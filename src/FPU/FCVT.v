/*************************************************
 *File----------FCVTSW.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 16, 2025 14:23:57 UTC
 ************************************************/

module FCVT (
        input  wire signed [31:0] rs1_i,
        input  wire signed [9:0]  rs1Exp_i,
        input  wire        [23:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [1:0]  instr_i,      // {fp->int, unsigned}
        input  wire        [2:0]  rm_i,         // Rounding Mode

        output wire        [31:0] fcvtOut_o
);
localparam CLASS_INF    = 3;
localparam CLASS_SNAN   = 4;
localparam CLASS_QNAN   = 5;
localparam INF_NAN_MASK = 6'b111000;

assign fcvtOut_o = instr_i[1] ? ftoiOut : {outSign, outExp, outSig};

// Int -> float conversion
reg         outSign;
wire [7:0]  outExp;
wire [22:0] outSig;

reg  [31:0] unsignedRs1;
wire [4:0]  intClz;
CLZ #(.W_IN(32))clz(unsignedRs1, intClz);

reg [31:0] normalSig;
reg [7:0] normalExp;
FRound round(outSign, normalSig, normalExp, rm_i, outSig, outExp);

always @(*) begin
        if (rs1_i == 0) begin
                // {outSign, outExp, outSig} = 32'b0;
                outSign = 1'b0;
                unsignedRs1 = 0;
                normalSig = 0;
                normalExp = 0;
        end else begin
                // Convert to unsigned and record sign
                if (instr_i[0] || (rs1_i > 0)) begin
                        unsignedRs1 = rs1_i;
                        outSign = 1'b0;
                end else begin
                        unsignedRs1 = ~($unsigned(rs1_i) - 1);
                        outSign = 1'b1;
                end

                // Normalize
                // Shift so leading 1 is at bit 31.
                // Set exponent to (32 - clz - 1) + 127 = 158 - clz
                normalSig = unsignedRs1 << intClz;
                normalExp = 158 - {3'b0, intClz};
        end
end

// Float -> Int conversion

wire        [31:0] ftoiOut;
reg         [31:0] ftoiNormal;
reg         [31:0] ftoiRoundBits;
FRoundInt roundFtoi(rs1_i[31], ftoiNormal, ftoiRoundBits[31], |ftoiRoundBits[30:0], rm_i, ftoiOut);

wire signed [9:0]  ftoiShift    = 10'd23 - rs1Exp_i;
wire signed [9:0]  negFtoiShift = -ftoiShift;

always @(*) begin
        ftoiRoundBits = 32'b0;
        /************************ Special Cases ************************/
        // Negatives are out-of-range for unsigned conversion. Returns 0
        if (rs1_i[31] && instr_i[0]) begin
                ftoiNormal = 32'b0;
        end
        // Negative infinity returns min value for signed conversion
        else if (rs1_i[31] && rs1Class_i[CLASS_INF]) begin
                ftoiNormal = 32'h80000000;
        end
        // Positive infinity and NaN returns max value
        else if (|(rs1Class_i & INF_NAN_MASK)) begin
                ftoiNormal = instr_i[0] ? 32'h7FFFFFFF : 32'hFFFFFFFF;
        end
        // Underflow: if float is < -2^31, return -2^31
        else if (rs1_i[31] && rs1Exp_i >= 31) begin
                ftoiNormal = 32'h80000000;
        end
        // Overflow: max signed = 2^31-1, max unsigned = 2^32-1
        else if (instr_i[0] && rs1Exp_i >= 32) begin
                ftoiNormal = 32'hFFFFFFFF;
        end else if (!instr_i[0] && rs1Exp_i >= 31) begin
                ftoiNormal = 32'h8FFFFFFF;
        end
        /************************ Conversion ************************/
        else begin
                // Left shift
                if (ftoiShift[8]) begin
                        ftoiNormal = {8'b0, rs1Sig_i} << negFtoiShift;
                end else begin
                        // Underflow
                        if (rs1Exp_i < 0) begin
                                ftoiNormal = 32'b0;
                        end else begin
                                ftoiNormal = {8'b0, rs1Sig_i} >> ftoiShift;
                                ftoiRoundBits = {8'b0, rs1Sig_i} << 10'd32 - ftoiShift;
                        end
                end
        end
end

endmodule

