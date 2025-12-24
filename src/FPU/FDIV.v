/*************************************************
 *File----------FDIV.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday Dec 17, 2025 19:27:37 UTC
 ************************************************/

module FDIV (
        input  wire               clk_i,
        input  wire               reset_i,
        input  wire               divEnable_i,

        input  wire        [31:0] rs1_i,
        input  wire signed [9:0]  rs1Exp_i,
        input  wire        [23:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [31:0] rs2_i,
        input  wire signed [9:0]  rs2Exp_i,
        input  wire        [23:0] rs2Sig_i,
        input  wire        [5:0]  rs2Class_i,
        input  wire        [2:0]  rm_i,

        output reg                ready_o,
        output wire        [31:0] fdivOut_o
);
`include "src/FPU/FClassFlags.vh"

reg [31:0] divOut;
assign fdivOut_o = divOut;

wire qSign = rs1_i[31] ^ rs2_i[31];

// Working registers
reg signed [25:0] aSig;
reg signed [25:0] bSig;
reg signed [25:0] rSig;
reg        [25:0] qSig;
reg signed [9:0]  qExp;
reg signed [9:0]  expNorm;
reg signed [9:0]  expIn;

// Cycle counter
reg  [4:0] counter;
// Only one cycle is needed to handle special cases
localparam SPECIAL_CYCLES = 5'b1;
// Enough cycles to compute full significand with extra bits for rounding and normalizing
localparam DIVIDE_CYCLES = 5'd27;

// Status Flags
reg special;    // Special Cases (NaN, inf, zero)
reg busy;

// A wire set to infinity or the max normal number depending on rounding modes
wire si = (rm_i == 3'b001 || (rm_i == 3'b010 && ~qSign) || (rm_i == 3'b011 &&  qSign));
wire [31:0] roundedInfinity = {qSign, {7{1'b1}}, ~si, {23{si}}};

// Rounding
wire        [23:0] sigOut;
wire signed [9:0]  expOut;
FRound #(.nInt(52)) round(qSign, {qSig, aSig}, expIn, rm_i, sigOut, expOut);

always @(posedge clk_i) begin
        if (!divEnable_i) begin
                counter <= 0;
        end else if (counter == 0 && !reset_i) begin
                // Treat special cases as default
                special <= 1'b1;
                counter <= SPECIAL_CYCLES;

                // initalize output
                divOut = 32'b0;

                // Handle all cases
                /* verilator lint_off CASEOVERLAP */
                casez(rs1Class_i | rs2Class_i)
                        /************************ Special Cases ************************/
                        // Return NaN if one or both inputs are NaN
                        6'b?1????: divOut <= rs1Class_i[CLASS_BIT_SNAN] ? rs1_i : rs2_i;
                        6'b10????: divOut <= rs1Class_i[CLASS_BIT_QNAN] ? rs1_i : rs2_i;
                        // Both inputs are infinity
                        6'b001000: divOut <= {qSign, {31{1'b1}}};
                        // One finite input and one infinite input
                        6'b001???: begin
                                // Dividend is infinite. Divisor is finite. ∞/x
                                if (rs1Class_i[CLASS_BIT_INF])
                                        divOut <= roundedInfinity;
                                // Dividend is finite. Divisor is infinite. x/∞
                                else
                                        divOut <= {qSign, 31'b0};
                        end
                        // Both inputs are zero, return QNaN. 0/0 = QNaN
                        6'b000001: divOut <= {qSign, {31{1'b1}}};
                        // One input is zero, oneinput is normal/subnormal
                        6'b000??1: begin
                                // Dividend is zero. Divisor is non-zero. 0/x
                                if (rs1Class_i[CLASS_BIT_ZERO])
                                        divOut <= {qSign, 31'b0};
                                // Dividend is non-zero. Divisor is zero. x/0
                                else
                                        divOut <= roundedInfinity;
                        end

                        /************************ Divide ************************/
                        // Both inputs are normal or subnormal
                        default: begin
                                special <= 1'b0;
                                counter <= DIVIDE_CYCLES;

                                // Initalize working registers
                                qSig = 0;
                                aSig = {2'b00, rs1Sig_i};
                                bSig = {2'b00, rs2Sig_i};
                                expNorm <= 0;

                                // Compute first bit of quotient significand
                                rSig = aSig - bSig;
                                qSig = {qSig[24:0], ~rSig[25]};
                                aSig = {(rSig[25] ? aSig[24:0] : rSig[24:0]), 1'b0};

                                // DEBUG: Show current state of computation
                                divOut = {6'b0, qSig};
                        end
                endcase
                /* verilator lint_on CASEOVERLAP */
        end else if (counter > 2) begin // Continue computing significand
                counter <= counter - 1;

                rSig = aSig - bSig;
                qSig = {qSig[24:0], ~rSig[25]};
                aSig = {(rSig[25] ? aSig[24:0] : rSig[24:0]), 1'b0};

                // DEBUG: Show current state of computation
                divOut = {6'b0, qSig};
        end else if (counter > 1) begin // Set exponent and normalize quotient if needed
                counter <= counter - 1;

                // Set the quotient exponent and normalize if needed
                expNorm[0] = ~qSig[25];
                expIn = rs1Exp_i - rs2Exp_i - expNorm;
                qSig = qSig << ~qSig[25];

                // expIn and {qSig, aSig} will go into the rounding module

                // DEBUG: Show current state of computation
                divOut = {6'b0, qSig};
        end else if (counter > 0) begin // Construct final output
                counter <= counter - 1;

                // Special cases already constructed output
                if (~special) begin
                        // Zero
                        if (~|sigOut) begin
                                // Negative zero if rounding mode is towards -infinity
                                divOut <= {rm_i == 3'b010, 31'b0};
                        end
                        // Subnormal
                        else if (expOut < -126) begin
                                divOut <= {qSign, 8'b0, sigOut[22:0]};
                        end
                        // Overflow
                        else if (expOut > 127) begin
                                // // Round to infinity or largest normal depending on rounding mode
                                // si = (rm_i == 3'b001 || 
                                //         (rm_i == 3'b010 && ~qSign) ||
                                //         (rm_i == 3'b011 &&  qSign));
                                // divOut <= {qSign, {7{1'b1}}, ~si, {23{si}}};
                                divOut <= roundedInfinity;
                        end
                        // Normal
                        else begin
                                qExp = expOut + 127;
                                divOut = {qSign, qExp[7:0], sigOut[22:0]};
                        end
                end
                special <= 1'b0;
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

