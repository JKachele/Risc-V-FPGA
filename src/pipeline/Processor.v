/*************************************************
 *File----------Processor.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:09:17 UTC
 ************************************************/
module Processor(
        input  clk,
        input  reset,
        // output [31:0] progRomAddr,
        // input  [31:0] progRomData,
        output [31:0] ramAddr,
        input  [31:0] ramRData,
        output ramRStrb,
        output [31:0] memWData,
        output [3:0]  memWMask
);

reg [31:0] PROGROM [0:16383];

initial begin
        $readmemh("../bin/ROM.hex",PROGROM);
end

reg [31:0] PC;       // program counter
reg [31:0] instr;    // current instruction

// Used RISC-V ISM Version 20250508, Ch. 35, Page 609
// 11 RISC-V OpCodes
wire isLUI      = (instr[6:0] == 7'b0110111);
wire isAUIPC    = (instr[6:0] == 7'b0010111);
wire isJAL      = (instr[6:0] == 7'b1101111);
wire isJALR     = (instr[6:0] == 7'b1100111);
wire isBranch   = (instr[6:0] == 7'b1100011);
wire isLoad     = (instr[6:0] == 7'b0000011);
wire isStore    = (instr[6:0] == 7'b0100011);
wire isALUI     = (instr[6:0] == 7'b0010011);
wire isALUR     = (instr[6:0] == 7'b0110011);
wire isFENCE    = (instr[6:0] == 7'b0001111);
wire isSYS      = (instr[6:0] == 7'b1110011);

// Instruction Functions
wire [2:0] funct3 = instr[14:12];
wire [6:0] funct7 = instr[31:25];

// Source and dest registers
wire [4:0] rs1Id = instr[19:15];
wire [4:0] rs2Id = instr[24:20];
wire [4:0] rdId  = instr[11:7];

// Immediate Values
wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
wire [31:0] Uimm={instr[31],       instr[30:12], {12{1'b0}}};
wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};

wire isEBREAK = isSYS & (funct3 == 3'b000) & (Iimm == 12'h001);
reg HALT = 0;

wire isCSR = isSYS & ((funct3 != 3'b000) & (funct3 != 3'b100));
wire [11:0] csrID = instr[31:20];

// Address for Load/Store
wire [31:0] loadStoreAddr = rs1 + (isStore ? Simm : Iimm);

/************************************************
 -----------------REGISTER FILE------------------
 ************************************************/
reg [31:0] RegisterFile [0:31];
reg [31:0] rs1;
reg [31:0] rs2;
wire [31:0] writeBackData;
wire writeBackEn;

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

/************************************************
 ----------------------ALU-----------------------
 ************************************************/
wire [31:0] aluIn1 = rs1;
wire [31:0] aluIn2 = isALUR | isBranch ? rs2 : Iimm;

wire [31:0] aluPlus = aluIn1 + aluIn2;
wire [32:0] aluMinus = {1'b0, aluIn1} + {1'b1, ~aluIn2} + 33'b1;

wire LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
wire LTU = aluMinus[32];
wire EQ  = (aluMinus[31:0] == 0);

wire [31:0] shifter = $signed({instr[30] & aluIn1[31], aluIn1}) >>> aluIn2[4:0];

reg  [31:0] aluOut;
always @(*) begin
        case (funct3)
                // Add/Sub
                3'b000: begin
                        if (funct7[5] == 1'b1 && isALUR) begin
                                aluOut = aluMinus[31:0];
                        end else begin
                                aluOut = aluPlus;
                        end
                end
                // Left Shift
                3'b001: aluOut = aluIn1 << aluIn2[4:0];
                // Signed Comparason (<)
                3'b010: aluOut = {31'b0, LT};
                // Unsigned Comparason (<)
                3'b011: aluOut = {31'b0, LTU};
                // XOR
                3'b100: aluOut = aluIn1 ^ aluIn2;
                // Logical/Atithmetic Right Shift
                3'b101: aluOut = shifter;
                // OR
                3'b110: aluOut = aluIn1 | aluIn2;
                // AND
                3'b111: aluOut = aluIn1 & aluIn2;
        endcase
end

/************************************************
 -----------------------CSR----------------------
 ************************************************/
reg [31:0] csrData;
always @(*) begin
        if (csrID == CYCLE_ID)
                csrData = cycle[31:0];
        else if (csrID == CYCLEH_ID)
                csrData = cycle[63:32];
        else if (csrID == INSTRET_ID)
                csrData = instret[31:0];
        else // if (csrID == INSTRETH_ID)
                csrData = instret[63:32];
end

/************************************************
 ---------------------BRANCH---------------------
 ************************************************/
reg takeBranch;
always @(*) begin
        case (funct3)
                // BEQ
                3'b000:  takeBranch = EQ;
                // BNE
                3'b001:  takeBranch = !EQ;
                // BLT
                3'b100:  takeBranch = LT;
                // BGE
                3'b101:  takeBranch = !LT;
                // BLTU
                3'b110: takeBranch = LTU;
                // BGEU
                3'b111: takeBranch = !LTU;
                default:  takeBranch = 1'b0;
        endcase
end

/************************************************
 ---------------------JUMPS----------------------
 ************************************************/

wire [31:0] PCplusImm = PC + ( instr[3] ? Jimm[31:0] :
        instr[4] ? Uimm[31:0] :
        Bimm[31:0]);
wire [31:0] PCplus4 = PC + 4;

reg [31:0] nextPC;
always @(*) begin
        if ((isBranch && takeBranch) || isJAL) begin
                nextPC = PCplusImm;
        end else if (isJALR) begin
                nextPC = {aluPlus[31:1],1'b0};
        end else begin
                nextPC = PCplus4;
        end
end

/************************************************
 ----------------------LOAD----------------------
 ************************************************/
// Determine type of load. Word, Halfword, or Byte
wire loadStoreByte = (funct3[1:0] == 2'b00);
wire loadStoreHalf = (funct3[1:0] == 2'b01);

wire [15:0] memHalf = loadStoreAddr[1] ? ramRData[31:16] : ramRData[15:0];
wire [7:0]  memByte = loadStoreAddr[0] ? memHalf[15:8]  : memHalf[7:0];

// Sign expansion
// Based on funct3[2]: 0->sign expand, 1->unsigned
wire loadSign = !funct3[2] & (loadStoreByte ? memByte[7] : memHalf[15]);

reg [31:0] loadData;
always @(*) begin
        if(loadStoreByte)
                loadData <= {{24{loadSign}}, memByte};
        else if(loadStoreHalf)
                loadData <= {{16{loadSign}}, memHalf};
        else
                loadData <= ramRData;
end

/************************************************
 ---------------------STORE----------------------
 ************************************************/
assign memWData [7:0]  = rs2[7:0];
assign memWData[15:8]  = loadStoreAddr[0] ? rs2[7:0]  : rs2[15:8];
assign memWData[23:16] = loadStoreAddr[1] ? rs2[7:0]  : rs2[23:16];
assign memWData[31:24] = loadStoreAddr[0] ? rs2[7:0]  :
		         loadStoreAddr[1] ? rs2[15:8] : rs2[31:24];

reg [3:0] storeMask;
always @(*) begin
        if (loadStoreByte) begin
                if (loadStoreAddr[1:0] == 2'b11)
                        storeMask <= 4'b1000;
                else if (loadStoreAddr[1:0] == 2'b10)
                        storeMask <= 4'b0100;
                else if (loadStoreAddr[1:0] == 2'b01)
                        storeMask <= 4'b0010;
                else
                        storeMask <= 4'b0001;
        end else if (loadStoreHalf) begin
                if (loadStoreAddr[1])
                        storeMask <= 4'b1100;
                else
                        storeMask <= 4'b0011;
        end else begin
                storeMask <= 4'b1111;
        end
end

/************************************************
 ------------------STATE MACHINE-----------------
 ************************************************/
localparam FETCH_INSTR = 0;
localparam WAIT_INSTR  = 1;
localparam EXECUTE     = 2;
localparam WAIT_DATA   = 3;
reg [1:0] state = FETCH_INSTR;

// Instruction fetching
// assign progRomAddr = PC;
assign ramAddr = loadStoreAddr;
assign ramRStrb = (state == EXECUTE & isLoad);
assign memWMask = {4{(state == EXECUTE ) & isStore}} & storeMask;

// Register Write Back
assign writeBackData = (isJAL || isJALR) ? PCplus4      :
                       (isLUI)           ? Uimm         :
                       (isAUIPC)         ? PCplusImm    :
                       (isLoad)          ? loadData     :
                       (isCSR)           ? csrData      :
                                           aluOut;

assign writeBackEn = ((state == EXECUTE && !isBranch && !isStore) ||
                      (state == WAIT_DATA));

// State Machine
always @(posedge clk or posedge reset) begin
        if(reset) begin
                PC <= 0;
                state <= FETCH_INSTR;
        end else begin
                if(writeBackEn && rdId != 0) begin
                        RegisterFile[rdId] <= writeBackData;
                end

                case(state)
                        FETCH_INSTR: begin
                                instr <= PROGROM[PC[15:2]];
                                state <= WAIT_INSTR;
                        end
                        WAIT_INSTR: begin
                                rs1 <= RegisterFile[instr[19:15]];
                                rs2 <= RegisterFile[instr[24:20]];
                                instret <= instret + 1;
                                state <= EXECUTE;
                        end
                        EXECUTE: begin
                                if(!isEBREAK)
                                        PC <= nextPC;
                                else
                                        HALT <= 1;

                                if (isLoad)
                                        state <= WAIT_DATA;
                                else
                                        state <= FETCH_INSTR;
                        end
                        WAIT_DATA: begin
                                state <= FETCH_INSTR;
                        end
                endcase
        end
end

endmodule

