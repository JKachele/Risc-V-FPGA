/*************************************************
 *File----------FClass.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 20:06:53 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module FClass #(
        parameter FLen = 32,
        parameter ExpLen = 8,
        parameter SigLen = 23
)(
        input  wire        [FLen-1:0] reg_i,
        output reg  signed [ExpLen+1:0]  regExp_o,
        output reg         [SigLen:0] regSig_o,
        output wire        [5:0]  class_o,
        output wire        [9:0]  fullClass_o
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

wire regExpZ   = (reg_i[FLen-2:SigLen] == 0);
wire regExpMax = &reg_i[FLen-2:SigLen];
wire regSigniZ = (reg_i[SigLen-1:0]  == 0);

assign class_o = {
         regExpMax &  reg_i[SigLen-1],                  // 5: quiet NaN
         regExpMax & !reg_i[SigLen-1] & (|reg_i[SigLen-2:0]), // 4: sig NaN
         regExpMax &  regSigniZ,                  // 3: infinity
        !regExpZ   & !regExpMax,                  // 2: normal
         regExpZ   & !regSigniZ,                  // 1: subnormal
         regExpZ   &  regSigniZ                   // 0: 0
        };

assign fullClass_o = {
        regExpMax   &  reg_i[SigLen-1],                 // 9: quiet NaN
        regExpMax   & !reg_i[SigLen-1] & (|reg_i[SigLen-2:0]),// 8: sig NaN
        !reg_i[FLen-1]  &  regExpMax &  regSigniZ,    // 7: +infinity
        !reg_i[FLen-1]  & !regExpZ   & !regExpMax,    // 6: +normal
        !reg_i[FLen-1]  &  regExpZ   & !regSigniZ,    // 5: +subnormal
        !reg_i[FLen-1]  &  regExpZ   &  regSigniZ,    // 4: +0
        reg_i[FLen-1]   &  regExpZ   &  regSigniZ,    // 3: -0
        reg_i[FLen-1]   &  regExpZ   & !regSigniZ,    // 2: -subnormal
        reg_i[FLen-1]   & !regExpZ   & !regExpMax,    // 1: -normal
        reg_i[FLen-1]   &  regExpMax &  regSigniZ     // 0: -infinity
        };

// First bit set = 63 - clz
wire [5:0] sigClz;
CLZ #(.W_IN(64))clz({{64-SigLen{1'b0}}, reg_i[SigLen-1:0]}, sigClz);
// Shift so leading 1 is at bit SigLen:
// shamt = SigLen - first_bit_set = SigLen - (63 - clz) = clz - (63 - SigLen)
localparam shamtConst = 63 - SigLen;
wire [5:0] lshamt = sigClz - shamtConst;

localparam BIAS = ((1 << (ExpLen - 1)) - 1);
localparam EMIN = 1 - BIAS;

// Decode register into exponent and significand
always @(*) begin
        regExp_o = reg_i[FLen-2:SigLen] - BIAS;
        regSig_o = {1'b1, reg_i[SigLen-1:0]};
        if (class_o[CLASS_BIT_SUB]) begin
                regExp_o = EMIN - lshamt;
                regSig_o = regSig_o << lshamt;
        end
end
endmodule
/* verilator lint_on WIDTH */

