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
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

localparam FMAX = 32'h7F7FFFFF;
localparam FMIN = 32'hFF7FFFFF;
localparam INF  = 32'h7F800000;
localparam NINF = 32'hFF800000;

reg  [31:0] out;
assign faddOut_o = out;

wire signed [48:0] rs1Sig = {1'b0, rs1Sig_i};
wire signed [48:0] rs2Sig = {1'b0, rs2Sig_i};

reg               sumSign;
reg signed [48:0] sumSig;
reg signed [48:0] sumSigNorm;
reg signed [10:0] adjExpNorm;
reg        [10:0] biasExp;

reg signed [48:0] augendSig;
reg signed [48:0] addendSig;
reg signed [10:0] adjExp;
reg        [10:0] shamt;
wire              subtract = rs1_i[31] ^ rs2_i[31];

// Need to get the larger of the 2 inputs
wire signed [10:0] expDiff = rs2Exp_i - rs1Exp_i;
wire signed [48:0] sigDiff = rs2Sig - rs1Sig;
wire rs2_lt_rs1 = expDiff[10] || (rs1Exp_i == rs2Exp_i && sigDiff[48]);

// Normalization logic
wire [5:0] sumSigCLZ;
CLZ clz({15'b0, sumSig}, sumSigCLZ);
// Shift amount is 47 - firstBitSet = 47 - (63 - CLZ) = CLZ - 16
wire [5:0] normShamt = sumSigCLZ - 16;

// Rounding
reg  signed [48:0] outSig;
wire        [23:0] sumSigRound;
wire signed [10:0] sumExpRound;
FRound #(.nInt(48),.nExp(9)) round(
        sumSign, outSig[47:0], adjExpNorm, rm_i,
        sumSigRound, sumExpRound
);

always @(*) begin
        /************************ Special Cases ************************/
        augendSig = 0; addendSig = 0; sumSign = 0; sumSig = 0; sumSigNorm = 0; shamt = 0;
        adjExp = 0; adjExpNorm = 0; outSig = 0; biasExp = 0;
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
                // NOTE: Logical shift + negation is the same as negation + arithmetic shift
                if (rs2_lt_rs1) begin
                        augendSig = rs1Sig;
                        addendSig = (rs1_i[31] ^ rs2_i[31]) ? -rs2Sig : rs2Sig;
                        sumSign = rs1_i[31];
                        adjExp = rs1Exp_i;
                        shamt = rs1Exp_i - rs2Exp_i;
                end else begin
                        augendSig = rs2Sig;
                        addendSig = (rs1_i[31] ^ rs2_i[31]) ? -rs1Sig : rs1Sig;
                        sumSign = rs2_i[31];
                        adjExp = rs2Exp_i;
                        shamt = rs2Exp_i - rs1Exp_i;
                end

                // Shift significand so exponents match
                // Arithmetic shift to preserve negation for subtraction
                addendSig = addendSig >>> shamt;

                // Add adjusted significands.
                sumSig = augendSig + addendSig;

                // Normalize
                adjExpNorm = adjExp + 16 - {5'b0, sumSigCLZ};
                if (adjExpNorm < -126 || sumSig == 0) begin
                        sumSigNorm = 49'b0;
                        adjExpNorm = -127;
                        sumSign = 1'b0;
                end else if (sumSig[48]) begin
                        sumSigNorm = sumSig >> 1;
                end else begin
                        sumSigNorm = sumSig << normShamt;
                end


                // Pack output into 32 bit FP
                // Underflow
                if (adjExpNorm < -149) begin // Too small for subnormals
                        out = {sumSign, 31'b0};
                end
                // Subnormal
                else if (adjExpNorm < -126) begin
                        outSig = sumSigNorm >> (-126 - adjExpNorm);
                        out = {sumSign, 8'b0, sumSigRound[22:0]};
                end
                // Overflow
                else if (adjExpNorm > 127) begin
                        out = {sumSign, {8{1'b1}}, 23'b0};
                end
                // Normal
                else begin
                        outSig = sumSigNorm;
                        biasExp = sumExpRound + 127;
                        out = {sumSign, biasExp[7:0], sumSigRound[22:0]};
                end
        end
end

endmodule

