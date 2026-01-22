/*************************************************
 *File----------FCVTSD.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 20, 2026 22:42:26 UTC
 ************************************************/

module FCVTDS (
        input  wire signed [63:0] rs1_i,

        output wire        [63:0] fcvtOut_o,
        output wire signed [12:0] exp_o,
        output wire        [52:0] sig_o,
        output wire        [5:0]  class_o,
        output wire        [9:0]  fullClass_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

wire [31:0] rs1 = rs1_i[31:0];

wire        [5:0]  rs1Class;
wire signed [9:0]  rs1Exp;
wire        [23:0] rs1Sig;
FClass class1(.reg_i(rs1), .regExp_o(rs1Exp), .regSig_o(rs1Sig),
        .class_o(rs1Class), .fullClass_o(fullClass_o));

// Exact conversion - No rounding
// Value is NaN boxed in the 64 bit input
reg  [63:0] ftodOut;
reg  [12:0] expOut;
reg  [52:0] sigOut;
reg  [5:0]  classOut;
assign fcvtOut_o = ftodOut;
assign exp_o = expOut;
assign sig_o = sigOut;
assign class_o = classOut;

wire [10:0] ftodExp = {rs1Exp[9], rs1Exp} + 1023;
wire [51:0] ftodSig = {rs1Sig[22:0], 29'b0};

always @(*) begin
        expOut = 0;
        sigOut = 0;
        if (rs1Class[CLASS_BIT_QNAN]) begin
                ftodOut = {rs1[31], {11{1'b1}}, 1'b1, 51'b0};
                classOut = CLASS_QNAN;
        end
        else if (rs1Class[CLASS_BIT_SNAN]) begin
                ftodOut = {rs1[31], {11{1'b1}}, ftodSig};
                classOut = CLASS_SNAN;
        end
        else if (rs1Class[CLASS_BIT_INF]) begin
                ftodOut = {rs1[31], {10{1'b1}}, 1'b0, 52'b0};
                classOut = CLASS_INF;
        end
        else if (rs1Class[CLASS_BIT_ZERO]) begin
                ftodOut = {rs1[31], 63'b0};
                classOut = CLASS_ZERO;
        end
        else begin
                ftodOut = {rs1[31], ftodExp, ftodSig};
                expOut = {{3{rs1Exp[9]}}, rs1Exp};
                sigOut = {rs1Sig, 29'b0};
                classOut = CLASS_NORM;
        end
end

endmodule

module FCVTSD (
        input  wire signed [63:0] rs1_i,
        input  wire signed [12:0] rs1Exp_i,
        input  wire        [52:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [2:0]  rm_i,         // Rounding Mode

        output wire        [31:0] fcvtOut_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

reg         [31:0] dtofOut;
assign fcvtOut_o = dtofOut;

reg         [52:0] outSig;
reg         [12:0] outExpBiased;

wire        [23:0] outSigRound;
wire signed [12:0] outExpRound;
FRound #(.nInt(53),.nExp(11))round(rs1_i[63], outSig, rs1Exp_i, rm_i, outSigRound, outExpRound);

always @(*) begin
        outSig = 0;
        outExpBiased = 0;
        if (rs1Class_i[CLASS_BIT_QNAN]) begin
                dtofOut = {rs1_i[63], {8{1'b1}}, 1'b1, 22'b0};
        end
        else if (rs1Class_i[CLASS_BIT_SNAN]) begin
                dtofOut = {rs1_i[63], {8{1'b1}}, rs1_i[51:29]};
        end
        else if (rs1Class_i[CLASS_BIT_INF]) begin
                dtofOut = {rs1_i[63], {7{1'b1}}, 1'b0, 23'b0};
        end
        else if (rs1Class_i[CLASS_BIT_ZERO]) begin
                dtofOut = {rs1_i[63], 31'b0};
        end
        // Underflow
        if (rs1Exp_i < -149) begin // Too small for subnormals
                dtofOut = {rs1_i[63], 31'b0};
        end
        // Subnormal
        else if (rs1Exp_i < -126) begin
                outSig = rs1Sig_i >> (-126 - rs1Exp_i);
                dtofOut = {rs1_i[63], 8'b0, outSigRound[22:0]};
        end
        // Overflow
        else if (rs1Exp_i > 127) begin
                dtofOut = {rs1_i[63], {8{1'b1}}, 23'b0};
        end
        // Normal
        else begin
                outSig = rs1Sig_i;
                outExpBiased = outExpRound + 127;
                dtofOut = {rs1_i[63], outExpBiased[7:0], outSigRound[22:0]};
        end
end

endmodule

