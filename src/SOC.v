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

// Registers
wire [31:0] rs1Data;
wire [31:0] rs2Data;
wire [31:0] rs3Data;
wire [5:0]  rdId;
wire [31:0] rdData;
wire [5:0]  rs1Id;
wire [5:0]  rs2Id;
wire [5:0]  rs3Id;

// CSR
wire [11:0] csrWAddr;
wire [31:0] csrWData;
wire [11:0] csrRAddr;
wire [31:0] csrRData;
wire        csrInstStep;
wire [3:0]  csrFRM;

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
        .rs1Data_i(rs1Data),
        .rs2Data_i(rs2Data),
        .rs3Data_i(rs3Data),
        .rdId_o(rdId),
        .rdData_o(rdData),
        .rs1Id_o(rs1Id),
        .rs2Id_o(rs2Id),
        .rs3Id_o(rs3Id),
        .csrWAddr_o(csrWAddr), 
        .csrWData_o(csrWData),
        .csrRAddr_o(csrRAddr),
        .csrRData_i(csrRData),
        .csrInstStep_o(csrInstStep),
        .csrFRM_i(csrFRM),
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

RegisterFile registers(
        .clk_i(clk),
        .reset_i(reset),
        .rdId_i(rdId),
        .rdData_i(rdData),
        .rs1Id_i(rs1Id),
        .rs2Id_i(rs2Id),
        .rs3Id_i(rs3Id),
        .rs1Data_o(rs1Data),
        .rs2Data_o(rs2Data),
        .rs3Data_o(rs3Data)
);

CSR_RegFile csr(
        .clk_i(clk),
        .reset_i(reset),
        .csrWAddr_i(csrWAddr),
        .csrWData_i(csrWData),
        .csrRAddr_i(csrRAddr),
        .csrRData_o(csrRData),
        .csrInstStep_i(csrInstStep),
        .csrFRM_o(csrFRM)
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

Clockworks CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(reset)
);

endmodule
/* verilator lint_on WIDTH */

