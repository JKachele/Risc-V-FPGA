/*************************************************
 *File----------FSQRT.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Dec 22, 2025 13:51:51 UTC
 ************************************************/

module FSQRT (
        input  wire               clk_i,
        input  wire               reset_i,
        input  wire               sqrtEnable_i,

        input  wire        [31:0] rs1_i,
        input  wire signed [9:0]  rs1Exp_i,
        input  wire        [23:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [2:0]  rm_i,

        output reg                ready_o,
        output wire        [31:0] fsqrtOut_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

reg [31:0] sqrtOut;
assign fsqrtOut_o = sqrtOut;

// Working registers
reg signed [9:0]  expIn;
reg signed [9:0]  qExp;
reg [25:0] sqrtSig;
reg [25:0] sqrtIn;
reg [49:0] rootIn;

reg [25:0] x;
reg [25:0] xNext;
reg [25:0] q;
reg [25:0] qNext;
reg [27:0] ac;
reg [27:0] acNext;
reg [27:0] test;

// Cycle counter
reg  [4:0] counter;
// Only one cycle is needed to handle special cases
localparam SPECIAL_CYCLES = 5'b1;
// Enough cycles to compute full significand with extra bits for rounding and normalizing
localparam SQRT_CYCLES = 5'd26;

// Status Flags
reg special;    // Special Cases (NaN, inf, zero)
reg busy;

// A wire set to infinity or the max normal number depending on rounding modes
wire si = (rm_i == 3'b001 || rm_i == 3'b010);
wire [31:0] roundedInfinity = {1'b0, {7{1'b1}}, ~si, {23{si}}};

// Rounding
wire        [23:0] sigOut;
wire signed [9:0]  expOut;
FRound #(.nInt(50)) round(1'b0, rootIn, expIn, rm_i, sigOut, expOut);

always @(posedge clk_i) begin
        if (!sqrtEnable_i) begin
                counter <= 0;
        end else if (counter == 0 && !reset_i) begin
                // Treat special cases as default
                special <= 1'b1;
                counter <= SPECIAL_CYCLES;

                // initalize output
                sqrtOut = 32'b0;

                /************************ Special Cases ************************/
                // Propagate NaN and Zero (Zero keeps original sign)
                if (|(rs1Class_i & 6'b110001)) begin
                        sqrtOut = rs1_i;
                end
                // Negatives are invalid and return qNaN
                else if (rs1_i[31]) begin
                        sqrtOut = {{10{1'b1}}, 22'b0};
                end
                // Infinity returns infinity
                else if (rs1Class_i[CLASS_BIT_INF]) begin
                        sqrtOut = rs1_i;
                end
                // Normal and subnormal numbers proceed to sqrt algorithm
                else begin
                        special <= 1'b0;
                        counter <= SQRT_CYCLES;

                        // Exponent gets halved
                        expIn <= {rs1Exp_i[9], rs1Exp_i[9:1]};

                        // Input into square root is significand with hidden bit
                        // If rs1Exp_i is odd, right shift by 1
                        q = 0;
                        sqrtSig = {1'b0, rs1Sig_i, 1'b0} >> rs1Exp_i[0];
                        {ac, x} = {26'b0, sqrtSig, 2'b0};

                        sqrtOut = {6'b0, q};
                end
        end else if (counter > 2) begin
                counter <= counter - 1;

                x <= xNext;
                ac <= acNext;
                q <= qNext;

                sqrtOut <= {6'b0, qNext};
        end else if (counter > 1) begin
                counter <= counter - 1;

                rootIn <= (rs1Exp_i[0]) ? {qNext[23:0], acNext[27:2]} : {qNext[24:1], acNext[27:2]};
        end else if (counter > 0) begin // Construct final output
                counter <= counter - 1;

                // Special cases already constructed output
                if (~special) begin
                        // Zero
                        if (~|sigOut) begin
                                // Negative zero if rounding mode is towards -infinity
                                sqrtOut <= {rm_i == 3'b010, 31'b0};
                        end
                        // Subnormal
                        else if (expOut < -126) begin
                                sqrtOut <= {9'b0, sigOut[22:0]};
                        end
                        // Overflow
                        else if (expOut > 127) begin
                                // // Round to infinity or largest normal depending on rounding mode
                                // si = (rm_i == 3'b001 || 
                                //         (rm_i == 3'b010 && ~qSign) ||
                                //         (rm_i == 3'b011 &&  qSign));
                                // divOut <= {qSign, {7{1'b1}}, ~si, {23{si}}};
                                sqrtOut <= roundedInfinity;
                        end
                        // Normal
                        else begin
                                qExp = expOut + 127;
                                sqrtOut = {1'b0, qExp[7:0], sigOut[22:0]};
                        end
                end
                special <= 1'b0;
        end
end

always @(*) begin
        test = ac - {q, 2'b01};
        if (test[27] == 0) begin
                {acNext, xNext} = {test[25:0], x, 2'b0};
                qNext = {q[24:0], 1'b1};
        end else begin
                {acNext, xNext} = {ac[25:0], x, 2'b0};
                qNext = q << 1;
        end
end

// Logic to generate the busy signal
always @(negedge clk_i) begin
        if (counter > 0) begin
                busy <= 1'b1;
                ready_o <= 1'b0;
        end else if (busy) begin
                busy <= 1'b0;
                ready_o <= 1'b1;
        end else begin
                ready_o <= 1'b0;
        end
end
endmodule

