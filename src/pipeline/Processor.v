/*************************************************
 *File----------Processor.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:17 UTC
 ************************************************/
/* verilator lint_off WIDTH */
// `define CONFIG_DEBUG

module Processor(
        input  wire clk_i,
        input  wire reset_i,
        output wire [31:0] IO_memAddr_o,
        input  wire [31:0] IO_memRData_i,
        output wire [31:0] IO_memWData_o,
        output wire        IO_memWr_o
);

`include "../Extern/riscv_disassembly.v"

/*
 * Used RISC-V ISM Volume I: Version 20250508, Ch. 35, Page 609
 * The 11 RISC-V opcodes
 * ----------------------------------
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
 --------------------------------REGISTER FILE---------------------------------
 ******************************************************************************/

reg [31:0] RegisterFile [0:31];

// Writeback Signals
wire        wbEnable;
wire [31:0] wbData;
wire [4:0]  wbRdId;

// Control and Status Registers
reg [63:0] cycle;       // 0xC00 - 0xC80 ([31:0] - [63:32])
reg [63:0] instret;     // 0xC02 - 0xC82 ([31:0] - [63:32]) 

localparam CYCLE_ID     = 12'hC00;
localparam CYCLEH_ID    = 12'hC80;
localparam INSTRET_ID   = 12'hC02;
localparam INSTRETH_ID  = 12'hC82;

always @(posedge clk_i) begin
        cycle <= cycle + 1;
end

/******************************************************************************
 -------------------------------CONTROL SIGNALS--------------------------------
 ******************************************************************************/

wire HALT;

localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;

wire D_flush;
wire E_flush;

wire F_stall;
wire D_stall;

wire rs1Hazard = D_readsRs1 && (D_rs1Id == DE_rdId);
wire rs2Hazard = D_readsRs2 && (D_rs2Id == DE_rdId);

wire dataHazard = !FD_nop &&
        ((DE_isLoad || DE_isCSR) && (rs1Hazard || rs2Hazard)) ||
        (D_isLoad && DE_isStore);

assign F_stall = dataHazard | HALT;
assign D_stall = dataHazard | HALT;

assign D_flush = E_correctPC;
assign E_flush = E_correctPC | dataHazard;

/******************************************************************************
 ----------------------------------FETCH UNIT----------------------------------
 ******************************************************************************/

reg [31:0] PC;

wire [31:0] F_PC =
        D_predictPC  ? D_PCprediction  :
        EM_correctPC ? EM_PCcorrection :
                             PC;

reg [31:0] PROGROM [0:16383];
initial begin $readmemh("../bin/ROM.hex",PROGROM); end

always @(posedge clk_i) begin
        if (!F_stall) begin
                FD_instr <= PROGROM[F_PC[15:2]];
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
                if (D_isJAL && D_rdId == 1) begin
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
                DE_wbEnable <= 1'b0;
        end

        if (wbEnable) 
                RegisterFile[wbRdId] <= wbData;
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

reg DE_wbEnable; // !isBranch && !isStore && rdId != 0

reg         DE_predictBranch;
reg [BP_ADDR_BITS-1:0] DE_bhtIndex;
reg [31:0] DE_predictRA;

/******************************************************************************
 ---------------------------------EXECUTE UNIT--------------------------------*
 ******************************************************************************/

/*---------------REGISTER FORWARDING--------------*/
// Forward from End of Execute Unit
wire EMfwd_rs1 = EM_wbEnable && (EM_rdId == DE_rs1Id);
wire EMfwd_rs2 = EM_wbEnable && (EM_rdId == DE_rs2Id);

// Forward from End of Memory Unit
wire EWfwd_rs1 = MW_wbEnable && (MW_rdId == DE_rs1Id);
wire EWfwd_rs2 = MW_wbEnable && (MW_rdId == DE_rs2Id);

wire [31:0] E_rs1 = EMfwd_rs1 ? EM_Eresult :
        EWfwd_rs1 ? wbData : RegisterFile[DE_rs1Id];

wire [31:0] E_rs2 = EMfwd_rs2 ? EM_Eresult :
        EWfwd_rs2 ? wbData : RegisterFile[DE_rs2Id];

/*----------------------ALU-----------------------*/
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
wire E_arithShift = DE_instr[30];
wire [31:0] E_shifterIn = 
        (DE_funct3 == 3'b001) ? flip32(E_aluIn1) : E_aluIn1;
wire [31:0] E_shifter =
        $signed({E_arithShift & E_aluIn1[31], E_shifterIn}) >>> E_aluIn2[4:0];
wire [31:0] E_leftShift = flip32(E_shifter);

wire [31:0] E_aluOut = 
        (DE_funct3_is[0] ? (E_isMinus ? E_aluMinus[31:0] : E_aluPlus) : 32'b0) |
        (DE_funct3_is[1] ? E_leftShift                                : 32'b0) |
        (DE_funct3_is[2] ? {31'b0, E_LT}                              : 32'b0) |
        (DE_funct3_is[3] ? {31'b0, E_LTU}                             : 32'b0) |
        (DE_funct3_is[4] ? E_aluIn1 ^ E_aluIn2                        : 32'b0) |
        (DE_funct3_is[5] ? E_shifter                                  : 32'b0) |
        (DE_funct3_is[6] ? E_aluIn1 | E_aluIn2                        : 32'b0) |
        (DE_funct3_is[7] ? E_aluIn1 & E_aluIn2                        : 32'b0) ;

/*------------------JUMP/BRANCH-------------------*/
wire E_takeBranch = 
        (DE_funct3_is[0] &  E_EQ ) | // BEQ
        (DE_funct3_is[1] & !E_EQ ) | // BNE
        (DE_funct3_is[4] &  E_LT ) | // BLT
        (DE_funct3_is[5] & !E_LT ) | // BGE
        (DE_funct3_is[6] &  E_LTU) | // BLTU
        (DE_funct3_is[7] & !E_LTU) ; // BGEU

always @(posedge clk_i) begin
        if (DE_isBranch) begin
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
        /* JALR */           {E_aluPlus[31:1], 1'b0};

wire [31:0] E_result = 
        (DE_isJAL | DE_isJALR) ? DE_PC + 4              :
        DE_isLUI                      ? DE_Uimm         :
        DE_isAUIPC                    ? DE_PC + DE_Uimm :
        /* ALU OP */                           E_aluOut ;

/*------------------------------------------------*/
// Memory access address
wire [31:0] E_addr =
        DE_isStore ? E_rs1 + DE_Simm : E_rs1 + DE_Iimm;

always @(posedge clk_i) begin
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
        EM_Mdata <= DATARAM[E_addr[31:2]];
        EM_correctPC <= E_correctPC;
        EM_PCcorrection <= E_PCcorrection;
        EM_wbEnable <= DE_wbEnable && (DE_rdId != 0);
end

assign HALT = !reset_i & DE_isEBREAK;

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

wire [3:0] M_wmask = 
        {4{EM_isStore & M_isRAM}} & M_storeMask;

reg [31:0] DATARAM [0:16383];

initial begin
        $readmemh("../bin/RAM.hex",DATARAM);
end

wire [29:0] M_wordAddr = EM_addr[31:2];
always @(posedge clk_i) begin
        if (M_wmask[0]) DATARAM[M_wordAddr][ 7:0 ] <= M_storeData[ 7:0 ];
        if (M_wmask[1]) DATARAM[M_wordAddr][15:8 ] <= M_storeData[15:8 ];
        if (M_wmask[2]) DATARAM[M_wordAddr][23:16] <= M_storeData[23:16];
        if (M_wmask[3]) DATARAM[M_wordAddr][31:24] <= M_storeData[31:24];
end

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

/*-----------------------CSR----------------------*/
reg [31:0] M_csrData;
always @(*) begin
        case (EM_csrId)
                CYCLE_ID:    M_csrData = cycle[31:0];
                CYCLEH_ID:   M_csrData = cycle[63:32];
                INSTRET_ID:  M_csrData = instret[31:0];
                INSTRETH_ID: M_csrData = instret[63:32];
                default:     M_csrData = 32'h00000000;
        endcase
end

/*------------------------------------------------*/
wire [31:0] M_wbData =
        EM_isLoad ? (M_isIO ? IO_memRData_i : M_Mdata) :
        EM_isCSR  ? M_csrData : EM_Eresult;

always @(posedge clk_i) begin
        MW_PC <= EM_PC;
        MW_instr <= EM_instr;
        MW_nop <= EM_nop;

        MW_rdId <= EM_rdId;
        MW_wbData <= M_wbData;
        MW_wbEnable <= EM_wbEnable;

        if (reset_i)
                instret <= 0;
        else if (!MW_nop)
                instret <= instret + 1;
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

assign wbData = MW_wbData;

assign wbEnable = MW_wbEnable;

assign wbRdId = MW_rdId;

/*----------------------------------------------------------------------------*/
`ifdef BENCH
        integer nbBranch = 0;
        integer nbPredictHit = 0;
        integer nbJAL  = 0;
        integer nbJALR = 0;
        always @(posedge clk_i) begin
                if(!reset_i) begin
                        if(DE_isBranch) begin
                                nbBranch <= nbBranch + 1;
                                if(E_takeBranch == DE_predictBranch) begin
                                        nbPredictHit <= nbPredictHit + 1;
                                end
                        end
                        if(DE_isJAL) begin
                                nbJAL <= nbJAL + 1;
                        end
                        if(DE_isJALR) begin
                                nbJALR <= nbJALR + 1;
                        end
                end
        end
        always @(posedge clk_i) begin
                if(HALT) begin
                        $display("\n\nSimulated processor's report");
                        $display("----------------------------");
                        $display("Branch hits= %3.3f\%%",
                                nbPredictHit*100.0/nbBranch	 );
                        $display("CPI        = %3.3f",(cycle*1.0)/(instret*1.0));
                        $display("Instr. mix = (Branch:%3.3f\%% JAL:%3.3f\%% JALR:%3.3f\%%)",
                                nbBranch*100.0/instret,
                                nbJAL*100.0/instret,
                                nbJALR*100.0/instret);
                        $finish();
                end
        end
`endif

`ifdef BENCH
`ifdef CONFIG_DEBUG

        always @(posedge clk_i) begin
                if(!reset_i & !HALT) begin

                        $write("     ");
                        $write("[W] PC=%h ", MW_PC);
                        $write("     ");
                        riscv_disasm(MW_instr,MW_PC);
                        if(wbEnable) $write(
                                "    x%0d <- 0x%0h (%0d)",
                                riscv_disasm_rdId(MW_instr),wbData,wbData
                        );
                        $write("\n");

                        $write("(  ) ");
                        $write("[M] PC=%h ", EM_PC);
                        $write("     ");
                        riscv_disasm(EM_instr,EM_PC);
                        $write("\n");

                        $write("( %c) ", E_flush ? "f":" ");
                        $write("[E] PC=%h ", DE_PC);

                        // Register forwarding
                        if(DE_nop) $write("[  ] ");
                        else $write("[%s%s] ",
                                riscv_disasm_readsRs1(DE_instr) ?
                                (EMfwd_rs1 ? "M" : EWfwd_rs1 ? "W" : " ") : " ",
                                riscv_disasm_readsRs2(DE_instr) ?
                                (EMfwd_rs2 ? "M" : EWfwd_rs2 ? "W" : " ") : " "
                        );
                        riscv_disasm(DE_instr,DE_PC);
                        if(DE_instr != NOP) begin
                                $write("  rs1=0x%h (%0d) rs2=0x%h (%0d) ",E_rs1,E_rs1,E_rs2,E_rs2);
                                `ifdef CONFIG_PC_PREDICT
                                        if(riscv_disasm_isBranch(DE_instr)) begin
                                                $write(" taken:%0d  %s",
                                                        E_takeBranch,
                                                        (E_takeBranch == DE_predictBranch) ?
                                                        "predict hit" : "predict miss"
                                                );
                                        end
                                `endif
                        end
                        $write("\n");

                        $write("(%c%c) ",D_stall ? "s":" ",D_flush ? "f":" ");
                        $write("[D] PC=%h ", FD_PC);
                        $write("[%s%s] ",
                                dataHazard && rs1Hazard?"*":" ",
                                dataHazard && rs2Hazard?"*":" ");
                        riscv_disasm(FD_nop ? NOP : FD_instr,FD_PC);
                        `ifdef CONFIG_PC_PREDICT
                                if(riscv_disasm_isBranch(FD_instr)) begin
                                        $write(" predict taken:%0d",D_predictBranch);
                                end
                        `endif
                        $write("\n");

                        $write("(%c ) ",F_stall ? "s":" ");
                        $write("[F] PC=%h ", F_PC);
                        `ifdef CONFIG_PC_PREDICT
                                if(D_predictPC) begin
                                        $write(" PC <- [D] 0x%0h (prediction)",D_PCprediction);
                                end
                        `endif
                        if(EM_correctPC) begin
                                $write(" PC <- [E] 0x%0h (correction)",EM_PCcorrection);
                        end
                        $write("\n");

                        $display("");
                end
        end

        /* "debugger" */

        // wire breakpoint = 1'b0; // no breakpoint
        // wire breakpoint = (EM_addr == 32'h400004); // break on LEDs output
        wire breakpoint = (EM_addr == 32'h400008); // break on character output
        // wire breakpoint = (DE_PC   == 32'h000000); // break on address reached

        reg step = 1'b1;
        reg [31:0] dbg_cmd = 0;

        initial begin
                $display("");
                $display("\"Debugger\" commands:");
                $display("--------------------");
                $display("g       : go");
                $display("<return>: step");
                $display("see \"debugger\" section in source for breakpoints");
                $display("");
end

always @(posedge clk_i) begin
        if(!reset_i & !HALT) begin
                if(step) begin
                        $write("DBG>");
                        dbg_cmd <= $c32("getchar()");
                        $write("\n");
                end
                if(dbg_cmd == "g") begin
                        step <= 1'b0;
                end
                if(breakpoint) begin
                        step <= 1'b1;
                end
        end
end

`endif // `CONFIG_DEBUG
`endif

endmodule
/* verilator lint_on WIDTH */

