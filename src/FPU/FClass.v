/*************************************************
 *File----------FClass.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 20:06:53 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module FClass (
        input  wire        [31:0] reg_i,
        output reg  signed [9:0]  regExp_o,
        output reg         [23:0] regSig_o,
        output wire        [5:0]  class_o,
        output wire        [9:0]  fullClass_o
);

wire regExpZ   = (reg_i[30:23] == 0);
wire regExp255 = (reg_i[30:23] == 255);
wire regSigniZ = (reg_i[22:0]  == 0);

assign class_o = {
         regExp255 &  reg_i[22],                  // 5: quiet NaN
         regExp255 & !reg_i[22] & (|reg_i[21:0]), // 4: sig NaN
         regExp255 &  regSigniZ,                  // 3: infinity
        !regExpZ   & !regExp255,                  // 2: normal
         regExpZ   & !regSigniZ,                  // 1: subnormal
         regExpZ   &  regSigniZ                   // 0: 0
        };

assign fullClass_o = {
        regExp255   &  reg_i[22],                 // 9: quiet NaN
        regExp255   & !reg_i[22] & (|reg_i[21:0]),// 8: sig NaN
        !reg_i[31]  &  regExp255 &  regSigniZ,    // 7: +infinity
        !reg_i[31]  & !regExpZ   & !regExp255,    // 6: +normal
        !reg_i[31]  &  regExpZ   & !regSigniZ,    // 5: +subnormal
        !reg_i[31]  &  regExpZ   &  regSigniZ,    // 4: +0
        reg_i[31]   &  regExpZ   &  regSigniZ,    // 3: -0
        reg_i[31]   &  regExpZ   & !regSigniZ,    // 2: -subnormal
        reg_i[31]   & !regExpZ   & !regExp255,    // 1: -normal
        reg_i[31]   &  regExp255 &  regSigniZ     // 0: -infinity
        };

localparam CLASS_ZERO = 0;
localparam CLASS_SUB  = 1;
localparam CLASS_NORM = 2;
localparam CLASS_INF  = 3;
localparam CLASS_SNAN = 4;
localparam CLASS_QNAN = 5;

// First bit set = 31 - clz
wire [4:0] sigClz;
CLZ #(.W_IN(32))clz({9'b0, reg_i[22:0]}, sigClz);
// Shift so leading 1 is at bit 23: shamt = 23 - first_bit_set = 23 - (31 - clz) = clz - 8
wire [4:0] lshamt = sigClz - 8;

// Decode register into exponent and significand
always @(*) begin
        regExp_o = reg_i[30:23] - 127;
        regSig_o = {1'b1, reg_i[22:0]};
        if (class_o[CLASS_SUB]) begin
                regExp_o = -126 - lshamt;
                regSig_o = regSig_o << lshamt;
        end
end
endmodule
/* verilator lint_on WIDTH */

