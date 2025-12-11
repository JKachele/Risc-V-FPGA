/*************************************************
 *File----------FMUL.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 18:22:47 UTC
 ************************************************/

module FMUL (
        input  wire        clk_i,
        input  wire        reset_i,

        input  wire        fmulEnable_i,
        input  wire [31:0] rs1_i,
        input  wire [31:0] rs2_i,

        output wire [31:0] fmulOut_o
);

reg [31:0] out;
assign fmulOut_o = out;

wire signed [8:0]  rs1Exp;// = rs1_i[30:23] - 127;
wire        [23:0] rs1Sig;// = {1'b1, rs1_i[22:0]};
wire signed [8:0]  rs2Exp;// = rs2_i[30:23] - 127;
wire        [23:0] rs2Sig;// = {1'b1, rs2_i[22:0]};

wire        [47:0] sigProd = rs1Sig * rs2Sig;
wire signed [8:0]  expSum = rs1Exp + rs2Exp;

wire               outSign = rs1_i[31] ^ rs2_i[31];
reg         [47:0] outSigNorm;
reg         [47:0] outSig;
reg  signed [8:0]  outExp;
reg         [8:0]  outExpBiased;

wire [5:0] rs1Class;
wire [5:0] rs2Class;
FClass class1(rs1_i, rs1Exp, rs1Sig, rs1Class);
FClass class2(rs2_i, rs2Exp, rs2Sig, rs1Class);
localparam CLASS_ZERO = 0;
localparam CLASS_SUB  = 1;
localparam CLASS_NORM = 2;
localparam CLASS_INF  = 3;
localparam CLASS_SNAN = 4;
localparam CLASS_QNAN = 5;

always @(*) begin
        /******** Special Cases ********/
        // Propigate NaNs
        if (rs1Class[CLASS_QNAN] || rs2Class[CLASS_QNAN]) begin
                out = rs1Class[CLASS_QNAN] ? rs1_i : rs2_i;
        end
        else if (rs1Class[CLASS_SNAN] || rs2Class[CLASS_SNAN]) begin
                out = rs1Class[CLASS_SNAN] ? rs1_i : rs2_i;
        end
        // Infinity
        else if (rs1Class[CLASS_INF] || rs2Class[CLASS_INF]) begin
                // Infinity x Zero = qNaN
                if (rs1Class[CLASS_ZERO] || rs2Class[CLASS_ZERO]) begin
                        out = {outSign, {8{1'b1}}, 1'b1, 22'b0};
                end
                // Infinity x (infinity, normal, subnormal) = infinity
                else begin
                        out = {outSign, {8{1'b1}}, 23'b0};
                end
        end
        // Zero and Subnormals
        else if (rs1Class[CLASS_ZERO] || rs2Class[CLASS_ZERO] ||
                 rs1Class[CLASS_SUB] || rs2Class[CLASS_SUB]) begin
                out = {outSign, 31'b0};
        end

        /******** Normals X Normals ********/
        else if (rs1Class[CLASS_NORM] && rs2Class[CLASS_NORM]) begin
                // Normalize the significand product
                if (sigProd[47]) begin
                        outSigNorm = {sigProd[46:0], 1'b0};
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
                        out = {outSign, 8'b0, outSig[47:25]};
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

