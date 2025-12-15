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

        output wire        [31:0] fmulOut_o,
        output wire signed [10:0] exp_o,
        output wire        [47:0] sig_o
);

reg [31:0] out;
assign fmulOut_o = out;
assign exp_o = outExp;
assign sig_o = outSigNorm;

wire        [47:0] sigProd = rs1Sig_i * rs2Sig_i;
wire signed [10:0]  expSum = rs1Exp_i + rs2Exp_i;

wire               outSign = rs1_i[31] ^ rs2_i[31];
reg         [47:0] outSigNorm;
reg         [47:0] outSig;
reg  signed [10:0] outExp;
reg         [10:0] outExpBiased;

localparam CLASS_ZERO = 0;
localparam CLASS_SUB  = 1;
localparam CLASS_NORM = 2;
localparam CLASS_INF  = 3;
localparam CLASS_SNAN = 4;
localparam CLASS_QNAN = 5;

always @(*) begin
        outSigNorm = 48'b0;
        outSig = 48'b0;
        outExp = 11'b0;
        outExpBiased = 11'b0;
        /******** Special Cases ********/
        // Propigate NaNs
        if (rs1Class_i[CLASS_QNAN] || rs2Class_i[CLASS_QNAN]) begin
                out = rs1Class_i[CLASS_QNAN] ? rs1_i : rs2_i;
        end
        else if (rs1Class_i[CLASS_SNAN] || rs2Class_i[CLASS_SNAN]) begin
                out = rs1Class_i[CLASS_SNAN] ? rs1_i : rs2_i;
        end
        // Infinity
        else if (rs1Class_i[CLASS_INF] || rs2Class_i[CLASS_INF]) begin
                // Infinity x Zero = qNaN
                if (rs1Class_i[CLASS_ZERO] || rs2Class_i[CLASS_ZERO]) begin
                        out = {outSign, {8{1'b1}}, 1'b1, 22'b0};
                end
                // Infinity x (infinity, normal, subnormal) = infinity
                else begin
                        out = {outSign, {8{1'b1}}, 23'b0};
                end
        end
        // Zero and Subnormals
        else if (rs1Class_i[CLASS_ZERO] || rs2Class_i[CLASS_ZERO] ||
                 rs1Class_i[CLASS_SUB] || rs2Class_i[CLASS_SUB]) begin
                out = {outSign, 31'b0};
        end

        /******** Normals X Normals or Subnormals ********/
        else begin
                // Normalize the significand product
                if (sigProd[47]) begin
                        outSigNorm = {sigProd[47:1], 1'b0};
                        outExp = expSum + 1;
                end else begin
                        outSigNorm = sigProd;
                        outExp = expSum;
                end

                // Pack output into 32 bit FP
                // Underflow
                if (outExp < -149) begin // Too small for subnormals
                        out = {outSign, 31'b0};
                end
                // Subnormal
                else if (outExp < -126) begin
                        outSig = outSigNorm >> (-126 - outExp);
                        out = {outSign, 8'b0, outSig[46:24]};
                end
                // Overflow
                else if (outExp > 127) begin
                        out = {outSign, {8{1'b1}}, 23'b0};
                end
                // Normal
                else begin
                        outExpBiased = outExp + 127;
                        out = {outSign, outExpBiased[7:0], outSigNorm[46:24]};
                end
        end
end

endmodule

