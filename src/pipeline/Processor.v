/*************************************************
 *File----------Processor.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:17 UTC
 ************************************************/
// `define VERBOSE

module Processor(
        input  wire clk,
        input  wire reset,
        output wire [31:0] IO_memAddr,
        input  wire [31:0] IO_memRData,
        output wire [31:0] IO_memWData,
        output wire        IO_memWr
);

`include "../Extern/riscv_disassembly.v"

/*
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
 -------------------------------HELPER FUNCTIONS-------------------------------
 ******************************************************************************/

// Used RISC-V ISM Version 20250508, Ch. 35, Page 609
// 11 RISC-V OpCodes
function isLUI;    input [31:0] I; isLUI    = (I[6:0] == 7'b0110111); endfunction
function isAUIPC;  input [31:0] I; isAUIPC  = (I[6:0] == 7'b0010111); endfunction
function isJAL;    input [31:0] I; isJAL    = (I[6:0] == 7'b1101111); endfunction
function isJALR;   input [31:0] I; isJALR   = (I[6:0] == 7'b1100111); endfunction
function isBranch; input [31:0] I; isBranch = (I[6:0] == 7'b1100011); endfunction
function isLoad;   input [31:0] I; isLoad   = (I[6:0] == 7'b0000011); endfunction
function isStore;  input [31:0] I; isStore  = (I[6:0] == 7'b0100011); endfunction
function isALUI;   input [31:0] I; isALUI   = (I[6:0] == 7'b0010011); endfunction
function isALUR;   input [31:0] I; isALUR   = (I[6:0] == 7'b0110011); endfunction
function isFENCE;  input [31:0] I; isFENCE  = (I[6:0] == 7'b0001111); endfunction
function isSYS;    input [31:0] I; isSYS    = (I[6:0] == 7'b1110011); endfunction

// Instruction Functions
function [2:0] funct3; input [31:0] I; funct3 = I[14:12]; endfunction
function [6:0] funct7; input [31:0] I; funct7 = I[31:25]; endfunction

// Source and dest registers
function [4:0]  rs1Id; input [31:0] I; rs1Id = I[19:15]; endfunction
function [4:0]  rs2Id; input [31:0] I; rs2Id = I[24:20]; endfunction
function [4:0]  rdId;  input [31:0] I; rdId  = I[11:7];  endfunction
function [11:0] csrID; input [31:0] I; csrID = I[31:20]; endfunction

// Immediate Values
function [31:0] Iimm;
        input [31:0] I;
        Iimm={{21{I[31]}}, I[30:20]};
endfunction

function [31:0] Simm;
        input [31:0] I;
        Simm={{21{I[31]}}, I[30:25],I[11:7]};
endfunction

function [31:0] Bimm;
        input [31:0] I;
        Bimm={{20{I[31]}}, I[7],I[30:25],I[11:8],1'b0};
endfunction

function [31:0] Uimm;
        input [31:0] I;
        Uimm={I[31],       I[30:12], {12{1'b0}}};
endfunction

function [31:0] Jimm;
        input [31:0] I;
        Jimm={{12{I[31]}}, I[19:12],I[20],I[30:21],1'b0};
endfunction

// System Instructions
function isEBREAK;
        input [31:0] I;
        isEBREAK = isSYS(I) & (funct3(I) == 3'b000) & (Iimm(I) == 12'h001);
endfunction

function isCSR;
        input [31:0] I;
        isCSR = isSYS(I) & ((funct3(I) != 3'b000) & (funct3(I) != 3'b100));
endfunction

// Flip a 32 bit word. Used by the shifter
function [31:0] flip32;
        input [31:0] x;
        flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7],
                x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15],
                x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
                x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
endfunction

function writesRd;
        input [31:0] I;
        writesRd = !isStore(I) && !isBranch(I);
endfunction

function readsRs1;
        input [31:0] I;
        readsRs1 = !(isJAL(I) || isAUIPC(I) || isLUI(I));
endfunction

function readsRs2;
        input [31:0] I;
        readsRs2 = isALUR(I) || isBranch(I) || isStore(I);
endfunction

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

always @(posedge clk) begin
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

wire rs1Hazard = !FD_nop && readsRs1(FD_instr) && rs1Id(FD_instr) != 0 && (
        (writesRd(DE_instr) && rs1Id(FD_instr) == rdId(DE_instr)) ||
        (writesRd(EM_instr) && rs1Id(FD_instr) == rdId(EM_instr)) ||
        (writesRd(MW_instr) && rs1Id(FD_instr) == rdId(MW_instr)) ) ;

wire rs2Hazard = !FD_nop && readsRs2(FD_instr) && rs2Id(FD_instr) != 0 && (
        (writesRd(DE_instr) && rs2Id(FD_instr) == rdId(DE_instr)) ||
        (writesRd(EM_instr) && rs2Id(FD_instr) == rdId(EM_instr)) ||
        (writesRd(MW_instr) && rs2Id(FD_instr) == rdId(MW_instr)) ) ;

wire dataHazard = rs1Hazard || rs2Hazard;

assign F_stall = dataHazard | HALT;
assign D_stall = dataHazard | HALT;

assign D_flush = E_jumpOrBranch;
assign E_flush = E_jumpOrBranch | dataHazard;

/******************************************************************************
 ----------------------------------FETCH UNIT----------------------------------
 ******************************************************************************/

reg [31:0] F_PC;

// Jump signals from Execute Unit
wire [31:0] jumpBranchAddr;
wire        jumpOrBranch;

reg [31:0] PROGROM [0:16383];
initial begin $readmemh("../bin/ROM.hex",PROGROM); end

always @(posedge clk) begin
        if (!F_stall) begin
                FD_instr <= PROGROM[F_PC[15:2]];
                FD_PC <= F_PC;
                F_PC <= F_PC + 4;
        end

        if (jumpOrBranch) begin
                F_PC <= jumpBranchAddr;
        end

        FD_nop <= D_flush | reset;

        if (reset) begin
                F_PC <= 0;
        end

end

/*----------------------------------------------------------------------------*/
reg [31:0] FD_PC;
reg [31:0] FD_instr;
reg        FD_nop;
/******************************************************************************
 ---------------------------------DECODE UNIT----------------------------------
 ******************************************************************************/

always @(posedge clk) begin
        if (!D_stall) begin
                DE_PC <= FD_PC;
                DE_instr <= (E_flush | FD_nop) ? NOP : FD_instr;
        end

        if (E_flush)
                DE_instr <= NOP;

        DE_rs1 <= RegisterFile[rs1Id(FD_instr)];
        DE_rs2 <= RegisterFile[rs2Id(FD_instr)];

        if (wbEnable) 
                RegisterFile[wbRdId] <= wbData;
end

always @(posedge clk) begin
end

/*----------------------------------------------------------------------------*/
reg [31:0] DE_PC;
reg [31:0] DE_instr;
reg [31:0] DE_rs1;
reg [31:0] DE_rs2;
/******************************************************************************
 ---------------------------------EXECUTE UNIT--------------------------------*
 ******************************************************************************/

/*----------------------ALU-----------------------*/
wire [31:0] E_aluIn1 = DE_rs1;
wire [31:0] E_aluIn2 =
        isALUR(DE_instr) | isBranch(DE_instr) ? DE_rs2 : Iimm(DE_instr);

// Add Subtract
wire [31:0] E_aluPlus = E_aluIn1 + E_aluIn2;
wire [32:0] E_aluMinus = {1'b0, E_aluIn1} + {1'b1, ~E_aluIn2} + 33'b1;

// Comparisons
wire E_LT  = (E_aluIn1[31] ^ E_aluIn2[31]) ? E_aluIn1[31] : E_aluMinus[32];
wire E_LTU = E_aluMinus[32];
wire E_EQ  = (E_aluMinus[31:0] == 0);

// Bit Shifts
wire E_arithShift = DE_instr[30];
wire [31:0] E_shifterIn = 
        (funct3(DE_instr)==3'b001) ? flip32(E_aluIn1) : E_aluIn1;
wire [31:0] E_shifter =
        $signed({E_arithShift & E_aluIn1[31], E_shifterIn}) >>> E_aluIn2[4:0];
wire [31:0] E_leftShift = flip32(E_shifter);

reg  [31:0] E_aluOut;
always @(*) begin
        case (funct3(DE_instr))
                // Add/Sub
                3'b000: begin
                        if (DE_instr[30] & isALUR(DE_instr)) begin
                                E_aluOut = E_aluMinus[31:0];
                        end else begin
                                E_aluOut = E_aluPlus;
                        end
                end
                // Left Shift
                3'b001: E_aluOut = E_leftShift;
                // Signed Comparason (<)
                3'b010: E_aluOut = {31'b0, E_LT};
                // Unsigned Comparason (<)
                3'b011: E_aluOut = {31'b0, E_LTU};
                // XOR
                3'b100: E_aluOut = E_aluIn1 ^ E_aluIn2;
                // Logical/Atithmetic Right Shift
                3'b101: E_aluOut = E_shifter;
                // OR
                3'b110: E_aluOut = E_aluIn1 | E_aluIn2;
                // AND
                3'b111: E_aluOut = E_aluIn1 & E_aluIn2;
        endcase
end

/*------------------JUMP/BRANCH-------------------*/
reg E_takeBranch;
always @(*) begin
        case (funct3(DE_instr))
                // BEQ
                3'b000:  E_takeBranch = E_EQ;
                // BNE
                3'b001:  E_takeBranch = !E_EQ;
                // BLT
                3'b100:  E_takeBranch = E_LT;
                // BGE
                3'b101:  E_takeBranch = !E_LT;
                // BLTU
                3'b110:  E_takeBranch = E_LTU;
                // BGEU
                3'b111:  E_takeBranch = !E_LTU;
                default: E_takeBranch = 1'b0;
        endcase
end

wire E_jumpOrBranch = (
        isJAL(DE_instr)  ||
        isJALR(DE_instr) ||
        (isBranch(DE_instr) && E_takeBranch)
);

wire [31:0] E_jumpBranchAddr = 
        isBranch(DE_instr) ? DE_PC + Bimm(DE_instr) :
        isJAL(DE_instr)    ? DE_PC + Jimm(DE_instr) :
        /* JALR */           {E_aluPlus[31:1], 1'b0};

wire [31:0] E_result = 
        (isJAL(DE_instr) | isJALR(DE_instr)) ? DE_PC + 4              :
        isLUI(DE_instr)                      ? Uimm(DE_instr)         :
        isAUIPC(DE_instr)                    ? DE_PC + Uimm(DE_instr) :
        /* ALU OP */                           E_aluOut;

/*------------------------------------------------*/
// Memory access address
wire [31:0] E_addr =
        isStore(DE_instr) ? DE_rs1 + Simm(DE_instr) : DE_rs1 + Iimm(DE_instr);

always @(posedge clk) begin
        EM_PC <= DE_PC;
        EM_instr <= DE_instr;
        EM_rs2 <= DE_rs2;
        EM_Eresult <= E_result;
        EM_addr <= E_addr;
end

assign HALT = !reset & isEBREAK(DE_instr);
assign jumpBranchAddr = E_jumpBranchAddr;
assign jumpOrBranch = E_jumpOrBranch;

/*----------------------------------------------------------------------------*/
reg [31:0] EM_PC;
reg [31:0] EM_instr;
reg [31:0] EM_rs2;
reg [31:0] EM_Eresult;
reg [31:0] EM_addr;
/******************************************************************************
 ------------------------------MEMORY ACCESS UNIT-----------------------------*
 ******************************************************************************/

wire [2:0] M_funct3 = funct3(EM_instr);
wire M_is8 = (M_funct3[1:0] == 2'b00);
wire M_isH = (M_funct3[1:0] == 2'b01);

/*----------------------STORE---------------------*/
wire [31:0] M_storeData;
assign M_storeData [7:0]  = EM_rs2[7:0];
assign M_storeData[15:8]  = EM_addr[0] ? EM_rs2[7:0]  : EM_rs2[15:8];
assign M_storeData[23:16] = EM_addr[1] ? EM_rs2[7:0]  : EM_rs2[23:16];
assign M_storeData[31:24] = EM_addr[0] ? EM_rs2[7:0]  :
		            EM_addr[1] ? EM_rs2[15:8] : EM_rs2[31:24];

reg [3:0] M_storeMask;
always @(*) begin
        if (M_is8) begin
                if (EM_addr[1:0] == 2'b11)
                        M_storeMask <= 4'b1000;
                else if (EM_addr[1:0] == 2'b10)
                        M_storeMask <= 4'b0100;
                else if (EM_addr[1:0] == 2'b01)
                        M_storeMask <= 4'b0010;
                else
                        M_storeMask <= 4'b0001;
        end else if (M_isH) begin
                if (EM_addr[1])
                        M_storeMask <= 4'b1100;
                else
                        M_storeMask <= 4'b0011;
        end else begin
                M_storeMask <= 4'b1111;
        end
end

wire M_isIO  = EM_addr[22];
wire M_isRAM = !M_isIO;

assign IO_memAddr  = EM_addr;
assign IO_memWr    = isStore(EM_instr) && M_isIO;
assign IO_memWData = EM_rs2;

wire [3:0] M_wmask = 
        {4{isStore(EM_instr) & M_isRAM}} & M_storeMask;

reg [31:0] DATARAM [0:16383];

initial begin
        $readmemh("../bin/RAM.hex",DATARAM);
end

wire [29:0] M_wordAddr = EM_addr[31:2];
always @(posedge clk) begin
        MW_Mdata <=DATARAM[M_wordAddr];
        if (M_wmask[0]) DATARAM[M_wordAddr][ 7:0 ] <= M_storeData[ 7:0 ];
        if (M_wmask[1]) DATARAM[M_wordAddr][15:8 ] <= M_storeData[15:8 ];
        if (M_wmask[2]) DATARAM[M_wordAddr][23:16] <= M_storeData[23:16];
        if (M_wmask[3]) DATARAM[M_wordAddr][31:24] <= M_storeData[31:24];
end

/*-----------------------CSR----------------------*/
reg [31:0] M_csrData;
always @(*) begin
        if (csrID(EM_instr) == CYCLE_ID)
                M_csrData = cycle[31:0];
        else if (csrID(EM_instr) == CYCLEH_ID)
                M_csrData = cycle[63:32];
        else if (csrID(EM_instr) == INSTRET_ID)
                M_csrData = instret[31:0];
        else // if (csrID(EM_instr) == INSTRETH_ID)
                M_csrData = instret[63:32];
end

/*------------------------------------------------*/
always @(posedge clk) begin
        MW_PC <= EM_PC;
        MW_instr <= EM_instr;
        MW_Eresult <= EM_Eresult;
        MW_IOresult <= IO_memRData;
        MW_addr <= EM_addr;
        MW_CSRresult <= M_csrData;

        if (reset)
                instret <= 0;
        else if (MW_instr != NOP)
                instret <= instret + 1;
end

/*----------------------------------------------------------------------------*/
reg [31:0] MW_PC;
reg [31:0] MW_instr;
reg [31:0] MW_Eresult;
reg [31:0] MW_addr;
reg [31:0] MW_Mdata;
reg [31:0] MW_IOresult;
reg [31:0] MW_CSRresult;
/******************************************************************************
 -------------------------------WRITE BACK UNIT-------------------------------- 
 ******************************************************************************/

wire [2:0] W_funct3 = funct3(MW_instr);

/*----------------------LOAD----------------------*/
// Determine type of load. Word, Halfword, or Byte
wire W_loadByte = (W_funct3[1:0] == 2'b00);
wire W_loadHalf = (W_funct3[1:0] == 2'b01);
wire W_isIO = MW_addr[22];

wire [15:0] W_memHalf = MW_addr[1] ? MW_Mdata[31:16] : MW_Mdata[15:0];
wire [7:0]  W_memByte = MW_addr[0] ? W_memHalf[15:8]  : W_memHalf[7:0];

// Sign expansion
// Based on funct3[2]: 0->sign expand, 1->unsigned
wire W_loadSign = !W_funct3[2] & (W_loadByte ? W_memByte[7] : W_memHalf[15]);

reg [31:0] W_Mresult;
always @(*) begin
        if(W_loadByte)
                W_Mresult <= {{24{W_loadSign}}, W_memByte};
        else if(W_loadHalf)
                W_Mresult <= {{16{W_loadSign}}, W_memHalf};
        else
                W_Mresult <= MW_Mdata;
end

/*----------------REGISTER WRITEBACK--------------*/
assign wbData =
        isLoad(MW_instr) ? (W_isIO ? MW_IOresult : W_Mresult) :
        isCSR(MW_instr)  ? MW_CSRresult : MW_Eresult;

assign wbEnable = 
        !isBranch(MW_instr) && !isStore(MW_instr) && (rdId(MW_instr) != 0);

assign wbRdId = rdId(MW_instr);

/*----------------------------------------------------------------------------*/

`ifdef BENCH
`ifdef VERBOSE
        always @(posedge clk) begin
                if(!reset) begin
                        $write("[F] PC=%h ", F_PC);
                        if(jumpOrBranch) $write(" PC <- 0x%0h",jumpBranchAddr);
                        $write("\n");

                        $write("[D] PC=%h ", FD_PC);
                        $write("[%s%s] ",rs1Hazard?"*":" ",rs2Hazard?"*":" ");
                        riscv_disasm(FD_nop ? NOP : FD_instr,FD_PC);
                        $write("\n");

                        $write("[E] PC=%h ", DE_PC);
                        $write("     ");
                        riscv_disasm(DE_instr,DE_PC);
                        if(DE_instr != NOP) begin
                                $write("  rs1=0x%h  rs2=0x%h  ",DE_rs1, DE_rs2);
                        end
                        $write("\n");

                        $write("[M] PC=%h ", EM_PC);
                        $write("     ");
                        riscv_disasm(EM_instr,EM_PC);
                        $write("\n");

                        $write("[W] PC=%h ", MW_PC);
                        $write("     ");
                        riscv_disasm(MW_instr,MW_PC);
                        if(wbEnable) $write("    x%0d <- 0x%0h",rdId(MW_instr),wbData);
                        $write("\n");

                        $display("");
                end
        end
`endif
`endif

endmodule

