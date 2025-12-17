/*************************************************
 *File----------Processor.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:17 UTC
 ************************************************/
/* verilator lint_off WIDTH */

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

/******************************************************************************
 -------------------------------CONTROL SIGNALS--------------------------------
 ******************************************************************************/

wire HALT;

localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;

wire F_stall;
wire D_stall;
wire E_stall;

wire D_flush;
wire E_flush;
wire M_flush;

wire rs1Hazard = D_readsRs1 && (D_rs1Id == DE_rdId);
wire rs2Hazard = D_readsRs2 && (D_rs2Id == DE_rdId);

wire dataHazard = !FD_nop &&
        ((DE_isLoad || DE_isCSR) && (rs1Hazard || rs2Hazard)) ||
        (D_isLoad && DE_isStore);

assign F_stall = aluBusy | dataHazard | HALT;
assign D_stall = aluBusy | dataHazard | HALT;
assign E_stall = aluBusy;

assign D_flush = E_correctPC;
assign E_flush = E_correctPC | dataHazard;
assign M_flush = aluBusy;

/******************************************************************************
 ----------------------------------FETCH UNIT----------------------------------
 ******************************************************************************/
/* Inputs:                      Outputs:
 *      clk_i                           IMemAddr
 *      reset_i                         FD_PC
 *      IMemData                    FD_instr
 *      F_stall                         FD_nop
 *      D_flush
 *      D_predictPC
 *      D_PCprediction
 *      EM_correctPC
 *      EM_PCcorrection
 */

reg [31:0] PC;

wire [31:0] F_PC =
        D_predictPC  ? D_PCprediction  :
        EM_correctPC ? EM_PCcorrection :
                             PC;

assign IMemAddr_o = F_PC;

always @(posedge clk_i) begin
        if (!F_stall) begin
                FD_instr <= IMemData_i;
                FD_PC <= F_PC;
                PC <= F_PC + 4;
        end

        FD_nop <= D_flush | reset_i;

        if (reset_i) begin
                PC <= 0;
        end

end

/*----------------------------------------------------------------------------*/
reg [31:0] FD_PC;
reg [31:0] FD_instr;
reg        FD_nop;
/******************************************************************************
 ---------------------------------DECODE UNIT----------------------------------
 ******************************************************************************/
/* Inputs:                      Outputs:
 *      clk_i                           D_predictPC
 *      reset_i                         D_PCprediction
 *      D_stall
 *      D_flush
 *      E_flush
 */

/*--------------INSTRUCTION DECODING--------------*/
// 11 RISC-V OpCodes
// bits [1:0] are always 00 for all opcodes
wire D_isLUI      = (FD_instr[6:2] == 5'b01101);
wire D_isAUIPC    = (FD_instr[6:2] == 5'b00101);
wire D_isJAL      = (FD_instr[6:2] == 5'b11011);
wire D_isJALR     = (FD_instr[6:2] == 5'b11001);
wire D_isBranch   = (FD_instr[6:2] == 5'b11000);
wire D_isLoad     = (FD_instr[6:2] == 5'b00000);
wire D_isStore    = (FD_instr[6:2] == 5'b01000);
wire D_isALUI     = (FD_instr[6:2] == 5'b00100);
wire D_isALUR     = (FD_instr[6:2] == 5'b01100);
wire D_isFENCE    = (FD_instr[6:2] == 5'b00011);
wire D_isSYS      = (FD_instr[6:2] == 5'b11100);

// Instruction Functions
wire [2:0] D_funct3 = FD_instr[14:12];
wire [6:0] D_funct7 = FD_instr[31:25];

// Source and dest registers
wire [4:0] D_rdId  = FD_instr[11:7];
wire [4:0] D_rs1Id = FD_instr[19:15];
wire [4:0] D_rs2Id = FD_instr[24:20];

// Immediate Values
wire [31:0] D_Iimm =
        {{21{FD_instr[31]}}, FD_instr[30:20]};
wire [31:0] D_Simm =
        {{21{FD_instr[31]}}, FD_instr[30:25],FD_instr[11:7]};
wire [31:0] D_Bimm =
        {{20{FD_instr[31]}}, FD_instr[7],FD_instr[30:25],FD_instr[11:8],1'b0};
wire [31:0] D_Uimm =
        {FD_instr[31], FD_instr[30:12], {12{1'b0}}};
wire [31:0] D_Jimm =
        {{12{FD_instr[31]}}, FD_instr[19:12],FD_instr[20],FD_instr[30:21],1'b0};

wire D_isEBREAK = D_isSYS & (D_funct3 == 3'b000) & FD_instr[20] & ~FD_instr[22];

wire D_isCSR = D_isSYS & ((D_funct3 != 3'b000) & (D_funct3 != 3'b100));
wire [11:0] D_csrId = FD_instr[31:20];

wire D_isRV32M = D_isALUR  & FD_instr[25];
wire D_isMUL   = D_isRV32M & !FD_instr[14];
wire D_isDIV   = D_isRV32M &  FD_instr[14];

wire D_readsRs1 = !(D_isJAL || D_isLUI || D_isAUIPC);

wire D_readsRs2 = (FD_instr[5] && (FD_instr[3:2] == 2'b00));

/*----------------BRANCH PREDICTION---------------*/
localparam BP_ADDR_BITS = 12;
localparam BHT_SIZE = 1 << BP_ADDR_BITS;
reg [1:0] BHT[BHT_SIZE-1:0]; // Branch History Table

localparam BH_BITS = 9;
reg [BH_BITS-1:0] branchHist;

wire [BP_ADDR_BITS-1:0] D_bhtIndex =
        FD_PC[BP_ADDR_BITS+1:2] ^ (branchHist << (BP_ADDR_BITS - BH_BITS));

wire D_predictBranch = BHT[D_bhtIndex][1];

/*--------------RETURN ADDRESS STACK--------------*/
reg [31:0] RAS_0;
reg [31:0] RAS_1;
reg [31:0] RAS_2;
reg [31:0] RAS_3;

wire D_predictPC = !FD_nop &&
        (D_isJAL || D_isJALR || (D_isBranch && D_predictBranch));

wire [31:0] D_PCprediction = D_isJALR ? RAS_0 :
        (FD_PC + (D_isJAL ? D_Jimm : D_Bimm));

always @(posedge clk_i) begin
        if (!D_stall && !FD_nop && !D_flush) begin
                if ((D_isJAL || D_isJALR) && D_rdId == 1) begin
                        RAS_3 <= RAS_2;
                        RAS_2 <= RAS_1;
                        RAS_1 <= RAS_0;
                        RAS_0 <= FD_PC + 4;
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
        if (!D_stall) begin
                DE_PC <= FD_PC;
                DE_instr <= (E_flush | FD_nop) ? NOP : FD_instr;
                DE_nop <= 1'b0;

                DE_isLUI    <= D_isLUI;
                DE_isAUIPC  <= D_isAUIPC;
                DE_isJAL    <= D_isJAL;
                DE_isJALR   <= D_isJALR;
                DE_isBranch <= D_isBranch;
                DE_isLoad   <= D_isLoad;
                DE_isStore  <= D_isStore;
                DE_isALUI   <= D_isALUI;
                DE_isALUR   <= D_isALUR;
                DE_isFENCE  <= D_isFENCE;
                DE_isSYS    <= D_isSYS;
                DE_isEBREAK <= D_isEBREAK;
                DE_isCSR    <= D_isCSR;

                DE_rdId <= D_rdId;
                DE_rs1Id <= D_rs1Id;
                DE_rs2Id <= D_rs2Id;
                DE_csrId <= D_csrId;

                DE_funct3 <= D_funct3;
                DE_funct3_is <= 8'b00000001 << FD_instr[14:12];
                DE_funct7 <= D_funct7;

                DE_Iimm <= D_Iimm;
                DE_Simm <= D_Simm;
                DE_Bimm <= D_Bimm;
                DE_Uimm <= D_Uimm;

                DE_isRV32M <= D_isRV32M;
                DE_isMUL   <= D_isMUL;
                DE_isDIV   <= D_isDIV;

                DE_wbEnable <= ~(D_isBranch | D_isStore);

                DE_predictBranch <= D_predictBranch;
                DE_bhtIndex <= D_bhtIndex;
                DE_predictRA <= RAS_0;
        end

        if (E_flush || FD_nop) begin
                DE_instr    <= NOP;
                DE_nop      <= 1'b1;
                DE_isLUI    <= 1'b0;
                DE_isAUIPC  <= 1'b0;
                DE_isJAL    <= 1'b0;
                DE_isJALR   <= 1'b0;
                DE_isBranch <= 1'b0;
                DE_isLoad   <= 1'b0;
                DE_isStore  <= 1'b0;
                DE_isALUI   <= 1'b0;
                DE_isALUR   <= 1'b0;
                DE_isFENCE  <= 1'b0;
                DE_isSYS    <= 1'b0;
                DE_isEBREAK <= 1'b0;
                DE_isCSR    <= 1'b0;
                DE_isRV32M  <= 1'b0;
                DE_isMUL    <= 1'b0;
                DE_isDIV    <= 1'b0;
                DE_wbEnable <= 1'b0;
        end
end

/*----------------------------------------------------------------------------*/
reg  [31:0] DE_PC;
reg  [31:0] DE_instr;
reg         DE_nop;

reg DE_isLUI;
reg DE_isAUIPC;
reg DE_isJAL;
reg DE_isJALR;
reg DE_isBranch;
reg DE_isLoad;
reg DE_isStore;
reg DE_isALUI;
reg DE_isALUR;
reg DE_isFENCE;
reg DE_isSYS;
reg DE_isEBREAK;
reg DE_isCSR;

reg [4:0]  DE_rdId;
reg [4:0]  DE_rs1Id;
reg [4:0]  DE_rs2Id;
reg [11:0] DE_csrId;

reg [2:0]  DE_funct3;
(* onehot *) reg [7:0] DE_funct3_is;
reg [6:0]  DE_funct7;

reg [31:0] DE_Iimm;
reg [31:0] DE_Simm;
reg [31:0] DE_Bimm;
reg [31:0] DE_Uimm;

reg DE_isRV32M;
reg DE_isMUL;
reg DE_isDIV;

reg DE_wbEnable; // !isBranch && !isStore && rdId != 0

reg         DE_predictBranch;
reg [BP_ADDR_BITS-1:0] DE_bhtIndex;
reg [31:0] DE_predictRA;

/******************************************************************************
 ---------------------------------EXECUTE UNIT--------------------------------*
 ******************************************************************************/
/* Inputs:                      Outputs:
 *      clk_i                           rs1Id
 *      reset_i                         rs2Id
 *      MW_wbEnable                     aluBusy
 *      MW_rdId
 *      wbData
 *      rs1Data
 *      rs2Data
 */

/*---------------REGISTER FORWARDING--------------*/
// Forward from End of Execute Unit
wire EMfwd_rs1 = EM_wbEnable && (EM_rdId == DE_rs1Id);
wire EMfwd_rs2 = EM_wbEnable && (EM_rdId == DE_rs2Id);

// Forward from End of Memory Unit
wire EWfwd_rs1 = MW_wbEnable && (MW_rdId == DE_rs1Id);
wire EWfwd_rs2 = MW_wbEnable && (MW_rdId == DE_rs2Id);

assign rs1Id_o = DE_rs1Id;
assign rs2Id_o = DE_rs2Id;
wire [31:0] E_wbData;

wire [31:0] E_rs1 = EMfwd_rs1 ? EM_Eresult :
        EWfwd_rs1 ? E_wbData : rs1Data_i;

wire [31:0] E_rs2 = EMfwd_rs2 ? EM_Eresult :
        EWfwd_rs2 ? E_wbData : rs2Data_i;

/*---------------ADD/SUBTRACT/SHIFT---------------*/
wire [31:0] E_aluIn1 = E_rs1;
wire [31:0] E_aluIn2 =
        DE_isALUR | DE_isBranch ? E_rs2 : DE_Iimm;

// Add Subtract
wire E_isMinus = DE_funct7[5] & DE_isALUR;
wire [31:0] E_aluPlus = E_aluIn1 + E_aluIn2;
wire [32:0] E_aluMinus = {1'b0, E_aluIn1} + {1'b1, ~E_aluIn2} + 33'b1;

// Comparisons
wire E_LT  = (E_aluIn1[31] ^ E_aluIn2[31]) ? E_aluIn1[31] : E_aluMinus[32];
wire E_LTU = E_aluMinus[32];
wire E_EQ  = (E_aluMinus[31:0] == 0);

// Flip a 32 bit word. Used by the shifter
function [31:0] flip32;
        input [31:0] x;
        flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7],
                x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15],
                x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
                x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
endfunction

// Bit Shifts
wire E_arithShift = DE_funct7[5];
wire [31:0] E_shifterIn = 
        (DE_funct3 == 3'b001) ? flip32(E_aluIn1) : E_aluIn1;
wire [31:0] E_shifter =
        $signed({E_arithShift & E_aluIn1[31], E_shifterIn}) >>> E_aluIn2[4:0];
wire [31:0] E_leftShift = flip32(E_shifter);

wire [31:0] E_aluOutBase = 
        (DE_funct3_is[0] ? (E_isMinus ? E_aluMinus[31:0] : E_aluPlus) : 32'b0) |
        (DE_funct3_is[1] ? E_leftShift                                : 32'b0) |
        (DE_funct3_is[2] ? {31'b0, E_LT}                              : 32'b0) |
        (DE_funct3_is[3] ? {31'b0, E_LTU}                             : 32'b0) |
        (DE_funct3_is[4] ? E_aluIn1 ^ E_aluIn2                        : 32'b0) |
        (DE_funct3_is[5] ? E_shifter                                  : 32'b0) |
        (DE_funct3_is[6] ? E_aluIn1 | E_aluIn2                        : 32'b0) |
        (DE_funct3_is[7] ? E_aluIn1 & E_aluIn2                        : 32'b0) ;

/*--------------------MULTIPLY--------------------*/
wire E_isMULH   = DE_funct3_is[1];
wire E_isMULHSU = DE_funct3_is[2];

wire E_mulSign1 = E_rs1[31] & E_isMULH;
wire E_mulSign2 = E_rs2[31] & (E_isMULH | E_isMULHSU);

wire signed [32:0] E_mulSigned1 = {E_mulSign1, E_rs1};
wire signed [32:0] E_mulSigned2 = {E_mulSign2, E_rs2};
wire signed [63:0] E_multiply   = E_mulSigned1 * E_mulSigned2;

/*---------------------DIVIDE---------------------*/
reg [31:0] EE_dividend;
reg [62:0] EE_divisor;
reg [31:0] EE_quotient;
reg [31:0] EE_quotientMsk;

reg EE_divSign;
reg EE_divBusy     = 1'b0;
reg EE_divFinished = 1'b0;

wire E_divstepDo = (EE_divisor <= {31'b0, EE_dividend});

always @(posedge clk_i) begin
        if (!EE_divBusy) begin
                if (DE_isDIV & !dataHazard & !EE_divFinished) begin
                        EE_quotientMsk <= 1 << 31;
                        EE_divBusy <= 1'b1;
                end
                EE_dividend <= ~DE_funct3[0] & E_rs1[31] ? -E_rs1 : E_rs1;
                EE_divisor <=
                        {(~DE_funct3[0] & E_rs2[31] ? -E_rs2 : E_rs2), 31'b0};
                EE_quotient <= 0;
                EE_divSign <= ~DE_funct3[0] & (DE_funct3[1] ? E_rs1[31] :
                        (E_rs1[31] != E_rs2[31]) & |E_rs2);
        end else begin
                EE_dividend <= E_divstepDo ? EE_dividend - EE_divisor[31:0] :
                                             EE_dividend;
                EE_divisor <= EE_divisor >> 1;
                EE_quotient <= E_divstepDo ? EE_quotient | EE_quotientMsk :
                                             EE_quotient;
                EE_quotientMsk <=EE_quotientMsk >> 1;
                EE_divBusy <= EE_divBusy & !EE_quotientMsk[0];
        end
        EE_divFinished <= EE_quotientMsk[0];
end

wire [2:0] E_divsel = {DE_isDIV, DE_funct3[1], EE_divSign};

wire [31:0] E_aluOutM = 
        (  DE_funct3_is[0]    ?  E_multiply[31:0]  : 32'b0) | // MUL
        ( |DE_funct3_is[3:1]  ?  E_multiply[63:32] : 32'b0) | // MULH[[S]U]
        (  E_divsel == 3'b100 ?  EE_quotient       : 32'b0) | // DIV
        (  E_divsel == 3'b101 ? -EE_quotient       : 32'b0) | // DIV Negative
        (  E_divsel == 3'b110 ?  EE_dividend       : 32'b0) | // REM
        (  E_divsel == 3'b111 ? -EE_dividend       : 32'b0) ; // REM Negative

wire [31:0] E_aluOut = DE_isRV32M ? E_aluOutM : E_aluOutBase;

wire aluBusy = EE_divBusy | (DE_isDIV & !EE_divFinished);

/*------------------JUMP/BRANCH-------------------*/
wire E_takeBranch = 
        (DE_funct3_is[0] &  E_EQ ) | // BEQ
        (DE_funct3_is[1] & !E_EQ ) | // BNE
        (DE_funct3_is[4] &  E_LT ) | // BLT
        (DE_funct3_is[5] & !E_LT ) | // BGE
        (DE_funct3_is[6] &  E_LTU) | // BLTU
        (DE_funct3_is[7] & !E_LTU) ; // BGEU

always @(posedge clk_i) begin
        if (!E_stall && DE_isBranch) begin
                branchHist <= {E_takeBranch, branchHist[BH_BITS-1:1]};
                BHT[DE_bhtIndex] <= 
                        {E_takeBranch, BHT[DE_bhtIndex]} == 3'b000 ? 2'b00 :
                        {E_takeBranch, BHT[DE_bhtIndex]} == 3'b001 ? 2'b00 :
                        {E_takeBranch, BHT[DE_bhtIndex]} == 3'b010 ? 2'b01 :
                        {E_takeBranch, BHT[DE_bhtIndex]} == 3'b011 ? 2'b10 :		
                        {E_takeBranch, BHT[DE_bhtIndex]} == 3'b100 ? 2'b01 :
                        {E_takeBranch, BHT[DE_bhtIndex]} == 3'b101 ? 2'b10 :
                        {E_takeBranch, BHT[DE_bhtIndex]} == 3'b110 ? 2'b11 :
                        2'b11 ;
        end
end

wire [31:0] E_JALRaddr = {E_aluPlus[31:1],1'b0};

wire E_correctPC = (
        (DE_isJALR    && (DE_predictRA != E_JALRaddr)   ) ||
        (DE_isBranch  && (E_takeBranch^DE_predictBranch))
);

wire [31:0] E_PCcorrection = 
        DE_isBranch ? DE_PC + (DE_predictBranch ? 4 : DE_Bimm) :
        /* JALR */                                 E_JALRaddr;

wire [31:0] E_result = 
        (DE_isJAL | DE_isJALR) ? DE_PC + 4              :
        DE_isLUI                      ? DE_Uimm         :
        DE_isAUIPC                    ? DE_PC + DE_Uimm :
        /* ALU OP */                           E_aluOut ;

/*------------------------------------------------*/
// Memory access address
wire [31:0] E_addr =
        DE_isStore ? E_rs1 + DE_Simm : E_rs1 + DE_Iimm;
assign DMemRAddr_o = E_addr;

always @(posedge clk_i) begin
        if (!E_stall) begin
                EM_PC <= DE_PC;
                EM_instr <= DE_instr;
                EM_nop <= DE_nop;

                EM_isLoad <= DE_isLoad;
                EM_isStore <= DE_isStore;
                EM_isCSR <= DE_isCSR;
                EM_rdId <= DE_rdId;
                EM_rs1Id <= DE_rs1Id;
                EM_rs2Id <= DE_rs2Id;
                EM_csrId <= DE_csrId;
                EM_funct3 <= DE_funct3;
                EM_rs2 <= E_rs2;
                EM_Eresult <= E_result;
                EM_addr <= E_addr;
                EM_Mdata <= DMemRData_i;
                EM_correctPC <= E_correctPC;
                EM_PCcorrection <= E_PCcorrection;
                EM_wbEnable <= DE_wbEnable && (DE_rdId != 0);
        end

        if (M_flush) begin
                EM_instr     <= NOP;
                EM_nop       <= 1'b1;
                EM_isLoad    <= 1'b0;
                EM_isStore   <= 1'b0;
                EM_isCSR     <= 1'b0;
                EM_correctPC <= 1'b0;
                EM_wbEnable  <= 1'b0;
        end
end

assign HALT = (!reset_i && DE_isEBREAK);

/*----------------------------------------------------------------------------*/
reg [31:0] EM_PC;
reg [31:0] EM_instr;
reg        EM_nop;

reg        EM_isLoad;
reg        EM_isStore;
reg        EM_isCSR;
reg [4:0]  EM_rdId;
reg [4:0]  EM_rs1Id;
reg [4:0]  EM_rs2Id;
reg [11:0] EM_csrId;
reg [31:0] EM_rs2;
reg [2:0]  EM_funct3;

reg [31:0] EM_Eresult;
reg [31:0] EM_addr;
reg [31:0] EM_Mdata;
reg        EM_correctPC;
reg [31:0] EM_PCcorrection;
reg        EM_wbEnable;

/******************************************************************************
 ------------------------------MEMORY ACCESS UNIT-----------------------------*
 ******************************************************************************/

wire M_isB = (EM_funct3[1:0] == 2'b00);
wire M_isH = (EM_funct3[1:0] == 2'b01);

/*----------------------STORE---------------------*/
wire [31:0] M_storeData;
assign M_storeData [7:0]  = EM_rs2[7:0];
assign M_storeData[15:8]  = EM_addr[0] ? EM_rs2[7:0]  : EM_rs2[15:8];
assign M_storeData[23:16] = EM_addr[1] ? EM_rs2[7:0]  : EM_rs2[23:16];
assign M_storeData[31:24] = EM_addr[0] ? EM_rs2[7:0]  :
		            EM_addr[1] ? EM_rs2[15:8] : EM_rs2[31:24];

reg [3:0] M_storeMask;
always @(*) begin
        if (M_isB) begin
                if (EM_addr[1:0] == 2'b11)
                        M_storeMask = 4'b1000;
                else if (EM_addr[1:0] == 2'b10)
                        M_storeMask = 4'b0100;
                else if (EM_addr[1:0] == 2'b01)
                        M_storeMask = 4'b0010;
                else
                        M_storeMask = 4'b0001;
        end else if (M_isH) begin
                if (EM_addr[1])
                        M_storeMask = 4'b1100;
                else
                        M_storeMask = 4'b0011;
        end else begin
                M_storeMask = 4'b1111;
        end
end

wire M_isIO  = EM_addr[22];
wire M_isRAM = !M_isIO;

assign IO_memAddr_o  = EM_addr;
assign IO_memWr_o    = EM_isStore && M_isIO;
assign IO_memWData_o = EM_rs2;

assign DMemWAddr_o = EM_addr;
assign DMemWData_o = M_storeData;
assign DMemWMask_o = {4{EM_isStore & M_isRAM}} & M_storeMask;

/*----------------------LOAD----------------------*/
wire [15:0] M_memHalf = EM_addr[1] ? EM_Mdata[31:16] : EM_Mdata[15:0];
wire [7:0]  M_memByte = EM_addr[0] ? M_memHalf[15:8]  : M_memHalf[7:0];

// Sign expansion
// Based on funct3[2]: 0->sign expand, 1->unsigned
wire M_loadSign = !EM_funct3[2] & (M_isB ? M_memByte[7] : M_memHalf[15]);

reg [31:0] M_Mdata;
always @(*) begin
        if(M_isB)
                M_Mdata = {{24{M_loadSign}}, M_memByte};
        else if(M_isH)
                M_Mdata = {{16{M_loadSign}}, M_memHalf};
        else
                M_Mdata = EM_Mdata;
end


/*------------------------------------------------*/
assign csrRAddr_o = EM_csrId;
assign csrInstStep_o  = ~MW_nop;

wire [31:0] M_wbData =
        EM_isLoad ? (M_isIO ? IO_memRData_i : M_Mdata) :
        EM_isCSR  ? csrRData_i : EM_Eresult;

always @(posedge clk_i) begin
        MW_PC <= EM_PC;
        MW_instr <= EM_instr;
        MW_nop <= EM_nop;

        MW_rdId <= EM_rdId;
        MW_wbData <= M_wbData;
        MW_wbEnable <= EM_wbEnable;
end

/*----------------------------------------------------------------------------*/
reg [31:0] MW_PC;
reg [31:0] MW_instr;
reg        MW_nop;

reg [4:0]  MW_rdId;
reg [31:0] MW_wbData;
reg        MW_wbEnable;
/******************************************************************************
 -------------------------------WRITE BACK UNIT-------------------------------- 
 ******************************************************************************/

assign E_wbData = MW_wbData;
assign rdData_o = MW_wbData;

assign rdId_o = MW_wbEnable ? MW_rdId : 5'b0;

/*----------------------------------------------------------------------------*/
`ifdef BENCH
        `include "../Extern/riscv_disassembly.v"
        integer nbBranch = 0;
        integer nbBranchHit = 0;
        integer nbJAL  = 0;
        integer nbJALR = 0;
        integer nbJALRhit = 0;
        integer nbLoad = 0;
        integer nbStore = 0;
        integer nbLoadHazard = 0;
        integer nbRV32M = 0;
        integer nbMUL = 0;
        integer nbDIV = 0;

        always @(posedge clk_i) begin
                if(!reset_i & !D_stall) begin
                        if(riscv_disasm_isBranch(DE_instr)) begin
                                nbBranch <= nbBranch + 1;
                                if(E_takeBranch == DE_predictBranch) begin
                                        nbBranchHit <= nbBranchHit + 1;
                                end
                        end
                        if(riscv_disasm_isJAL(DE_instr)) begin
                                nbJAL <= nbJAL + 1;
                        end
                        if(riscv_disasm_isJALR(DE_instr)) begin
                                nbJALR <= nbJALR + 1;
                                if(DE_predictRA == E_JALRaddr) begin
                                        nbJALRhit <= nbJALRhit + 1;
                                end
                        end
                end

                if(riscv_disasm_isLoad(MW_instr)) begin
                        nbLoad <= nbLoad + 1;
                end
                if(riscv_disasm_isStore(MW_instr)) begin
                        nbStore <= nbStore + 1;
                end
                if(riscv_disasm_isRV32M(MW_instr)) begin
                        if(MW_instr[14]) begin
                                nbDIV <= nbDIV + 1;
                        end else begin
                                nbMUL <= nbMUL + 1;
                        end
                end
                if(dataHazard) begin
                        nbLoadHazard <= nbLoadHazard + 1;
                end
                if(HALT) $finish();
        end
`endif

endmodule
/* verilator lint_on WIDTH */

