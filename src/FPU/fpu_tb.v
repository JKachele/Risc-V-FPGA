/*************************************************
 *File----------fpu_tb.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 16, 2025 15:38:56 UTC
 ************************************************/

`ifdef TB
module fpu_tb;

reg signed [31:0] intIn;
reg         fcvtU;
wire [31:0] fcvtswOut;
FCVTSW fcvtsw(
        .rs1_i(intIn),
        .fcvtU_i(fcvtU),
        .fcvtswOut_o(fcvtswOut)
);

initial begin
        $monitor("%d -> %x", intIn, fcvtswOut);
        $dumpfile("fpu_tb.vcd");
        $dumpvars(0, fpu_tb);
end

initial begin
        #0  assign intIn = 0; assign fcvtU = 0;
        #10 assign intIn = 1;
        #10 assign intIn = 2;
        #10 assign intIn = 3;
        #10 assign intIn = 4;
        #10 assign intIn = 100;
        #10 assign intIn = 10000;
        #10 assign intIn = 8726345;
        #10 assign intIn = -82347;
        #10 assign fcvtU = 1;
        $finish;
end

endmodule
`endif

