/*************************************************
 *File----------FADD.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 16, 2025 21:33:30 UTC
 ************************************************/

module FADD (
        input  wire        [31:0] rs1_i,
        input  wire signed [10:0] rs1Exp_i,     // Added precision for FMA Instructions
        input  wire        [47:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [31:0] rs2_i,
        input  wire signed [10:0] rs2Exp_i,
        input  wire        [47:0] rs2Sig_i,
        input  wire        [5:0]  rs2Class_i,
        input  wire        [2:0]  rm_i,

        output wire        [31:0] faddOut_o
);
localparam CLASS_BIT_ZERO = 0;
localparam CLASS_BIT_SUB  = 1;
localparam CLASS_BIT_NORM = 2;
localparam CLASS_BIT_INF  = 3;
localparam CLASS_BIT_SNAN = 4;
localparam CLASS_BIT_QNAN = 5;

localparam FMAX = 32'h7F7FFFFF;
localparam FMIN = 32'hFF7FFFFF;
localparam INF  = 32'h7F800000;
localparam NINF = 32'hFF800000;

reg [31:0] out;
assign faddOut_o = out;

wire signed [48:0] rs1Sig = {1'b0, rs1Sig_i};
wire signed [48:0] rs2Sig = {1'b0, rs2Sig_i};

reg               sumSign;
reg signed [48:0] sumSig;
reg signed [48:0] sumSigNormal;
reg        [10:0] adjExpNormal;

reg signed [48:0] augendSig;
reg signed [48:0] addendSig;
reg        [10:0] adjExp;
reg        [48:0] shamt;

always @(*) begin
        /************************ Special Cases ************************/
        // Propigate NaNs
        if (rs1Class_i[CLASS_BIT_QNAN] || rs2Class_i[CLASS_BIT_QNAN]) begin
                out = rs1Class_i[CLASS_BIT_QNAN] ? rs1_i : rs2_i;
        end
        else if (rs1Class_i[CLASS_BIT_SNAN] || rs2Class_i[CLASS_BIT_SNAN]) begin
                out = rs1Class_i[CLASS_BIT_SNAN] ? rs1_i : rs2_i;
        end
        // Zero
        else if (rs1Class_i[CLASS_BIT_ZERO] || rs2Class_i[CLASS_BIT_ZERO]) begin
                out = rs1Class_i[CLASS_BIT_ZERO] ? rs2_i : rs1_i;
        end
        // Infinity
        else if (rs1Class_i[CLASS_BIT_INF] && rs2Class_i[CLASS_BIT_INF]) begin
                // if signs differ, return QNaN
                if (rs1_i[31] ^ rs2_i[31]) begin
                        out = {1'b0, {8{1'b1}}, 1'b1, 22'b0};
                end
                // If signs the same and round to nearest, return infinity
                else if (rm_i[1:0] == 2'b00) begin
                        out = rs1_i;
                end
                // If round towards Zero, return largest finite number
                else if (rm_i == 3'b001) begin
                        out = rs1_i[31] ? FMIN : FMAX;
                end
                // If round towards +- Infinity, return MAX or infinity based on sign
                else if (rm_i == 3'b010) begin
                        out = rs1_i[31] ? NINF : FMAX;
                end else begin
                        out = rs1_i[31] ? FMIN : INF;
                end
        end else if (rs1Class_i[CLASS_BIT_INF] || rs2Class_i[CLASS_BIT_INF]) begin
                // If only one opperand is infinite, return signed infinity
                out = rs1Class_i[CLASS_BIT_INF] ? rs1_i : rs2_i;
        end
        /************************ Adding / Subtracting ************************/
        else begin
                if (rs1Exp_i < rs1Exp_i) begin
                        augendSig = rs2Sig;
                        addendSig = (rs1_i[31] ^ rs2_i[31]) ? -rs1Sig : rs1Sig;
                        sumSign = rs2_i[31];
                        adjExp = rs2Exp_i;
                        shamt = rs2Exp_i - rs1Exp_i;
                end else begin
                        augendSig = rs1Sig;
                        addendSig = (rs1_i[31] ^ rs2_i[31]) ? -rs2Sig : rs2Sig;
                        sumSign = rs1_i[31];
                        adjExp = rs1Exp_i;
                        shamt = rs1Exp_i - rs2Exp_i;
                end

                // Shift and add significands
                addendSig = addendSig >> shamt;
                sumSig = addendSig + augendSig;

                // Normalize
                sumSigNormal = sumSig >> sumSig[48];
                adjExpNormal = adjExp + sumSig[48];
        end
end

endmodule

