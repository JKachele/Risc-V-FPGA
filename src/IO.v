/*************************************************
 *File----------IO.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Dec 01, 2025 16:48:14 UTC
 ************************************************/

module IO (
        input  wire        clk_i,
        input  wire        reset_i,
        input  wire [31:0] IO_memAddr_i,
        output wire [31:0] IO_memRData_o,
        input  wire [31:0] IO_memWData_i,
        input  wire        IO_memWr_i,
        output wire [3:0]  leds_o,
        output wire        txd_o
);
wire [13:0] IO_wordAddr = IO_memAddr_i[15:2];

// Output Indicators
localparam IO_LEDS_bit          = 0;
localparam IO_UART_DAT_bit      = 1;
localparam IO_UART_CTRL_bit     = 2;

reg [3:0] leds;
always @(posedge clk_i) begin
        if (IO_memWr_i) begin
                if (IO_wordAddr[IO_LEDS_bit])
                        leds[3:0] <= IO_memWData_i[3:0];
        end
end

wire uartValid = IO_memWr_i & IO_wordAddr[IO_UART_DAT_bit];
wire uartBusy;

assign IO_memRData_o = IO_wordAddr[IO_UART_CTRL_bit] ? {22'b0, uartBusy, 9'b0}
                                                    : 32'b0;
// 115200 baud, 8-bit, no parity, 1 stop bit
localparam UART_SETUP = {1'b0, 2'b00, 1'b0, 3'b000, 24'h000364};

txuart TXUART (
        .i_clk(clk_i),
        .i_reset(reset_i),
        .i_setup(UART_SETUP),
        .i_break(0),
        .i_wr(uartValid),
        .i_data(IO_memWData_i[7:0]),
        .i_cts_n(0),
        .o_uart_tx(txd_o),
        .o_busy(uartBusy)
);

`ifdef BENCH
        always @(posedge clk_i) begin
                if(uartValid) begin
                        $write("%c", IO_memWData_i[7:0]);
                        $fflush(32'h8000_0001);
                end
        end
`endif

`ifdef BENCH
        assign leds_o = leds;
`else
        LedDim ledDim (
                .clk(clk_i),
                .leds_i(leds),
                .leds_o(leds_o)
        );
`endif   

endmodule

