/*************************************************
 *File----------Processor.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:17 UTC
 ************************************************/
// `include "Pipeline/FetchUnit.v"
// `include "Pipeline/DecodeUnit.v"
// `include "Pipeline/ExecuteUnit.v"
// `include "Pipeline/MemoryUnit.v"

module Processor(
        input  wire clk_i,
        input  wire reset_i,
        // Registers
        input  wire [31:0] rs1Data_i,
        input  wire [31:0] rs2Data_i,
        output wire [4:0]  rdId_o,
        output wire [31:0] rdData_o,
        output wire [4:0]  rs1Id_o,
        output wire [4:0]  rs2Id_o,
        // Control and Status Registers
        output wire [11:0] csrWAddr_o,
        output wire [31:0] csrWData_o,
        output wire [11:0] csrRAddr_o,
        input  wire [31:0] csrRData_i,
        output wire        csrInstStep_o,
        // Memory
        output wire [31:0] IMemAddr_o,
        input  wire [31:0] IMemData_i,
        output wire [31:0] DMemRAddr_o,
        input  wire [31:0] DMemRData_i,
        output wire [31:0] DMemWAddr_o,
        output wire [31:0] DMemWData_o,
        output wire [3:0]  DMemWMask_o,
        // Memory Mapped IO
        output wire [31:0] IO_memAddr_o,
        input  wire [31:0] IO_memRData_i,
        output wire [31:0] IO_memWData_o,
        output wire        IO_memWr_o
);

/******************************************************************************
 -------------------------------CONTROL SIGNALS--------------------------------
 ******************************************************************************/

wire HALT;
wire F_stall;
wire D_stall;
wire E_stall;
wire D_flush;
wire E_flush;
wire M_flush;
wire dataHazard;
wire D_predictPC;
wire [31:0] D_PCprediction;

ControlUnit control(
        .HALT_i(HALT),
        .dataHazard_i(dataHazard),
        .aluBusy_i(aluBusy),
        .E_correctPC_i(E_correctPC),
        .F_stall_o(F_stall),
        .D_stall_o(D_stall),
        .E_stall_o(E_stall),
        .D_flush_o(D_flush),
        .E_flush_o(E_flush),
        .M_flush_o(M_flush)
);

/******************************************************************************
 ----------------------------------FETCH UNIT----------------------------------
 ******************************************************************************/
wire [31:0] FD_PC;
wire [31:0] FD_instr;
wire        FD_nop;
FetchUnit fetch(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .F_stall_i(F_stall),
        .D_flush_i(D_flush),
        .D_predictPC_i(D_predictPC),
        .D_PCprediction_i(D_PCprediction),
        .EM_correctPC_i(EM_correctPC),
        .EM_PCcorrection_i(EM_PCcorrection),
        .IMemAddr_o(IMemAddr_o),
        .IMemData_i(IMemData_i),
        .FD_PC_o(FD_PC),
        .FD_instr_o(FD_instr),
        .FD_nop_o(FD_nop)
);
/******************************************************************************
 ---------------------------------DECODE UNIT----------------------------------
 ******************************************************************************/
wire [31:0] DE_PC;
wire [31:0] DE_instr;
wire        DE_nop;

wire        DE_isLUI;
wire        DE_isAUIPC;
wire        DE_isJAL;
wire        DE_isJALR;
wire        DE_isBranch;
wire        DE_isLoad;
wire        DE_isStore;
wire        DE_isALUI;
wire        DE_isALUR;
wire        DE_isFENCE;
wire        DE_isSYS;
wire        DE_isEBREAK;
wire        DE_isCSR;

wire [4:0]  DE_rdId;
wire [4:0]  DE_rs1Id;
wire [4:0]  DE_rs2Id;
wire [11:0] DE_csrId;

wire [2:0]  DE_funct3;
wire [7:0]  DE_funct3_is;
wire [6:0]  DE_funct7;

wire [31:0] DE_Iimm;
wire [31:0] DE_Simm;
wire [31:0] DE_Bimm;
wire [31:0] DE_Uimm;

wire        DE_isRV32M;
wire        DE_isMUL;
wire        DE_isDIV;

wire        DE_wbEnable; // !isBranch && !isStore && rdId != 0

wire        DE_predictBranch;
wire [BP_ADDR_BITS-1:0] DE_bhtIndex;
wire [31:0] DE_predictRA;

localparam BP_ADDR_BITS = 12;
localparam BHT_SIZE = 1 << BP_ADDR_BITS;
localparam BH_BITS = 9;

DecodeUnit #(
        .BP_ADDR_BITS(BP_ADDR_BITS),
        .BHT_SIZE(BHT_SIZE),
        .BH_BITS(BH_BITS)
)decode(
       .clk_i(clk_i),
       .reset_i(reset_i),
       .D_stall_i(D_stall),
       .D_flush_i(D_flush),
       .E_flush_i(E_flush),
       .E_stall_i(E_stall),
       .E_takeBranch_i(E_takeBranch),
       .D_predictPC_o(D_predictPC),
       .D_PCprediction_o(D_PCprediction),
       .dataHazard_o(dataHazard),
       .FD_PC_i(FD_PC),
       .FD_instr_i(FD_instr),
       .FD_nop_i(FD_nop),
       .DE_PC_o(DE_PC),
       .DE_instr_o(DE_instr),
       .DE_nop_o(DE_nop),
       .DE_isLUI_o(DE_isLUI),
       .DE_isAUIPC_o(DE_isAUIPC),
       .DE_isJAL_o(DE_isJAL),
       .DE_isJALR_o(DE_isJALR),
       .DE_isBranch_o(DE_isBranch),
       .DE_isLoad_o(DE_isLoad),
       .DE_isStore_o(DE_isStore),
       .DE_isALUI_o(DE_isALUI),
       .DE_isALUR_o(DE_isALUR),
       .DE_isFENCE_o(DE_isFENCE),
       .DE_isSYS_o(DE_isSYS),
       .DE_isEBREAK_o(DE_isEBREAK),
       .DE_isCSR_o(DE_isCSR),
       .DE_rdId_o(DE_rdId),
       .DE_rs1Id_o(DE_rs1Id),
       .DE_rs2Id_o(DE_rs2Id),
       .DE_csrId_o(DE_csrId),
       .DE_funct3_o(DE_funct3),
       .DE_funct3_is_o(DE_funct3_is),
       .DE_funct7_o(DE_funct7),
       .DE_Iimm_o(DE_Iimm),
       .DE_Simm_o(DE_Simm),
       .DE_Bimm_o(DE_Bimm),
       .DE_Uimm_o(DE_Uimm),
       .DE_isRV32M_o(DE_isRV32M),
       .DE_isMUL_o(DE_isMUL),
       .DE_isDIV_o(DE_isDIV),
       .DE_wbEnable_o(DE_wbEnable),
       .DE_predictBranch_o(DE_predictBranch),
       .DE_bhtIndex_o(DE_bhtIndex),
       .DE_predictRA_o(DE_predictRA)
);

/******************************************************************************
 ---------------------------------EXECUTE UNIT--------------------------------*
 ******************************************************************************/
wire [31:0] EM_PC;
wire [31:0] EM_instr;
wire        EM_nop;

wire        EM_isLoad;
wire        EM_isStore;
wire        EM_isCSR;
wire [4:0]  EM_rdId;
wire [4:0]  EM_rs1Id;
wire [4:0]  EM_rs2Id;
wire [11:0] EM_csrId;
wire [31:0] EM_rs2;
wire [2:0]  EM_funct3;

wire [31:0] EM_Eresult;
wire [31:0] EM_addr;
wire [31:0] EM_Mdata;
wire        EM_correctPC;
wire [31:0] EM_PCcorrection;
wire        EM_wbEnable;

wire        E_correctPC;
wire        E_takeBranch;
wire        aluBusy;

ExecuteUnit execute(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .E_stall_i(E_stall),
        .M_flush_i(M_flush),
        .dataHazard_i(dataHazard),
        .HALT_o(HALT),
        .E_takeBranch_o(E_takeBranch),
        .E_correctPC_o(E_correctPC),
        .aluBusy_o(aluBusy),
        .rs1Id_o(rs1Id_o),
        .rs2Id_o(rs2Id_o),
        .rs1Data_i(rs1Data_i),
        .rs2Data_i(rs2Data_i),
        .DMemRAddr_o(DMemRAddr_o),
        .DMemRData_i(DMemRData_i),
        .MW_wbEnable_i(MW_wbEnable),
        .MW_rdId_i(MW_rdId),
        .MW_wbData_i(MW_wbData),
        .DE_PC_i(DE_PC),
        .DE_instr_i(DE_instr),
        .DE_nop_i(DE_nop),
        .DE_isLUI_i(DE_isLUI),
        .DE_isAUIPC_i(DE_isAUIPC),
        .DE_isJAL_i(DE_isJAL),
        .DE_isJALR_i(DE_isJALR),
        .DE_isBranch_i(DE_isBranch),
        .DE_isLoad_i(DE_isLoad),
        .DE_isStore_i(DE_isStore),
        .DE_isALUI_i(DE_isALUI),
        .DE_isALUR_i(DE_isALUR),
        .DE_isFENCE_i(DE_isFENCE),
        .DE_isSYS_i(DE_isSYS),
        .DE_isEBREAK_i(DE_isEBREAK),
        .DE_isCSR_i(DE_isCSR),
        .DE_rdId_i(DE_rdId),
        .DE_rs1Id_i(DE_rs1Id),
        .DE_rs2Id_i(DE_rs2Id),
        .DE_csrId_i(DE_csrId),
        .DE_funct3_i(DE_funct3),
        .DE_funct3_is_i(DE_funct3_is),
        .DE_funct7_i(DE_funct7),
        .DE_Iimm_i(DE_Iimm),
        .DE_Simm_i(DE_Simm),
        .DE_Bimm_i(DE_Bimm),
        .DE_Uimm_i(DE_Uimm),
        .DE_isRV32M_i(DE_isRV32M),
        .DE_isMUL_i(DE_isMUL),
        .DE_isDIV_i(DE_isDIV),
        .DE_wbEnable_i(DE_wbEnable),
        .DE_predictBranch_i(DE_predictBranch),
        .DE_predictRA_i(DE_predictRA),
        .EM_PC_o(EM_PC),
        .EM_instr_o(EM_instr),
        .EM_nop_o(EM_nop),
        .EM_isLoad_o(EM_isLoad),
        .EM_isStore_o(EM_isStore),
        .EM_isCSR_o(EM_isCSR),
        .EM_rdId_o(EM_rdId),
        .EM_rs1Id_o(EM_rs1Id),
        .EM_rs2Id_o(EM_rs2Id),
        .EM_csrId_o(EM_csrId),
        .EM_rs2_o(EM_rs2),
        .EM_funct3_o(EM_funct3),
        .EM_Eresult_o(EM_Eresult),
        .EM_addr_o(EM_addr),
        .EM_Mdata_o(EM_Mdata),
        .EM_correctPC_o(EM_correctPC),
        .EM_PCcorrection_o(EM_PCcorrection),
        .EM_wbEnable_o(EM_wbEnable)
);

/******************************************************************************
 ------------------------------MEMORY ACCESS UNIT-----------------------------*
 ******************************************************************************/
wire [31:0] MW_PC;
wire [31:0] MW_instr;
wire        MW_nop;

wire [4:0]  MW_rdId;
wire [31:0] MW_wbData;
wire        MW_wbEnable;

MemoryUnit memory(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .DMemWAddr_o(DMemWAddr_o),
        .DMemWData_o(DMemWData_o),
        .DMemWMask_o(DMemWMask_o),
        .IO_memAddr_o(IO_memAddr_o),
        .IO_memRData_i(IO_memRData_i),
        .IO_memWData_o(IO_memWData_o),
        .IO_memWr_o(IO_memWr_o),
        .csrWAddr_o(csrWAddr_o),
        .csrWData_o(csrWData_o),
        .csrRAddr_o(csrRAddr_o),
        .csrRData_i(csrRData_i),
        .csrInstStep_o(csrInstStep_o),
        .EM_PC_i(EM_PC),
        .EM_instr_i(EM_instr),
        .EM_nop_i(EM_nop),
        .EM_isLoad_i(EM_isLoad),
        .EM_isStore_i(EM_isStore),
        .EM_isCSR_i(EM_isCSR),
        .EM_rdId_i(EM_rdId),
        .EM_rs1Id_i(EM_rs1Id),
        .EM_rs2Id_i(EM_rs2Id),
        .EM_csrId_i(EM_csrId),
        .EM_rs2_i(EM_rs2),
        .EM_funct3_i(EM_funct3),
        .EM_Eresult_i(EM_Eresult),
        .EM_addr_i(EM_addr),
        .EM_Mdata_i(EM_Mdata),
        .EM_correctPC_i(EM_correctPC),
        .EM_PCcorrection_i(EM_PCcorrection),
        .EM_wbEnable_i(EM_wbEnable),
        .MW_PC_o(MW_PC),
        .MW_instr_o(MW_instr),
        .MW_nop_o(MW_nop),
        .MW_rdId_o(MW_rdId),
        .MW_wbData_o(MW_wbData),
        .MW_wbEnable_o(MW_wbEnable)
);
/******************************************************************************
 -------------------------------WRITE BACK UNIT-------------------------------- 
 ******************************************************************************/

WriteBackUnit writeback(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .rdId_o(rdId_o),
        .rdData_o(rdData_o),
        .MW_PC_i(MW_PC),
        .MW_instr_i(MW_instr),
        .MW_nop_i(MW_nop),
        .MW_rdId_i(MW_rdId),
        .MW_wbData_i(MW_wbData),
        .MW_wbEnable_i(MW_wbEnable)
);

/*----------------------------------------------------------------------------*/
`ifdef BENCH
        // `include "../Extern/riscv_disassembly.v"
        // integer nbBranch = 0;
        // integer nbBranchHit = 0;
        // integer nbJAL  = 0;
        // integer nbJALR = 0;
        // integer nbJALRhit = 0;
        // integer nbLoad = 0;
        // integer nbStore = 0;
        // integer nbLoadHazard = 0;
        // integer nbRV32M = 0;
        // integer nbMUL = 0;
        // integer nbDIV = 0;

        always @(posedge clk_i) begin
                // if(!reset_i & !D_stall) begin
                //         if(riscv_disasm_isBranch(DE_instr)) begin
                //                 nbBranch <= nbBranch + 1;
                //                 if(E_takeBranch == DE_predictBranch) begin
                //                         nbBranchHit <= nbBranchHit + 1;
                //                 end
                //         end
                //         if(riscv_disasm_isJAL(DE_instr)) begin
                //                 nbJAL <= nbJAL + 1;
                //         end
                //         if(riscv_disasm_isJALR(DE_instr)) begin
                //                 nbJALR <= nbJALR + 1;
                //                 if(DE_predictRA == E_JALRaddr) begin
                //                         nbJALRhit <= nbJALRhit + 1;
                //                 end
                //         end
                // end
                //
                // if(riscv_disasm_isLoad(MW_instr)) begin
                //         nbLoad <= nbLoad + 1;
                // end
                // if(riscv_disasm_isStore(MW_instr)) begin
                //         nbStore <= nbStore + 1;
                // end
                // if(riscv_disasm_isRV32M(MW_instr)) begin
                //         if(MW_instr[14]) begin
                //                 nbDIV <= nbDIV + 1;
                //         end else begin
                //                 nbMUL <= nbMUL + 1;
                //         end
                // end
                // if(dataHazard) begin
                //         nbLoadHazard <= nbLoadHazard + 1;
                // end
                if(HALT) $finish();
        end
`endif

endmodule

