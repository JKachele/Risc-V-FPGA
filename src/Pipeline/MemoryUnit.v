/*************************************************
 *File----------MemoryUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 19:42:17 UTC
 ************************************************/

module MemoryUnit (
        input  wire clk_i,
        input  wire reset_i,
        // Pipeline Control Signals
        // Memory/IO Interface
        output wire [31:0] DMemWAddr_o,
        output wire [31:0] DMemWData_o,
        output wire [3:0]  DMemWMask_o,
        output wire [31:0] IO_memAddr_o,
        input  wire [31:0] IO_memRData_i,
        output wire [31:0] IO_memWData_o,
        output wire        IO_memWr_o,
        // CSR Interface
        output wire [11:0] csrWAddr_o,
        output wire [31:0] csrWData_o,
        output wire [11:0] csrRAddr_o,
        input  wire [31:0] csrRData_i,
        output wire        csrInstStep_o,
        // Execute Unit Interface
        input  wire [31:0] EM_PC_i,
        input  wire [31:0] EM_instr_i,
        input  wire        EM_nop_i,
        input  wire        EM_isLoad_i,
        input  wire        EM_isStore_i,
        input  wire        EM_isCSR_i,
        input  wire        EM_isAMO_i,
        input  wire [5:0]  EM_rdId_i,
        input  wire [5:0]  EM_rs1Id_i,
        input  wire [5:0]  EM_rs2Id_i,
        input  wire [11:0] EM_csrId_i,
        input  wire [31:0] EM_rs2_i,
        input  wire [2:0]  EM_funct3_i,
        input  wire [31:0] EM_Eresult_i,
        input  wire [31:0] EM_addr_i,
        input  wire [31:0] EM_Mdata_i,
        input  wire        EM_correctPC_i,
        input  wire [31:0] EM_PCcorrection_i,
        input  wire        EM_wbEnable_i,
        // Writeback Unit Interface
        output reg  [31:0] MW_PC_o,
        output reg  [31:0] MW_instr_o,
        output reg         MW_nop_o,
        output reg  [5:0]  MW_rdId_o,
        output reg  [31:0] MW_wbData_o,
        output reg         MW_wbEnable_o
);

wire M_isB = (EM_funct3_i[1:0] == 2'b00);
wire M_isH = (EM_funct3_i[1:0] == 2'b01);

/*----------------------STORE---------------------*/
reg [31:0] M_storeData;
always @(*) begin
        if (EM_isAMO_i) begin
                M_storeData = EM_Eresult_i;
        end
        // Store byte only
        else if (EM_addr_i[0]) begin
                M_storeData = {4{EM_rs2_i[7:0]}};
        end
        // Store half for [31:16] or [15:0] or store byte for [23:16]
        else if (EM_addr_i[1]) begin
                M_storeData = {2{EM_rs2_i[15:0]}};
        end
        // Store word or store byte for [7:0]
        else begin
                M_storeData = EM_rs2_i;
        end
end

reg [3:0] M_storeMask;
always @(*) begin
        if (M_isB) begin
                if (EM_addr_i[1:0] == 2'b11)
                        M_storeMask = 4'b1000;
                else if (EM_addr_i[1:0] == 2'b10)
                        M_storeMask = 4'b0100;
                else if (EM_addr_i[1:0] == 2'b01)
                        M_storeMask = 4'b0010;
                else
                        M_storeMask = 4'b0001;
        end else if (M_isH) begin
                if (EM_addr_i[1])
                        M_storeMask = 4'b1100;
                else
                        M_storeMask = 4'b0011;
        end else begin
                M_storeMask = 4'b1111;
        end
end

wire M_isIO  = EM_addr_i[22];
wire M_isRAM = !M_isIO;

assign IO_memAddr_o  = EM_addr_i;
assign IO_memWr_o    = (EM_isStore_i || EM_isAMO_i) && M_isIO;
assign IO_memWData_o = EM_rs2_i;

assign DMemWAddr_o = EM_addr_i;
assign DMemWData_o = M_storeData;
assign DMemWMask_o = {4{(EM_isStore_i | EM_isAMO_i) & M_isRAM}} & M_storeMask;

/*----------------------LOAD----------------------*/
wire [15:0] M_memHalf = EM_addr_i[1] ? EM_Mdata_i[31:16] : EM_Mdata_i[15:0];
wire [7:0]  M_memByte = EM_addr_i[0] ? M_memHalf[15:8]  : M_memHalf[7:0];

// Sign expansion
// Based on funct3[2]: 0->sign expand, 1->unsigned
wire M_loadSign = !EM_funct3_i[2] & (M_isB ? M_memByte[7] : M_memHalf[15]);

reg [31:0] M_Mdata;
always @(*) begin
        if(M_isB)
                M_Mdata = {{24{M_loadSign}}, M_memByte};
        else if(M_isH)
                M_Mdata = {{16{M_loadSign}}, M_memHalf};
        else
                M_Mdata = EM_Mdata_i;
end


/*------------------------------------------------*/
assign csrRAddr_o = EM_csrId_i;
assign csrInstStep_o  = ~MW_nop_o;

wire [31:0] M_wbData =
        (EM_isLoad_i | EM_isAMO_i) ? (M_isIO ? IO_memRData_i : M_Mdata) :
        EM_isCSR_i                 ? csrRData_i : EM_Eresult_i;

always @(posedge clk_i) begin
        MW_PC_o <= EM_PC_i;
        MW_instr_o <= EM_instr_i;
        MW_nop_o <= EM_nop_i;

        MW_rdId_o <= EM_rdId_i;
        MW_wbData_o <= M_wbData;
        MW_wbEnable_o <= EM_wbEnable_i;
end

endmodule

