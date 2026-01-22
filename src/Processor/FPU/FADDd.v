/*************************************************
 *File----------FADDd.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday Jan 21, 2026 14:34:53 UTC
 ************************************************/

module FADDd #(
        parameter FLEN = 32
)(
        input  wire        [FLEN-1:0]   rs1_i,
        input  wire signed [NEXP+2:0]   rs1Exp_i,     // Added precision for FMA Instructions
        input  wire        [NFULLSIG:0] rs1Sig_i,
        input  wire        [5:0]        rs1Class_i,
        input  wire        [FLEN-1:0]   rs2_i,
        input  wire signed [NEXP+2:0]   rs2Exp_i,
        input  wire        [NFULLSIG:0] rs2Sig_i,
        input  wire        [5:0]        rs2Class_i,
        input  wire        [2:0]        rm_i,

        output wire        [FLEN-1:0]   faddOut_o
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

localparam FMAX = {1'b0, {NEXP-1{1'b1}}, 1'b0, {NSIG{1'b1}}};
localparam FMIN = {1'b1, {NEXP-1{1'b1}}, 1'b0, {NSIG{1'b1}}};
localparam INF  = {1'b0, {NEXP{1'b1}}, {NSIG{1'b0}}};
localparam NINF = {1'b1, {NEXP{1'b1}}, {NSIG{1'b0}}};
localparam QNAN = {1'b0, {NEXP{1'b1}}, 1'b1, {NSIG-1{1'b0}}};

reg  [FLEN-1:0] out;
assign faddOut_o = out;

wire signed [NFULLSIG+1:0] rs1Sig = {1'b0, rs1Sig_i};
wire signed [NFULLSIG+1:0] rs2Sig = {1'b0, rs2Sig_i};

reg               sumSign;
reg signed [NFULLSIG+1:0] sumSig;
reg signed [NFULLSIG+1:0] sumSigNorm;
reg signed [NEXP+2:0] adjExpNorm;
reg        [NEXP+2:0] biasExp;

reg signed [NFULLSIG+1:0] augendSig;
reg signed [NFULLSIG+1:0] addendSig;
reg signed [NEXP+2:0] adjExp;
reg        [NEXP+2:0] shamt;
wire              subtract = rs1_i[FLEN-1] ^ rs2_i[FLEN-1];

// Need to get the larger of the 2 inputs
wire signed [NEXP+2:0] expDiff = rs2Exp_i - rs1Exp_i;
wire signed [NFULLSIG+1:0] sigDiff = rs2Sig - rs1Sig;
wire rs2_lt_rs1 = expDiff[NEXP+2] || (rs1Exp_i == rs2Exp_i && sigDiff[NFULLSIG+1]);

// Normalization logic
wire [6:0] sumSigCLZ;
CLZ #(.W_IN(128))clz({{126-NFULLSIG{1'b0}}, sumSig}, sumSigCLZ);
// Shift amount is sigLen - firstBitSet = sigLen - (127 - CLZ) = CLZ - (127 - sigLen)
localparam shamtConst = 127 - NFULLSIG;
wire [6:0] normShamt = sumSigCLZ - shamtConst;

// Rounding
reg  signed [NFULLSIG+1:0] outSig;
wire        [NSIG:0] sumSigRound;
wire signed [NEXP+2:0] sumExpRound;
FRound #(.nInt(NFULLSIG+1),.nExp(NEXP+1), .nSig(NSIG)) round(
        sumSign, outSig[NFULLSIG:0], adjExpNorm, rm_i,
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
                if (rs1_i[FLEN-1] ^ rs2_i[FLEN-1]) begin
                        out = QNAN;
                end
                // If signs the same and round to nearest, return infinity
                else if (rm_i[1:0] == 2'b00) begin
                        out = rs1_i;
                end
                // If round towards Zero, return largest finite number
                else if (rm_i == 3'b001) begin
                        out = rs1_i[FLEN-1] ? FMIN : FMAX;
                end
                // If round towards +- Infinity, return MAX or infinity based on sign
                else if (rm_i == 3'b010) begin
                        out = rs1_i[FLEN-1] ? NINF : FMAX;
                end else begin
                        out = rs1_i[FLEN-1] ? FMIN : INF;
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
                        addendSig = (rs1_i[FLEN-1] ^ rs2_i[FLEN-1]) ? -rs2Sig : rs2Sig;
                        sumSign = rs1_i[FLEN-1];
                        adjExp = rs1Exp_i;
                        shamt = rs1Exp_i - rs2Exp_i;
                end else begin
                        augendSig = rs2Sig;
                        addendSig = (rs1_i[FLEN-1] ^ rs2_i[FLEN-1]) ? -rs1Sig : rs1Sig;
                        sumSign = rs2_i[FLEN-1];
                        adjExp = rs2Exp_i;
                        shamt = rs2Exp_i - rs1Exp_i;
                end

                // Shift significand so exponents match
                // Arithmetic shift to preserve negation for subtraction
                addendSig = addendSig >>> shamt;

                // Add adjusted significands.
                sumSig = augendSig + addendSig;

                // Normalize
                adjExpNorm = adjExp + shamtConst - {{NEXP-4{1'b0}}, sumSigCLZ};
                if (adjExpNorm < EMIN || sumSig == 0) begin
                        sumSigNorm = 0;
                        adjExpNorm = EMIN - 1;
                        sumSign = 1'b0;
                end else if (sumSig[NFULLSIG+1]) begin
                        sumSigNorm = sumSig >> 1;
                end else begin
                        sumSigNorm = sumSig << normShamt;
                end


                // Pack output into 32 bit FP
                // Underflow
                if (adjExpNorm < (EMIN - NSIG)) begin // Too small for subnormals
                        out = {sumSign, {FLEN-1{1'b0}}};
                end
                // Subnormal
                else if (adjExpNorm < EMIN) begin
                        outSig = sumSigNorm >> (EMIN - adjExpNorm);
                        out = {sumSign, {NEXP{1'b0}}, sumSigRound[NSIG-1:0]};
                end
                // Overflow
                else if (adjExpNorm > EMAX) begin
                        out = {sumSign, {NEXP{1'b1}}, {NSIG{1'b0}}};
                end
                // Normal
                else begin
                        outSig = sumSigNorm;
                        biasExp = sumExpRound + BIAS;
                        out = {sumSign, biasExp[NEXP-1:0], sumSigRound[NSIG-1:0]};
                end
        end
end

endmodule

