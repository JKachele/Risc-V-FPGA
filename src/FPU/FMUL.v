/*************************************************
 *File----------FMUL.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 18:22:47 UTC
 ************************************************/

module FMUL (
        input  wire        [31:0] rs1_i,
        input  wire signed [9:0]  rs1Exp_i,
        input  wire        [23:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [31:0] rs2_i,
        input  wire signed [9:0]  rs2Exp_i,
        input  wire        [23:0] rs2Sig_i,
        input  wire        [5:0]  rs2Class_i,
        input  wire        [2:0]  rm_i,

        output wire        [31:0] fmulOut_o,
        output wire signed [10:0] exp_o,
        output wire        [47:0] sig_o,
        output wire        [5:0]  class_o
);
`ifdef BENCH
        `include "src/FPU/FClassFlags.vh"
`else
        `include "../src/FPU/FClassFlags.vh"
`endif

reg [31:0] out;
reg [5:0]  outClass;
assign fmulOut_o = out;
assign exp_o = outExp;
assign sig_o = outSigNorm;
assign class_o = outClass;

wire        [47:0] sigProd = rs1Sig_i * rs2Sig_i;
wire signed [10:0]  expSum = rs1Exp_i + rs2Exp_i;

wire               outSign = rs1_i[31] ^ rs2_i[31];
reg         [47:0] outSigNorm;
reg         [47:0] outSig;
reg  signed [10:0] outExp;
reg         [10:0] outExpBiased;

wire        [23:0] outSigRound;
wire        [10:0] outExpRound;
FRound #(.nInt(48),.nExp(9)) round(outSign, outSig, outExp, rm_i, outSigRound, outExpRound);

always @(*) begin
        outSigNorm = 48'b0;
        outSig = 48'b0;
        outExp = 11'b0;
        outExpBiased = 11'b0;
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
                        out = {outSign, {8{1'b1}}, 1'b1, 22'b0};
                        outClass = CLASS_QNAN;
                end
                // Infinity x (infinity, normal, subnormal) = infinity
                else begin
                        out = {outSign, {8{1'b1}}, 23'b0};
                        outClass = CLASS_INF;
                end
        end
        // Zero and Subnormals
        else if (rs1Class_i[CLASS_BIT_ZERO] || rs2Class_i[CLASS_BIT_ZERO] ||
                 (rs1Class_i[CLASS_BIT_SUB] && rs2Class_i[CLASS_BIT_SUB])) begin
                out = {outSign, 31'b0};
                outClass = CLASS_ZERO;
        end

        /************************ Multiply ************************/
        else begin
                // Normalize the significand product
                if (sigProd[47]) begin
                        outSigNorm = sigProd;
                        outExp = expSum + 1;
                end else begin
                        outSigNorm = {sigProd[46:0], 1'b0};
                        outExp = expSum;
                end

                // Pack output into 32 bit FP
                // Underflow
                if (outExp < -149) begin // Too small for subnormals
                        out = {outSign, 31'b0};
                        outClass = CLASS_ZERO;
                end
                // Subnormal
                else if (outExp < -126) begin
                        outSig = outSigNorm >> (-126 - outExp);
                        out = {outSign, 8'b0, outSigRound[22:0]};
                        outClass = CLASS_SUB;
                end
                // Overflow
                else if (outExp > 127) begin
                        out = {outSign, {8{1'b1}}, 23'b0};
                        outClass = CLASS_INF;
                end
                // Normal
                else begin
                        outSig = outSigNorm;
                        outExpBiased = outExpRound + 127;
                        out = {outSign, outExpBiased[7:0], outSigRound[22:0]};
                        outClass = CLASS_NORM;
                end
        end
end

endmodule

