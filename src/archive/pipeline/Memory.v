/*************************************************
 *File----------Memory.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:59:49 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module Memory (
        input  wire        clk_i,
        input  wire [31:0] IMemAddr_i,
        output wire [31:0] IMemData_o,
        input  wire [31:0] DMemRAddr_i,
        output wire [31:0] DMemRData_o,
        input  wire [31:0] DMemWAddr_i,
        input  wire [31:0] DMemWData_i,
        input  wire [3:0]  DMemWMask_i
);

reg [31:0] INSTMEM [0:16383];
reg [31:0] DATAMEM [0:16383];

initial begin
        $readmemh("../bin/ROM.hex",INSTMEM);
        $readmemh("../bin/RAM.hex",DATAMEM);
end

assign IMemData_o  = INSTMEM[IMemAddr_i[31:2]];
assign DMemRData_o = DATAMEM[DMemRAddr_i[31:2]];

wire [29:0] wordAddr = DMemWAddr_i[31:2];
always @(posedge clk_i) begin
        if (DMemWMask_i[0]) DATAMEM[wordAddr][ 7:0 ] <= DMemWData_i[ 7:0 ];
        if (DMemWMask_i[1]) DATAMEM[wordAddr][15:8 ] <= DMemWData_i[15:8 ];
        if (DMemWMask_i[2]) DATAMEM[wordAddr][23:16] <= DMemWData_i[23:16];
        if (DMemWMask_i[3]) DATAMEM[wordAddr][31:24] <= DMemWData_i[31:24];
end

endmodule
/* verilator lint_on WIDTH */

