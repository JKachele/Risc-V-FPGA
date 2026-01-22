/*************************************************
 *File----------FMUL.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 18:22:47 UTC
 ************************************************/

module FMUL #(
        parameter FLEN = 32
)(
        input  wire        [FLEN-1:0]   rs1_i,
        input  wire signed [NEXP+1:0]   rs1Exp_i,
        input  wire        [NSIG:0]     rs1Sig_i,
        input  wire        [5:0]        rs1Class_i,
        input  wire        [FLEN-1:0]   rs2_i,
        input  wire signed [NEXP+1:0]   rs2Exp_i,
        input  wire        [NSIG:0]     rs2Sig_i,
        input  wire        [5:0]        rs2Class_i,
        input  wire        [2:0]        rm_i,

        output wire        [FLEN-1:0]   fmulOut_o,
        output wire signed [NEXP+2:0]   exp_o,
        output wire        [NFULLSIG:0] sig_o,
        output wire        [5:0]        class_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

localparam NEXP      = (FLEN == 32) ? 8 : 11;
localparam NSIG      = (FLEN == 32) ? 23 : 52;
localparam NFULLSIG  = (2 * NSIG) + 1;
localparam EMAX = ((1 << (NEXP - 1)) - 1);
localparam BIAS = EMAX;
localparam EMIN = 1 - EMAX;

reg [FLEN-1:0] out;
reg [5:0]  outClass;
assign fmulOut_o = out;
assign exp_o = outExp;
assign sig_o = outSigNorm;
assign class_o = outClass;

wire        [NFULLSIG:0] sigProd = rs1Sig_i * rs2Sig_i;
wire signed [NEXP+2:0]   expSum = rs1Exp_i + rs2Exp_i;

wire                     outSign = rs1_i[FLEN-1] ^ rs2_i[FLEN-1];
reg         [NFULLSIG:0] outSigNorm;
reg         [NFULLSIG:0] outSig;
reg  signed [NEXP+2:0]   outExp;
reg         [NEXP+2:0]   outExpBiased;

wire        [NSIG:0] outSigRound;
wire        [NEXP+2:0] outExpRound;
FRound #(.nInt(NFULLSIG+1), .nExp(NEXP+1), .nSig(NSIG)
)round(outSign, outSig, outExp, rm_i, outSigRound, outExpRound);

always @(*) begin
        outSigNorm = 0;
        outSig = 0;
        outExp = 0;
        outExpBiased = 0;
        /************************ Special Cases ************************/
        // Propigate NaNs
        if (rs1Class_i[CLASS_BIT_QNAN] || rs2Class_i[CLASS_BIT_QNAN]) begin
                out = rs1Class_i[CLASS_BIT_QNAN] ? rs1_i : rs2_i;
                outClass = CLASS_QNAN;
        end
        else if (rs1Class_i[CLASS_BIT_SNAN] || rs2Class_i[CLASS_BIT_SNAN]) begin
                out = rs1Class_i[CLASS_BIT_SNAN] ? rs1_i : rs2_i;
                outClass = CLASS_SNAN;
        end
        // Infinity
        else if (rs1Class_i[CLASS_BIT_INF] || rs2Class_i[CLASS_BIT_INF]) begin
                // Infinity x Zero = qNaN
                if (rs1Class_i[CLASS_BIT_ZERO] || rs2Class_i[CLASS_BIT_ZERO]) begin
                        out = {outSign, {NEXP{1'b1}}, 1'b1, {NSIG-1{1'b0}}};
                        outClass = CLASS_QNAN;
                end
                // Infinity x (infinity, normal, subnormal) = infinity
                else begin
                        out = {outSign, {NEXP{1'b1}}, {NSIG{1'b0}}};
                        outClass = CLASS_INF;
                end
        end
        // Zero and Subnormals
        else if (rs1Class_i[CLASS_BIT_ZERO] || rs2Class_i[CLASS_BIT_ZERO] ||
                 (rs1Class_i[CLASS_BIT_SUB] && rs2Class_i[CLASS_BIT_SUB])) begin
                out = {outSign, {FLEN-1{1'b0}}};
                outClass = CLASS_ZERO;
        end

        /************************ Multiply ************************/
        else begin
                // Normalize the significand product
                if (sigProd[NFULLSIG]) begin
                        outSigNorm = sigProd;
                        outExp = expSum + 1;
                end else begin
                        outSigNorm = {sigProd[NFULLSIG-1:0], 1'b0};
                        outExp = expSum;
                end

                // Pack output into 32/64 bit FP
                // Underflow
                if (outExp < (EMIN - NSIG)) begin // Too small for subnormals
                        out = {outSign, {FLEN-1{1'b0}}};
                        outClass = CLASS_ZERO;
                end
                // Subnormal
                else if (outExp < EMIN) begin
                        outSig = outSigNorm >> (EMIN - outExp);
                        out = {outSign, {NEXP{1'b0}}, outSigRound[NSIG-1:0]};
                        outClass = CLASS_SUB;
                end
                // Overflow
                else if (outExp > EMAX) begin
                        out = {outSign, {NEXP{1'b1}}, {NSIG{1'b0}}};
                        outClass = CLASS_INF;
                end
                // Normal
                else begin
                        outSig = outSigNorm;
                        outExpBiased = outExpRound + BIAS;
                        out = {outSign, outExpBiased[NEXP-1:0], outSigRound[NSIG-1:0]};
                        outClass = CLASS_NORM;
                end
        end
end

endmodule

