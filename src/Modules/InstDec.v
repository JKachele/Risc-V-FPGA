module InstDec (
        input [31:0] PC,
        input [31:0] INSTR,
        output [3:0] INST_TYPE,
        output [2:0] FUNCT3,
        output [6:0] FUNCT7,
        output [4:0] RS1,
        output [4:0] RS2,
        output [4:0] RD,
        output [31:0] IMM
);

// Used RISC-V ISM Version 20250508, Ch. 35, Page 609
// 11 RISC-V OpCodes
localparam LUI    = {7'b0110111,  0};
localparam AUIPC  = {7'b0010111,  1};
localparam JAL    = {7'b1101111,  2};
localparam JALR   = {7'b1100111,  3};
localparam BRANCH = {7'b1100011,  4};
localparam LOAD   = {7'b0000011,  5};
localparam STORE  = {7'b0100011,  6};
localparam ALUI   = {7'b0010011,  7};
localparam ALUR   = {7'b0110011,  8};
localparam FENCE  = {7'b0001111,  9};
localparam SYS    = {7'b1110011, 10};

// Instruction Functions
FUNCT3 = instr[14:12];
FUNCT7 = instr[31:25];

// Source and dest registers
RS1 = instr[19:15];
RS2 = instr[24:20];
RD  = instr[11:7];

// Immediate Values
wire [31:0] Iimm={{21{instr[31]}}, instr[30:20]};
wire [31:0] Simm={{21{instr[31]}}, instr[30:25],instr[11:7]};
wire [31:0] Bimm={{20{instr[31]}}, instr[7],instr[30:25],instr[11:8],1'b0};
wire [31:0] Uimm={instr[31],       instr[30:12], {12{1'b0}}};
wire [31:0] Jimm={{12{instr[31]}}, instr[19:12],instr[20],instr[30:21],1'b0};

endmodule
