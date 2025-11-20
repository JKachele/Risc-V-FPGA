/*************************************************
 *File----------SOC.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:00 UTC
 ************************************************/
`include "../Extern/Clockworks.v"
`include "../Extern/SSegDisplay.v"
`include "../Extern/LedDim.v"
`include "../Extern/txuart.v"
`include "Processor.v"

module SOC (
        input  wire CLK,
        input  wire RESET,
        output wire [15:0] LEDS,
        input  wire RXD,
        output wire TXD,
        output wire [7:0] SSEG_CA,
        output wire [7:0] SSEG_AN
);

wire clk;
wire reset;

// IO
wire [31:0] IO_memAddr;
wire [31:0] IO_memRData;
wire [31:0] IO_memWData;
wire        IO_memWr;

Processor CPU(
        .clk(clk),
        .reset(reset),
        .IO_memAddr(IO_memAddr),
        .IO_memRData(IO_memRData),
        .IO_memWData(IO_memWData),
        .IO_memWr(IO_memWr)
);

wire [13:0] IO_wordAddr = IO_memAddr[15:2];

// Output Indicators
localparam IO_LEDS_bit          = 0;
localparam IO_UART_DAT_bit      = 1;
localparam IO_UART_CTRL_bit     = 2;
localparam IO_SSEG_bit          = 3;

reg [15:0] leds;
reg [31:0] sseg;
always @(posedge clk) begin
        if (IO_memWr) begin
                if (IO_wordAddr[IO_LEDS_bit])
                        leds[15:0] <= IO_memWData[15:0];
                else if (IO_wordAddr[IO_SSEG_bit])
                        sseg <= IO_memWData;
        end
end

wire uartValid = IO_memWr & IO_wordAddr[IO_UART_DAT_bit];
wire uartBusy;

assign IO_memRData = IO_wordAddr[IO_UART_CTRL_bit] ? {22'b0, uartBusy, 9'b0}
                                                    : 32'b0;
// 115200 baud, 8-bit, no parity, 1 stop bit
localparam UART_SETUP = {1'b0, 2'b00, 1'b0, 3'b000, 24'h000364};

txuart TXUART (
        .i_clk(clk),
        .i_reset(reset),
        .i_setup(UART_SETUP),
        .i_break(0),
        .i_wr(uartValid),
        .i_data(IO_memWData[7:0]),
        .i_cts_n(0),
        .o_uart_tx(TXD),
        .o_busy(uartBusy)
);

wire ssegClk;
SSegDisplay SSegDisp (
        .clk(ssegClk),
        .num(sseg),
        .SSEG_CA(SSEG_CA),
        .SSEG_AN(SSEG_AN)
);

`ifdef BENCH
        assign LEDS = leds;
`else
        LedDim ledDim (
                .clk(CLK),
                .leds_i(leds),
                .leds_o(LEDS)
        );
`endif   


Clockworks CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(reset)
);

/* verilator lint_off PINMISSING */
// Fast clock for SSeg Display Scanning
Clockworks #(
        .SLOW(15)
) SSEG_CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(ssegClk)
);
/* verilator lint_on PINMISSING */

endmodule

