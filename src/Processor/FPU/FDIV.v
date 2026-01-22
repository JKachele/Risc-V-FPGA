/*************************************************
 *File----------FDIV.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday Dec 17, 2025 19:27:37 UTC
 ************************************************/

module FDIV #(
        parameter FLEN = 32
)(
        input  wire                     clk_i,
        input  wire                     reset_i,
        input  wire                     divEnable_i,

        input  wire        [FLEN-1:0]   rs1_i,
        input  wire signed [NEXP+1:0]   rs1Exp_i,
        input  wire        [NSIG:0]     rs1Sig_i,
        input  wire        [5:0]        rs1Class_i,
        input  wire        [FLEN-1:0]   rs2_i,
        input  wire signed [NEXP+1:0]   rs2Exp_i,
        input  wire        [NSIG:0]     rs2Sig_i,
        input  wire        [5:0]        rs2Class_i,
        input  wire        [2:0]        rm_i,

        output reg                      ready_o,
        output wire        [FLEN-1:0]       fdivOut_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

localparam NEXP      = (FLEN == 32) ? 8 : 11;
localparam NSIG      = (FLEN == 32) ? 23 : 52;
localparam EMAX = ((1 << (NEXP - 1)) - 1);
localparam BIAS = EMAX;
localparam EMIN = 1 - EMAX;

reg [FLEN-1:0] divOut;
assign fdivOut_o = divOut;

wire qSign = rs1_i[FLEN-1] ^ rs2_i[FLEN-1];

// Working registers
reg signed [NSIG+2:0] aSig;
reg signed [NSIG+2:0] bSig;
reg signed [NSIG+2:0] rSig;
reg        [NSIG+2:0] qSig;
reg signed [NEXP+1:0] qExp;
reg signed [NEXP+1:0] expNorm;
reg signed [NEXP+1:0] expIn;

// Cycle counter
reg  [5:0] counter;
// Only one cycle is needed to handle special cases
localparam SPECIAL_CYCLES = 1;
// Enough cycles to compute full significand with extra bits for rounding and normalizing
localparam DIVIDE_CYCLES = NSIG + 4;

// Status Flags
reg special;    // Special Cases (NaN, inf, zero)
reg busy;

// A wire set to infinity or the max normal number depending on rounding modes
wire si = (rm_i == 3'b001 || (rm_i == 3'b010 && ~qSign) || (rm_i == 3'b011 &&  qSign));
wire [FLEN-1:0] roundedInfinity = {qSign, {NEXP-1{1'b1}}, ~si, {NSIG{si}}};

// Rounding
localparam roundLen = (NSIG + 3) * 2;
wire        [NSIG:0] sigOut;
wire signed [NEXP+1:0]  expOut;
FRound #(.nInt(roundLen), .nExp(NEXP), .nSig(NSIG)
)round(qSign, {qSig, aSig}, expIn, rm_i, sigOut, expOut);

always @(posedge clk_i) begin
        if (!divEnable_i) begin
                counter <= 0;
        end else if (counter == 0 && !reset_i) begin
                // Treat special cases as default
                special <= 1'b1;
                counter <= SPECIAL_CYCLES;

                // initalize output
                divOut = 0;

                // Handle all cases
                /* verilator lint_off CASEOVERLAP */
                casez(rs1Class_i | rs2Class_i)
                        /************************ Special Cases ************************/
                        // Return NaN if one or both inputs are NaN
                        6'b?1????: divOut <= rs1Class_i[CLASS_BIT_SNAN] ? rs1_i : rs2_i;
                        6'b10????: divOut <= rs1Class_i[CLASS_BIT_QNAN] ? rs1_i : rs2_i;
                        // Both inputs are infinity
                        6'b001000: divOut <= {qSign, {FLEN-1{1'b1}}};
                        // One finite input and one infinite input
                        6'b001???: begin
                                // Dividend is infinite. Divisor is finite. ∞/x
                                if (rs1Class_i[CLASS_BIT_INF])
                                        divOut <= roundedInfinity;
                                // Dividend is finite. Divisor is infinite. x/∞
                                else
                                        divOut <= {qSign, {FLEN-1{1'b0}}};
                        end
                        // Both inputs are zero, return QNaN. 0/0 = QNaN
                        6'b000001: divOut <= {qSign, {FLEN-1{1'b1}}};
                        // One input is zero, oneinput is normal/subnormal
                        6'b000??1: begin
                                // Dividend is zero. Divisor is non-zero. 0/x
                                if (rs1Class_i[CLASS_BIT_ZERO])
                                        divOut <= {qSign, {FLEN-1{1'b0}}};
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
                                qSig = {qSig[NSIG+1:0], ~rSig[NSIG+2]};
                                aSig = {(rSig[NSIG+2] ? aSig[NSIG+1:0] : rSig[NSIG+1:0]), 1'b0};

                                // DEBUG: Show current state of computation
                                divOut = {{FLEN-(NSIG+3){1'b0}}, qSig};
                        end
                endcase
                /* verilator lint_on CASEOVERLAP */
        end else if (counter > 2) begin // Continue computing significand
                counter <= counter - 1;

                rSig = aSig - bSig;
                qSig = {qSig[NSIG+1:0], ~rSig[NSIG+2]};
                aSig = {(rSig[NSIG+2] ? aSig[NSIG+1:0] : rSig[NSIG+1:0]), 1'b0};

                // DEBUG: Show current state of computation
                divOut = {{FLEN-(NSIG+3){1'b0}}, qSig};
        end else if (counter > 1) begin // Set exponent and normalize quotient if needed
                counter <= counter - 1;

                // Set the quotient exponent and normalize if needed
                expNorm[0] = ~qSig[NSIG+2];
                expIn = rs1Exp_i - rs2Exp_i - expNorm;
                qSig = qSig << ~qSig[NSIG+2];

                // expIn and {qSig, aSig} will go into the rounding module

                // DEBUG: Show current state of computation
                divOut = {{FLEN-(NSIG+3){1'b0}}, qSig};
        end else if (counter > 0) begin // Construct final output
                counter <= counter - 1;

                // Special cases already constructed output
                if (~special) begin
                        // Zero
                        if (~|sigOut) begin
                                // Negative zero if rounding mode is towards -infinity
                                divOut <= {rm_i == 3'b010, {FLEN-1{1'b0}}};
                        end
                        // Subnormal
                        else if (expOut < EMIN) begin
                                divOut <= {qSign, {NEXP{1'b0}}, sigOut[NSIG-1:0]};
                        end
                        // Overflow
                        else if (expOut > EMAX) begin
                                // // Round to infinity or largest normal depending on rounding mode
                                // si = (rm_i == 3'b001 || 
                                //         (rm_i == 3'b010 && ~qSign) ||
                                //         (rm_i == 3'b011 &&  qSign));
                                // divOut <= {qSign, {7{1'b1}}, ~si, {23{si}}};
                                divOut <= roundedInfinity;
                        end
                        // Normal
                        else begin
                                qExp = expOut + BIAS;
                                divOut = {qSign, qExp[NEXP-1:0], sigOut[NSIG-1:0]};
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

