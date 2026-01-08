/*************************************************
 *File----------DecodeUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 15:52:48 UTC
 ************************************************/

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
        // CSR Interface
        input  wire [63:0] csrMStatus_i,
        input  wire [63:0] csrMedeleg_i,
        input  wire [31:0] csrMtvec_i,
        input  wire [31:0] csrMepc_i,
        input  wire [31:0] csrStvec_i,
        input  wire [31:0] csrSepc_i,
        output wire [6:0]  csrMStatusSet_o, // {MPP[1:0], MPIE, MIE, SPP, SPIE, SIE}
        output wire [31:0] csrMepcSet_o,
        output wire [31:0] csrMCauseSet_o,
        output wire [31:0] csrSepcSet_o,
        output wire [31:0] csrSCauseSet_o,
        output wire        csrTrapSetEn_o,
        input  wire [1:0]  privilege_i,
        output wire [1:0]  privilegeSet_o,
        output wire        privilegeSetEn_o,
        // Fetch Unit Interface
        input  wire [31:0] FD_PC_i,
        input  wire [31:0] FD_instr_i,
        input  wire        FD_isRV32C_i,
        input  wire        FD_nop_i,
        // Execute Unit Interface
        output reg  [31:0] DE_PC_o,
        output reg  [31:0] DE_instr_o,
        output reg         DE_isRV32C_o,
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

/*------------Instruction Decompression-----------*/
wire [31:0] D_instr;
Decompressor decomp(FD_instr_i, D_instr);

/*--------------INSTRUCTION DECODING--------------*/
// 11 RV32I OpCodes
// bits [1:0] are always 00 for all opcodes
wire D_isLUI      = (D_instr[6:2] == 5'b01101);
wire D_isAUIPC    = (D_instr[6:2] == 5'b00101);
wire D_isJAL      = (D_instr[6:2] == 5'b11011);
wire D_isJALR     = (D_instr[6:2] == 5'b11001);
wire D_isBranch   = (D_instr[6:2] == 5'b11000);
wire D_isLoad     = (D_instr[6:3] == 4'b0000);  // instr[2]: FLW
wire D_isStore    = (D_instr[6:3] == 4'b0100);  // instr[2]: FSW
wire D_isALUI     = (D_instr[6:2] == 5'b00100);
wire D_isALUR     = (D_instr[6:2] == 5'b01100);
wire D_isFENCE    = (D_instr[6:2] == 5'b00011);
wire D_isSYS      = (D_instr[6:2] == 5'b11100);
wire D_isAMO      = (D_instr[6:2] == 5'b01011);
wire D_isFPU      = (D_instr[6:5] == 2'b10);

// Instruction Functions
wire [2:0] D_funct3 = D_instr[14:12];
wire [6:0] D_funct7 = D_instr[31:25];

// Source and dest registers
wire [4:0] D_raw_rdId  = D_instr[11:7];
wire [4:0] D_raw_rs1Id = D_instr[19:15];
wire [4:0] D_raw_rs2Id = D_instr[24:20];
wire [4:0] D_raw_rs3Id = D_instr[31:27]; // For FMA ops

// Immediate Values
wire [31:0] D_Iimm =
        {{21{D_instr[31]}}, D_instr[30:20]};
wire [31:0] D_Simm =
        {{21{D_instr[31]}}, D_instr[30:25],D_instr[11:7]};
wire [31:0] D_Bimm =
        {{20{D_instr[31]}}, D_instr[7],D_instr[30:25],D_instr[11:8],1'b0};
wire [31:0] D_Uimm =
        {D_instr[31], D_instr[30:12], {12{1'b0}}};
wire [31:0] D_Jimm =
        {{12{D_instr[31]}}, D_instr[19:12],D_instr[20],D_instr[30:21],1'b0};

// Privileged Instructions
wire D_isPrv    = D_isSYS & (D_funct3 == 3'b000);
wire D_isECALL  = D_isPrv & (D_instr[22:20] == 3'b000) & ~D_instr[25];
wire D_isEBREAK = D_isPrv & (D_instr[22:20] == 3'b001) & ~D_instr[25];
wire D_isMRET   = D_isPrv &  D_instr[21] & (D_instr[30:28] == 3'b011) & ~D_instr[25];
wire D_isSRET   = D_isPrv &  D_instr[21] & (D_instr[30:28] == 3'b001) & ~D_instr[25];
wire D_isWFI    = D_isPrv & (D_instr[22:20] == 3'b101) & ~D_instr[25];

wire D_isCSR = D_isSYS & (D_funct3[1:0] != 2'b00);
wire [11:0] D_csrId = D_instr[31:20];

wire D_isLR  = D_isAMO & (D_funct7[6:2] == 5'b00010);

wire D_isLoadOrAMO  = D_isLoad  | D_isAMO;
wire D_isStoreOrAMO = D_isStore | (D_isAMO & ~D_isLR);

wire D_readsRs1 = !(D_isJAL || D_isLUI || D_isAUIPC);

wire D_readsRs2 = (D_isStoreOrAMO || D_isBranch || D_isALUR || D_isFPU);

wire D_isRV32M = D_isALUR  & D_instr[25];
wire D_isMUL   = D_isRV32M & !D_instr[14];
wire D_isDIV   = D_isRV32M &  D_instr[14];

// rd is a FP reg if op is FLW, FMA, R-Type FPU, FCVT.S.W(U), or FMV.W.X
wire D_rdIsFP = (D_instr[6:2] == 5'b00001)  || // FLW
        (D_instr[6:4] == 3'b100)            || // FMA F(N)MADD / F(N)MSUB
        (D_isFPU && ((D_instr[31] == 1'b0)  || // R-Type FPU Instr
        (D_instr[31:28] == 4'b1101)         || // FCVT.S.W(U)
        (D_instr[31:28] == 4'b1111)));         // FMV.W.X

// rs1 is a FP reg if op is FPU except for FCVT.S.W(U) and FMV.W.X
wire D_rs1IsFP = D_isFPU &&
        !((D_instr[4:2]   == 3'b100) && (
          (D_instr[31:28] == 4'b1101) ||     // FCVT.S.W(U)
          (D_instr[31:28] == 4'b1111)));      // FMV.W.X

// rs2 is a FP reg if op is FPU or FSW
wire D_rs2IsFP = D_isFPU || (D_isStore && D_instr[2]);

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

localparam BH_SHAMT = BP_ADDR_BITS - BH_BITS;
wire [BP_ADDR_BITS-1:0] D_bhtIndex = FD_PC_i[BP_ADDR_BITS:1] ^ {branchHist, {BH_SHAMT{1'b0}}};

wire D_predictBranch = BHT[D_bhtIndex][1];

/*--------------RETURN ADDRESS STACK--------------*/
reg [31:0] RAS_0;
reg [31:0] RAS_1;
reg [31:0] RAS_2;
reg [31:0] RAS_3;

always @(posedge clk_i) begin
        if (!D_stall_i && !FD_nop_i && !D_flush_i) begin
                if ((D_isJAL || D_isJALR) && D_rdId == 1) begin
                        RAS_3 <= RAS_2;
                        RAS_2 <= RAS_1;
                        RAS_1 <= RAS_0;
                        RAS_0 <= FD_PC_i + (FD_isRV32C_i ? 2 : 4);
                end
                if(D_isJALR && D_rdId==0 && (D_rs1Id==1 || D_rs1Id==5)) begin
                        RAS_0 <= RAS_1;
                        RAS_1 <= RAS_2;
                        RAS_2 <= RAS_3;
                end
        end
end

/*------------------Trap Handlers-----------------*/
localparam US = 2'b00, SU = 2'b01, MA = 2'b11;

wire D_isTrap = D_isECALL;

wire [31:0] D_MRetJumpAddr = csrMepc_i;
wire [31:0] D_SRetJumpAddr = csrSepc_i;
reg  [31:0] D_ECallJumpAddr;
reg  [31:0] D_trapJumpAddr;

// Set PC, CSRs, and privilege level for traps
wire [1:0] D_trapPrivilege =
        (privilege_i == US)? (csrMedeleg_i[8] ? SU : MA) :
        (privilege_i == SU)? (csrMedeleg_i[9] ? SU : MA) : MA;

reg [1:0] D_privilegeSet;
always @(*) begin
        if (D_isTrap) begin
                if (D_trapPrivilege == SU) begin
                        D_trapJumpAddr = csrStvec_i;    // Set jump address to S-Trap
                        D_privilegeSet = SU;          // Set privilege to Supervisor
                end else begin // M-Trap
                        D_trapJumpAddr = csrMtvec_i;    // Set jump address to M-Trap
                        D_privilegeSet = MA;          // Set privilege to Machine
                end
        end else if (D_isMRET) begin
                D_trapJumpAddr = csrMepc_i;             // Set jump address to MEPC
                D_privilegeSet = csrMStatus_i[12:11]; // Set privilege to previous
        end else begin // SRET
                D_trapJumpAddr = csrSepc_i;             // Set jump address to SEPC
                D_privilegeSet = {1'b0, csrMStatus_i[8]}; // Set privilege to previous
        end
end
assign privilegeSet_o = D_privilegeSet;
assign privilegeSetEn_o   = D_isTrap || D_isSRET || D_isMRET;

always @(posedge clk_i) begin
end

/*------------Branch Prediction Result------------*/
assign D_predictPC_o = !FD_nop_i &&
        (D_isJAL || D_isJALR || D_isECALL || D_isMRET || D_isSRET ||
        (D_isBranch && D_predictBranch));

assign D_PCprediction_o =
        D_isJALR  ? RAS_0           :
        D_isECALL ? D_ECallJumpAddr :
        D_isMRET  ? D_MRetJumpAddr  :
        D_isSRET  ? D_SRetJumpAddr  :
        (FD_PC_i + (D_isJAL ? D_Jimm : D_Bimm));


/*------------------------------------------------*/
wire D_isNOP = E_flush_i | FD_nop_i | D_isWFI;
always @(posedge clk_i) begin
        if (!D_stall_i) begin
                DE_PC_o <= FD_PC_i;
                DE_instr_o <= D_isNOP ? NOP : D_instr;
                DE_isRV32C_o <= FD_isRV32C_i;
                DE_nop_o <= D_isNOP;

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
                DE_funct3_is_o <= 8'b00000001 << D_instr[14:12];
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

