/*************************************************
 *File----------SOC.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:00 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module SOC (
        input  wire CLK,
        input  wire RESET,
        output wire [3:0] LEDS,
        input  wire RXD,
        output wire TXD
);

/*verilator public_flat_rw_on*/
wire clk;
wire reset;
/*verilator public_off*/

//Memory
wire [31:0] IMemAddr;
wire [31:0] IMemData;
wire [31:0] DMemRAddr;
wire [63:0] DMemRData;
wire [31:0] DMemWAddr;
wire [63:0] DMemWData;
wire [4:0]  DMemWMask;

// IO
wire [31:0] IO_memAddr;
wire [31:0] IO_memRData;
wire [31:0] IO_memWData;
wire        IO_memWr;

Processor CPU(
        .clk_i(clk),
        .reset_i(reset),
        .IMemAddr_o(IMemAddr),
        .IMemData_i(IMemData),
        .DMemRAddr_o(DMemRAddr),
        .DMemRData_i(DMemRData),
        .DMemWAddr_o(DMemWAddr),
        .DMemWData_o(DMemWData),
        .DMemWMask_o(DMemWMask),
        .IO_memAddr_o(IO_memAddr),
        .IO_memRData_i(IO_memRData),
        .IO_memWData_o(IO_memWData),
        .IO_memWr_o(IO_memWr)
);

Memory mem(
        .clk_i(clk),
        .IMemAddr_i(IMemAddr),
        .IMemData_o(IMemData),
        .DMemRAddr_i(DMemRAddr),
        .DMemRData_o(DMemRData),
        .DMemWAddr_i(DMemWAddr),
        .DMemWData_i(DMemWData),
        .DMemWMask_i(DMemWMask)
);

IO io(
        .clk_i(clk),
        .reset_i(reset),
        .IO_memAddr_i(IO_memAddr),
        .IO_memRData_o(IO_memRData),
        .IO_memWData_i(IO_memWData),
        .IO_memWr_i(IO_memWr),
        .leds_o(LEDS),
        .txd_o(TXD)
);

Clockworks #(
`ifdef BENCH
        .SLOW(0)
`else
        .SLOW(2)        // Slow clock by 2^SLOW
`endif
)CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(reset)
);

endmodule
/* verilator lint_on WIDTH */

