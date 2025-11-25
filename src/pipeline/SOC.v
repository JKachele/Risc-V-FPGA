/*************************************************
 *File----------SOC.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:00 UTC
 ************************************************/
`include "../Extern/Clockworks.v"
`include "../Extern/LedDim.v"
`include "../Extern/txuart.v"
`include "Processor.v"
`include "RegisterFile.v"
`include "CSR_RegFile.v"

module SOC (
        input  wire CLK,
        input  wire RESET,
        output wire [15:0] LEDS,
        input  wire RXD,
        output wire TXD
);

wire clk;
wire reset;

// Registers
wire [31:0] rs1Data;
wire [31:0] rs2Data;
wire [4:0]  rdId;
wire [31:0] rdData;
wire [4:0]  rs1Id;
wire [4:0]  rs2Id;

// IO
wire [31:0] IO_memAddr;
wire [31:0] IO_memRData;
wire [31:0] IO_memWData;
wire        IO_memWr;

// CSR
wire [11:0] csrWAddr;
wire [31:0] csrWData;
wire [11:0] csrRAddr;
wire [31:0] csrRData;
wire        csrInstStep;

Processor CPU(
        .clk_i(clk),
        .reset_i(reset),
        .rs1Data_i(rs1Data),
        .rs2Data_i(rs2Data),
        .rdId_o(rdId),
        .rdData_o(rdData),
        .rs1Id_o(rs1Id),
        .rs2Id_o(rs2Id),
        .IO_memAddr_o(IO_memAddr),
        .IO_memRData_i(IO_memRData),
        .IO_memWData_o(IO_memWData),
        .IO_memWr_o(IO_memWr),
        .csrWAddr_o(csrWAddr), 
        .csrWData_o(csrWData),
        .csrRAddr_o(csrRAddr),
        .csrRData_i(csrRData),
        .csrInstStep_o(csrInstStep)
);

RegisterFile registers(
        .clk_i(clk),
        .reset_i(reset),
        .rdId_i(rdId),
        .rdData_i(rdData),
        .rs1Id_i(rs1Id),
        .rs2Id_i(rs2Id),
        .rs1Data_o(rs1Data),
        .rs2Data_o(rs2Data)
);

CSR_RegFile csr(
        .clk_i(clk),
        .reset_i(reset),
        .csrWAddr_i(csrWAddr),
        .csrWData_i(csrWData),
        .csrRAddr_i(csrRAddr),
        .csrRData_o(csrRData),
        .csrInstStep_i(csrInstStep)
);

wire [13:0] IO_wordAddr = IO_memAddr[15:2];

// Output Indicators
localparam IO_LEDS_bit          = 0;
localparam IO_UART_DAT_bit      = 1;
localparam IO_UART_CTRL_bit     = 2;

reg [15:0] leds;
always @(posedge clk) begin
        if (IO_memWr) begin
                if (IO_wordAddr[IO_LEDS_bit])
                        leds[15:0] <= IO_memWData[15:0];
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

`ifdef BENCH
        always @(posedge clk) begin
                if(uartValid) begin
                        $write("%c", IO_memWData[7:0]);
                        $fflush(32'h8000_0001);
                end
        end
`endif

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

endmodule

