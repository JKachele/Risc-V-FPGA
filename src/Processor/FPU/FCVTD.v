/*************************************************
 *File----------FCVTD.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 20, 2026 18:24:32 UTC
 ************************************************/

module FCVTD (
        input  wire signed [63:0] rs1_i,
        input  wire signed [12:0] rs1Exp_i,
        input  wire        [52:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [1:0]  instr_i,      // {double->int, unsigned}
        input  wire        [2:0]  rm_i,         // Rounding Mode

        output wire        [63:0] fcvtOut_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

assign fcvtOut_o = instr_i[1] ? ftoiOut : {outSign, outExp[10:0], outSig[51:0]};

// Int -> double conversion
// Exact conversion - No rounding
reg         outSign;
reg  [12:0] outExp;
reg  [52:0] outSig;

wire signed [31:0] rs1_32 = rs1_i[31:0];
reg         [31:0] unsignedRs1;
wire        [4:0]  intClz;
CLZ #(.W_IN(32))clz(unsignedRs1, intClz);

always @(*) begin
        if (rs1_32 == 0) begin
                outSign     = 0;
                unsignedRs1 = 0;
                outSig      = 0;
                outExp      = 0;
        end else begin
                // Convert to unsigned and record sign
                if (instr_i[0] || (rs1_32 > 0)) begin
                        unsignedRs1 = rs1_32;
                        outSign = 1'b0;
                end else begin
                        unsignedRs1 = ~($unsigned(rs1_32) - 1);
                        outSign = 1'b1;
                end

                // Normalize
                // Shift so leading 1 is at bit 31.
                // Set exponent to (32 - clz - 1) + 1023 = 1054 - clz
                // No need for rounding
                outSig = {unsignedRs1 << intClz, 21'b0};
                outExp = 1054 - {8'b0, intClz};
        end
end

// double -> Int conversion
wire signed [63:0] ftoiOut = {{32{1'b1}}, (rs1_i[63]) ? -$signed(ftoiRounded) : ftoiRounded};
wire        [31:0] ftoiRounded;
reg         [52:0] ftoiNormal;
reg         [52:0] ftoiRoundBits;
FRoundInt roundFtoi(rs1_i[63], ftoiNormal[31:0], ftoiRoundBits[52], |ftoiRoundBits[51:0],
        rm_i, ftoiRounded);

wire signed [12:0]  ftoiShift    = 13'd52 - rs1Exp_i;

always @(*) begin
        ftoiRoundBits = 53'b0;
        /************************ Special Cases ************************/
        // Negatives are out-of-range for unsigned conversion. Returns 0
        if (rs1_i[63] && instr_i[0]) begin
                ftoiNormal = 53'b0;
        end
        // Negative infinity returns min value for signed conversion
        else if (rs1_i[63] && rs1Class_i[CLASS_BIT_INF]) begin
                ftoiNormal = {21'b0, 32'h80000000};
        end
        // Positive infinity and NaN returns max value
        else if (|(rs1Class_i & INF_NAN_MASK)) begin
                ftoiNormal = {21'b0, instr_i[0] ? 32'h7FFFFFFF : 32'hFFFFFFFF};
        end
        // Underflow: if float is < -2^31, return -2^31
        else if (rs1_i[63] && rs1Exp_i >= 31) begin
                ftoiNormal = {21'b0, 32'h80000000};
        end
        // Overflow: max signed = 2^31-1, max unsigned = 2^32-1
        else if (instr_i[0] && rs1Exp_i >= 32) begin
                ftoiNormal = {21'b0, 32'hFFFFFFFF};
        end else if (!instr_i[0] && rs1Exp_i >= 31) begin
                ftoiNormal = {21'b0, 32'h7FFFFFFF};
        end
        /************************ Conversion ************************/
        else begin
                ftoiNormal = rs1Sig_i >> ftoiShift;
                ftoiRoundBits = rs1Sig_i << (53 - ftoiShift);
        end
end

endmodule

