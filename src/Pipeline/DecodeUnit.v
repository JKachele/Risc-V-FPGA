/*************************************************
 *File----------DecodeUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 15:52:48 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module DecodeUnit #(
        parameter BP_ADDR_BITS = 12,
        parameter BHT_SIZE = 1 << BP_ADDR_BITS,
        parameter BH_BITS = 9
)(
        input  wire        clk_i,
        input  wire        reset_i,
        // Pipeline Control Signals
        input  wire        D_stall_i,
        input  wire        D_flush_i,
        input  wire        E_flush_i,
        input  wire        E_stall_i,
        input  wire        E_takeBranch_i,
        output wire        D_predictPC_o,
        output wire [31:0] D_PCprediction_o,
        output wire        dataHazard_o,
        // Fetch Unit Interface
        input  wire [31:0] FD_PC_i,
        input  wire [31:0] FD_instr_i,
        input  wire        FD_nop_i,
        // Execute Unit Interface
        output reg  [31:0] DE_PC_o,
        output reg  [31:0] DE_instr_o,
        output reg         DE_nop_o,
        output reg         DE_isLUI_o,
        output reg         DE_isAUIPC_o,
        output reg         DE_isJAL_o,
        output reg         DE_isJALR_o,
        output reg         DE_isBranch_o,
        output reg         DE_isLoad_o,
        output reg         DE_isStore_o,
        output reg         DE_isALUI_o,
        output reg         DE_isALUR_o,
        output reg         DE_isFENCE_o,
        output reg         DE_isSYS_o,
        output reg         DE_isEBREAK_o,
        output reg         DE_isCSR_o,
        output reg         DE_isAMO_o,
        output reg         DE_isFPU_o,
        output reg  [5:0]  DE_rdId_o,
        output reg  [5:0]  DE_rs1Id_o,
        output reg  [5:0]  DE_rs2Id_o,
        output reg  [5:0]  DE_rs3Id_o,
        output reg  [11:0] DE_csrId_o,
        output reg  [2:0]  DE_funct3_o,
        output reg  [7:0]  DE_funct3_is_o,
        output reg  [6:0]  DE_funct7_o,
        output reg  [31:0] DE_Iimm_o,
        output reg  [31:0] DE_Simm_o,
        output reg  [31:0] DE_Bimm_o,
        output reg  [31:0] DE_Uimm_o,
        output reg         DE_isRV32M_o,
        output reg         DE_isMUL_o,
        output reg         DE_isDIV_o,
        output reg         DE_wbEnable_o,
        output reg         DE_predictBranch_o,
        output reg  [BP_ADDR_BITS-1:0] DE_bhtIndex_o,
        output reg  [31:0] DE_predictRA_o
);

localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;

/*
 * Used RISC-V ISM Volume I: Version 20250508, Ch. 35, Page 609
 * The RISC-V (RV32G) opcodes inst[6:2] (inst[1:0]=11)
 * | inst[6:5] |   000  |   001  |   010  |   011  |   100  |   101  |
 * +-----------+--------+--------+--------+--------+--------+--------+
 * |        00 | LOAD   | FLOAD  |        | FENCE  | ALUImm | AUIPC  |
 * |        01 | STORE  | FSTORE |        | AMO    | ALUreg | LUI    |
 * |        10 | FMADD  | FMSUB  | FNMSUB | FNMADD | FPU    |        |
 * |        11 | BRANCH | JALR   |        | JAL    | SYSTEM |        |
 * +-----------+--------+--------+--------+--------+--------+--------+
 *
 * ALUreg  // rd <- rs1 OP rs2
 * ALUimm  // rd <- rs1 OP Iimm
 * Branch  // if(rs1 OP rs2) PC<-PC+Bimm
 * JALR    // rd <- PC+4; PC<-rs1+Iimm
 * JAL     // rd <- PC+4; PC<-PC+Jimm
 * AUIPC   // rd <- PC + Uimm
 * LUI     // rd <- Uimm
 * Load    // rd <- mem[rs1+Iimm]
 * Store   // mem[rs1+Simm] <- rs2
 * Fence   // special
 * SYSTEM  // special
 */

/*--------------INSTRUCTION DECODING--------------*/
// 11 RV32I OpCodes
// bits [1:0] are always 00 for all opcodes
wire D_isLUI      = (FD_instr_i[6:2] == 5'b01101);
wire D_isAUIPC    = (FD_instr_i[6:2] == 5'b00101);
wire D_isJAL      = (FD_instr_i[6:2] == 5'b11011);
wire D_isJALR     = (FD_instr_i[6:2] == 5'b11001);
wire D_isBranch   = (FD_instr_i[6:2] == 5'b11000);
wire D_isLoad     = (FD_instr_i[6:3] == 4'b0000);  // instr[2]: FLW
wire D_isStore    = (FD_instr_i[6:3] == 4'b0100);  // instr[2]: FSW
wire D_isALUI     = (FD_instr_i[6:2] == 5'b00100);
wire D_isALUR     = (FD_instr_i[6:2] == 5'b01100);
wire D_isFENCE    = (FD_instr_i[6:2] == 5'b00011);
wire D_isSYS      = (FD_instr_i[6:2] == 5'b11100);
wire D_isAMO      = (FD_instr_i[6:2] == 5'b01011);
wire D_isFPU      = (FD_instr_i[6:5] == 2'b10);

// Instruction Functions
wire [2:0] D_funct3 = FD_instr_i[14:12];
wire [6:0] D_funct7 = FD_instr_i[31:25];

// Source and dest registers
wire [4:0] D_raw_rdId  = FD_instr_i[11:7];
wire [4:0] D_raw_rs1Id = FD_instr_i[19:15];
wire [4:0] D_raw_rs2Id = FD_instr_i[24:20];
wire [4:0] D_raw_rs3Id = FD_instr_i[31:27]; // For FMA ops

// Immediate Values
wire [31:0] D_Iimm =
        {{21{FD_instr_i[31]}}, FD_instr_i[30:20]};
wire [31:0] D_Simm =
        {{21{FD_instr_i[31]}}, FD_instr_i[30:25],FD_instr_i[11:7]};
wire [31:0] D_Bimm =
        {{20{FD_instr_i[31]}}, FD_instr_i[7],FD_instr_i[30:25],FD_instr_i[11:8],1'b0};
wire [31:0] D_Uimm =
        {FD_instr_i[31], FD_instr_i[30:12], {12{1'b0}}};
wire [31:0] D_Jimm =
        {{12{FD_instr_i[31]}}, FD_instr_i[19:12],FD_instr_i[20],FD_instr_i[30:21],1'b0};

wire D_isEBREAK = D_isSYS & (D_funct3 == 3'b000) & FD_instr_i[20] & ~FD_instr_i[22];

wire D_isCSR = D_isSYS & ((D_funct3 != 3'b000) & (D_funct3 != 3'b100));
wire [11:0] D_csrId = FD_instr_i[31:20];

wire D_isLoadOrAMO  = D_isLoad  || D_isAMO;
wire D_isStoreOrAMO = D_isStore || D_isAMO;

wire D_readsRs1 = !(D_isJAL || D_isLUI || D_isAUIPC);

wire D_readsRs2 = (D_isStoreOrAMO || D_isBranch || D_isALUR || D_isFPU);

wire D_isRV32M = D_isALUR  & FD_instr_i[25];
wire D_isMUL   = D_isRV32M & !FD_instr_i[14];
wire D_isDIV   = D_isRV32M &  FD_instr_i[14];

// rd is a FP reg if op is FLW, FMA, R-Type FPU, FCVT.S.W(U), or FMV.W.X
wire D_rdIsFP = (FD_instr_i[6:2] == 5'b00001)  || // FLW
        (FD_instr_i[6:4] == 3'b100)            || // FMA F(N)MADD / F(N)MSUB
        (D_isFPU && ((FD_instr_i[31] == 1'b0)  || // R-Type FPU Instr
        (FD_instr_i[31:28] == 4'b1101)         || // FCVT.S.W(U)
        (FD_instr_i[31:28] == 4'b1111)));         // FMV.W.X

// rs1 is a FP reg if op is FPU except for FCVT.S.W(U) and FMV.W.X
wire D_rs1IsFP = D_isFPU &&
        !((FD_instr_i[4:2]   == 3'b100) && (
          (FD_instr_i[31:28] == 4'b1101) ||     // FCVT.S.W(U)
          (FD_instr_i[31:28] == 4'b1111)));      // FMV.W.X

// rs2 is a FP reg if op is FPU or FSW
wire D_rs2IsFP = D_isFPU || (D_isStore && FD_instr_i[2]);

// Floating Point Registers are encoded with id[5] == 1
wire [5:0] D_rdId =  {D_rdIsFP , D_raw_rdId };
wire [5:0] D_rs1Id = {D_rs1IsFP, D_raw_rs1Id};
wire [5:0] D_rs2Id = {D_rs2IsFP, D_raw_rs2Id};
wire [5:0] D_rs3Id = {1'b1     , D_raw_rs3Id};

/*----------------BRANCH PREDICTION---------------*/
reg [1:0] BHT[BHT_SIZE-1:0]; // Branch History Table

reg [BH_BITS-1:0] branchHist;

always @(posedge clk_i) begin
        if (!E_stall_i && DE_isBranch_o) begin
                branchHist <= {E_takeBranch_i, branchHist[BH_BITS-1:1]};
                BHT[DE_bhtIndex_o] <= 
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b000 ? 2'b00 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b001 ? 2'b00 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b010 ? 2'b01 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b011 ? 2'b10 :		
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b100 ? 2'b01 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b101 ? 2'b10 :
                        {E_takeBranch_i, BHT[DE_bhtIndex_o]} == 3'b110 ? 2'b11 :
                        2'b11 ;
        end
end

wire [BP_ADDR_BITS-1:0] D_bhtIndex =
        FD_PC_i[BP_ADDR_BITS+1:2] ^ (branchHist << (BP_ADDR_BITS - BH_BITS));

wire D_predictBranch = BHT[D_bhtIndex][1];

/*--------------RETURN ADDRESS STACK--------------*/
reg [31:0] RAS_0;
reg [31:0] RAS_1;
reg [31:0] RAS_2;
reg [31:0] RAS_3;

assign D_predictPC_o = !FD_nop_i &&
        (D_isJAL || D_isJALR || (D_isBranch && D_predictBranch));

assign D_PCprediction_o = D_isJALR ? RAS_0 :
        (FD_PC_i + (D_isJAL ? D_Jimm : D_Bimm));

always @(posedge clk_i) begin
        if (!D_stall_i && !FD_nop_i && !D_flush_i) begin
                if ((D_isJAL || D_isJALR) && D_rdId == 1) begin
                        RAS_3 <= RAS_2;
                        RAS_2 <= RAS_1;
                        RAS_1 <= RAS_0;
                        RAS_0 <= FD_PC_i + 4;
                end
                if(D_isJALR && D_rdId==0 && (D_rs1Id==1 || D_rs1Id==5)) begin
                        RAS_0 <= RAS_1;
                        RAS_1 <= RAS_2;
                        RAS_2 <= RAS_3;
                end
        end
end

/*------------------------------------------------*/
always @(posedge clk_i) begin
        if (!D_stall_i) begin
                DE_PC_o <= FD_PC_i;
                DE_instr_o <= (E_flush_i | FD_nop_i) ? NOP : FD_instr_i;
                DE_nop_o <= 1'b0;

                DE_isLUI_o    <= D_isLUI;
                DE_isAUIPC_o  <= D_isAUIPC;
                DE_isJAL_o    <= D_isJAL;
                DE_isJALR_o   <= D_isJALR;
                DE_isBranch_o <= D_isBranch;
                DE_isLoad_o   <= D_isLoad;
                DE_isStore_o  <= D_isStore;
                DE_isALUI_o   <= D_isALUI;
                DE_isALUR_o   <= D_isALUR;
                DE_isFENCE_o  <= D_isFENCE;
                DE_isSYS_o    <= D_isSYS;
                DE_isEBREAK_o <= D_isEBREAK;
                DE_isCSR_o    <= D_isCSR;
                DE_isAMO_o    <= D_isAMO;
                DE_isFPU_o    <= D_isFPU;

                DE_rdId_o  <= D_rdId;
                DE_rs1Id_o <= D_rs1Id;
                DE_rs2Id_o <= D_rs2Id;
                DE_rs3Id_o <= D_rs3Id;
                DE_csrId_o <= D_csrId;

                DE_funct3_o <= D_funct3;
                DE_funct3_is_o <= 8'b00000001 << FD_instr_i[14:12];
                DE_funct7_o <= D_funct7;

                DE_Iimm_o <= D_Iimm;
                DE_Simm_o <= D_Simm;
                DE_Bimm_o <= D_Bimm;
                DE_Uimm_o <= D_Uimm;

                DE_isRV32M_o <= D_isRV32M;
                DE_isMUL_o   <= D_isMUL;
                DE_isDIV_o   <= D_isDIV;

                DE_wbEnable_o <= ~(D_isBranch | D_isStore);

                DE_predictBranch_o <= D_predictBranch;
                DE_bhtIndex_o <= D_bhtIndex;
                DE_predictRA_o <= RAS_0;
        end

        if (E_flush_i || FD_nop_i) begin
                DE_instr_o    <= NOP;
                DE_nop_o      <= 1'b1;
                DE_isLUI_o    <= 1'b0;
                DE_isAUIPC_o  <= 1'b0;
                DE_isJAL_o    <= 1'b0;
                DE_isJALR_o   <= 1'b0;
                DE_isBranch_o <= 1'b0;
                DE_isLoad_o   <= 1'b0;
                DE_isStore_o  <= 1'b0;
                DE_isALUI_o   <= 1'b0;
                DE_isALUR_o   <= 1'b0;
                DE_isFENCE_o  <= 1'b0;
                DE_isSYS_o    <= 1'b0;
                DE_isEBREAK_o <= 1'b0;
                DE_isCSR_o    <= 1'b0;
                DE_isAMO_o    <= 1'b0;
                DE_isFPU_o    <= 1'b0;
                DE_isRV32M_o  <= 1'b0;
                DE_isMUL_o    <= 1'b0;
                DE_isDIV_o    <= 1'b0;
                DE_wbEnable_o <= 1'b0;
        end
end

wire rs1Hazard = D_readsRs1 && (D_rs1Id == DE_rdId_o);
wire rs2Hazard = D_readsRs2 && (D_rs2Id == DE_rdId_o);

assign dataHazard_o = !FD_nop_i &&
        ((DE_isLoad_o || DE_isAMO_o || DE_isCSR_o) && (rs1Hazard || rs2Hazard)) ||
        (D_isLoadOrAMO && (DE_isStore_o || DE_isAMO_o));

endmodule
/* verilator lint_on WIDTH */

