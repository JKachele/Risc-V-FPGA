/*************************************************
 *File----------SOC.v
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Saturday Nov 01, 2025 08:24:54 EDT
 *License-------GNU GPL-3.0
 ************************************************/
`include "../Extern/Clockworks.v"
`include "../Extern/SSegDisplay.v"
`include "../Extern/LedDim.v"
`include "../Extern/txuart.v"
`include "../Extern/rxuart.v"
`include "Memory.v"
`include "Processor.v"

module SOC (
        input CLK,
        input RESET,
        output [15:0] LEDS,
        input RXD,
        output TXD,
        output [7:0] SSEG_CA,
        output [7:0] SSEG_AN
);

wire clk;
wire reset;

// Memory
wire [31:0] memAddr;
wire [31:0] memRData;
wire        memRstrb;
wire [31:0] memWData;
wire [3:0]  memWMask;

Processor CPU(
        .clk(clk),
        .reset(reset),
        .memAddr(memAddr),
        .memRData(memRData),
        .memRstrb(memRstrb),
        .memWData(memWData),
        .memWMask(memWMask)
);

wire [31:0] ramRData;
wire [29:0] memWordAddr = memAddr[31:2];
wire isIO = memAddr[22];
wire isRam = !isIO;
wire memWstrb = |memWMask;

Memory RAM(
        .clk(clk),
        .memAddr(memAddr),
        .memRData(ramRData),
        .memRstrb(isRam & memRstrb),
        .memWData(memWData),
        .memWMask({4{isRam}} & memWMask)
);

// Output Indicators
localparam IO_LEDS_bit          = 0;
localparam IO_UART_DAT_bit      = 1;
localparam IO_UART_CTRL_bit     = 2;
localparam IO_SSEG_bit          = 3;

reg [15:0] leds;
reg [31:0] sseg;
always @(posedge clk) begin
        if (isIO & memWstrb) begin
                if (memWordAddr[IO_LEDS_bit])
                        leds[15:0] <= memWData[15:0];
                else if (memWordAddr[IO_SSEG_bit])
                        sseg <= memWData;
        end
end

wire uartValid = isIO & memWstrb & memWordAddr[IO_UART_DAT_bit];
wire uartBusy;

wire uartReady;
wire [7:0] uartData;
always @(posedge uartReady) begin
        leds[7:0] <= uartData;
end

wire [31:0] IORData = memWordAddr[IO_UART_CTRL_bit] ? {22'b0, uartBusy, 9'b0}
                                                    : 32'b0;
assign memRData = isRam ? ramRData : IORData;

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

// 115200 baud, 8-bit, no parity, 1 stop bit
localparam UART_SETUP = {1'b0, 2'b00, 1'b0, 3'b000, 24'h000364};

txuart TXUART (
        .i_clk(clk),
        .i_reset(reset),
        .i_setup(UART_SETUP),
        .i_break(0),
        .i_wr(uartValid),
        .i_data(memWData[7:0]),
        .i_cts_n(0),
        .o_uart_tx(TXD),
        .o_busy(uartBusy)
);

rxuart RXUART (
        .i_clk(clk),
        .i_reset(reset),
        .i_setup(UART_SETUP),
        .i_uart_rx(RXD),
        .o_wr(uartReady),
        .o_data(uartData)
);

Clockworks CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(reset)
);

// Fast clock for SSeg Display Scanning
Clockworks #(
        .SLOW(15)
) SSEG_CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(ssegClk)
);

endmodule

