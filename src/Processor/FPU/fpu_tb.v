/*************************************************
 *File----------fpu_tb.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 16, 2025 15:38:56 UTC
 ************************************************/

`ifdef TB
module fpu_tb;

localparam ONE = 32'h3F800000;

reg  [31:0] a;
reg  [31:0] b;
reg  [31:0] c;

reg  [31:0] instr;

wire [31:0] fpuOut;
FPU2 fpu(
        .clk_i(1'b0),
        .reset_i(1'b0),
        .fpuEnable_i(1'b1),
        .instr_i(instr),
        .rs1_i(a),
        .rs2_i(b),
        .rs3_i(c),
        .rm_i(3'b000),
        .busy_o(),
        .fpuOut_o(fpuOut)
);

initial begin
        $monitor("a(%x), b(%x), c(%x), out(%x)", a, b, c, fpuOut);
        $dumpfile("fpu_tb.vcd");
        $dumpvars(0, fpu_tb);
end

initial begin
        #0 $display("\n1 * 1 + 1 = 2");
           assign a = ONE; assign b = ONE; assign c = ONE; assign instr = 32'h68c5f543;

        #10 $display("\n1 * 2 + 3 = 5");
           assign a = ONE; assign b = 32'h40000000; assign c = 32'h40400000;

        #10 $display("\n35187.3135 * 32158.3257 = 1131565088.04100695");
           assign a = 32'h47097350; assign b = 32'h46FB3CA7; assign instr = 32'h10c5f553;

        #10 $display("\n1131565088.04100695 + 325144.57941 = 1131890232.62041695");
           assign a = 32'h4E86E4A0; assign b = 32'h489EC313; assign instr = 32'h00c5f553;

        #10 $display("\n35187.3135 * 32158.3257 + 325144.57941 = 1131890232.62041695");
           assign a = 32'h47097350; assign b = 32'h46FB3CA7; assign c = 32'h489EC313;
           assign instr = 32'h68c5f543;

        #10 $finish;
end

endmodule
`endif

