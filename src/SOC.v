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

wire clk;
wire reset;

//Memory
wire [31:0] IMemAddr;
wire [31:0] IMemData;
wire [31:0] DMemRAddr;
wire [31:0] DMemRData;
wire [31:0] DMemWAddr;
wire [31:0] DMemWData;
wire [3:0]  DMemWMask;

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
        .SLOW(2)        // Slow clock by 2^SLOW
)CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(reset)
);

endmodule
/* verilator lint_on WIDTH */

