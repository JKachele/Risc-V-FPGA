/*************************************************
 *File----------Decompressor.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Jan 05, 2026 20:40:41 UTC
 ************************************************/

module Decompressor (
        input  wire [31:0] compressed_i,
        output wire [31:0] decompressed_o
);

wire [15:0] c = compressed_i[15:0];
reg  [31:0] dcmp;
assign decompressed_o = dcmp;


/*--------------INSTRUCTION DECODING--------------*/
wire isC0           = c[1:0] == 2'b00;
wire isC1           = c[1:0] == 2'b01;
wire isC2           = c[1:0] == 2'b10;
wire isUncompressed = c[1:0] == 2'b11;

wire isADDI4SPN     = isC0 & c[15:13] == 3'b000;
wire isFLD          = isC0 & c[15:13] == 3'b001;
wire isLW           = isC0 & c[15:13] == 3'b010;
wire isFLW          = isC0 & c[15:13] == 3'b011;
wire isFSD          = isC0 & c[15:13] == 3'b101;
wire isSW           = isC0 & c[15:13] == 3'b110;
wire isFSW          = isC0 & c[15:13] == 3'b111;

wire isADDI         = isC1 & c[15:13] == 3'b000;
wire isJAL          = isC1 & c[15:13] == 3'b001;
wire isLI           = isC1 & c[15:13] == 3'b010;
wire isADDI16SP     = isC1 & c[15:13] == 3'b011 & c[11:7] == 5'b00010;
wire isLUI          = isC1 & c[15:13] == 3'b011 & c[11:7] != 5'b00010;

wire isALUMisc      = isC1 & c[15:13] == 3'b100;
wire isSRLI         = isALUMisc & c[11:10] == 2'b00;
wire isSRAI         = isALUMisc & c[11:10] == 2'b01;
wire isANDI         = isALUMisc & c[11:10] == 2'b10;
wire isSUB          = isALUMisc & c[12:10] == 3'b011 & c[6:5] == 2'b00;
wire isXOR          = isALUMisc & c[12:10] == 3'b011 & c[6:5] == 2'b01;
wire isOR           = isALUMisc & c[12:10] == 3'b011 & c[6:5] == 2'b10;
wire isAND          = isALUMisc & c[12:10] == 3'b011 & c[6:5] == 2'b11;

wire isJ            = isC1 & c[15:13] == 3'b101;
wire isBEQZ         = isC1 & c[15:13] == 3'b110;
wire isBNEZ         = isC1 & c[15:13] == 3'b111;

wire isSLLI         = isC2 & c[15:13] == 3'b000;
wire isFLDSP        = isC2 & c[15:13] == 3'b001;
wire isLWSP         = isC2 & c[15:13] == 3'b010;
wire isFLWSP        = isC2 & c[15:13] == 3'b011;
wire isJR           = isC2 & c[15:13] == 3'b100 & ~c[12] & c[6:2]  == 5'b0;
wire isMV           = isC2 & c[15:13] == 3'b100 & ~c[12] & c[6:2]  != 5'b0;
wire isEBREAK       = isC2 & c[15:13] == 3'b100 &  c[12] & c[11:2] == 10'b0;
wire isJALR         = isC2 & c[15:13] == 3'b100 &  c[12] & c[6:2]  == 5'b0;
wire isADD          = isC2 & c[15:13] == 3'b100 &  c[12] & c[6:2]  != 5'b0;
wire isFSDSP        = isC2 & c[15:13] == 3'b101;
wire isSWSP         = isC2 & c[15:13] == 3'b110;
wire isFSWSP        = isC2 & c[15:13] == 3'b111;

/*---------------INSTRUCTION FIELDS---------------*/
localparam x0 = 5'b00000;
localparam ra = 5'b00001;
localparam sp = 5'b00010;

localparam EBREAK = 32'h00100073;

// Register decoding
wire [4:0] reg1c = {2'b01, c[9:7]};
wire [4:0] reg2c = {2'b01, c[4:2]};
wire [4:0] reg1w = c[11:7];
wire [4:0] reg2w = c[6:2];

// Immediate decoding
wire [11:0] addi4spnImm = {2'b00, c[10:7], c[12:11], c[5], c[6], 2'b00};
wire [11:0]     lwswImm = {5'b00000, c[5], c[12:10] , c[6], 2'b00};
wire [11:0]     ldsdImm = {4'b0000, c[6:5], c[12:10], 3'b000};
wire [11:0]     lwspImm = {4'b0000, c[3:2], c[12], c[6:4], 2'b00};
wire [11:0]     ldspImm = {3'b000, c[4:2], c[12], c[6:5], 3'b000};
wire [11:0]     swspImm = {4'b0000, c[8:7], c[12:9], 2'b00};
wire [11:0]     sdspImm = {3'b000, c[9:7], c[12:10], 3'b000};
wire [11:0] addi16spImm = {{3{c[12]}}, c[4:3], c[5], c[2], c[6], 4'b0000};
wire [11:0]      addImm = {{7{c[12]}}, c[6:2]};
wire [19:0]      jmpImm = {c[12], c[8], c[10:9], c[6], c[7], c[2], c[11], c[5:3], {9{c[12]}}};
wire [19:0]      luiImm = {{15{c[12]}}, c[6:2]};
wire [4:0]     shiftImm = c[6:2];
wire [6:0]   branchImm7 = {{4{c[12]}}, c[6:5], c[2]};
wire [4:0]   branchImm5 = {c[11:10], c[4:3], c[12]};

always @(*) begin
        case(1'b1)
        isUncompressed: dcmp = compressed_i;

        isADDI4SPN: dcmp = {addi4spnImm,   sp,              3'b000, reg2c,        7'b0010011};
        isFLD:      dcmp = {ldsdImm,       reg1c,           3'b011, reg2c,        7'b0000111};
        isLW:       dcmp = {lwswImm,       reg1c,           3'b010, reg2c,        7'b0000011};
        isFLW:      dcmp = {lwswImm,       reg1c,           3'b010, reg2c,        7'b0000111};
        isFSD:      dcmp = {ldsdImm[11:5], reg2c,    reg1c, 3'b011, lwswImm[4:0], 7'b0100111};
        isSW:       dcmp = {lwswImm[11:5], reg2c,    reg1c, 3'b010, lwswImm[4:0], 7'b0100011};
        isFSW:      dcmp = {lwswImm[11:5], reg2c,    reg1c, 3'b010, lwswImm[4:0], 7'b0100111};

        isADDI:     dcmp = {addImm,        reg1w,           3'b000, reg1w,        7'b0010011};
        isJAL:      dcmp = {jmpImm,        ra,                                    7'b1101111};
        isLI:       dcmp = {addImm,        x0,              3'b000, reg1w,        7'b0010011};
        isADDI16SP: dcmp = {addi16spImm,   reg1w,           3'b000, reg1w,        7'b0010011};
        isLUI:      dcmp = {luiImm,        reg1w,                                 7'b0110111};
        isSRLI:     dcmp = {7'b0000000,    shiftImm, reg1c, 3'b101, reg1c,        7'b0010011};
        isSRAI:     dcmp = {7'b0100000,    shiftImm, reg1c, 3'b101, reg1c,        7'b0010011}; 
        isANDI:     dcmp = {addImm,        reg1c,           3'b111, reg1c,        7'b0010011};
        isSUB:      dcmp = {7'b0100000,    reg2c,    reg1c, 3'b000, reg1c,        7'b0110011};
        isXOR:      dcmp = {7'b0000000,    reg2c,    reg1c, 3'b100, reg1c,        7'b0110011}; 
        isOR:       dcmp = {7'b0000000,    reg2c,    reg1c, 3'b110, reg1c,        7'b0110011};
        isAND:      dcmp = {7'b0000000,    reg2c,    reg1c, 3'b111, reg1c,        7'b0110011};
        isJ:        dcmp = {jmpImm,        x0,                                    7'b1101111};
        isBEQZ:     dcmp = {branchImm7,    x0,       reg1c, 3'b000, branchImm5,   7'b1100011};
        isBNEZ:     dcmp = {branchImm7,    x0,       reg1c, 3'b001, branchImm5,   7'b1100011};

        isSLLI:     dcmp = {7'b0000000,    shiftImm, reg1w, 3'b001, reg1w,        7'b0010011};
        isFLDSP:    dcmp = {lwspImm,       sp,              3'b011, reg1w,        7'b0000111};
        isLWSP:     dcmp = {lwspImm,       sp,              3'b010, reg1w,        7'b0000011};
        isFLWSP:    dcmp = {lwspImm,       sp,              3'b010, reg1w,        7'b0000111};
        isJR:       dcmp = {12'b0,         reg1w,           3'b000, x0,           7'b1100111};
        isMV:       dcmp = {7'b0,          reg2w,    x0,    3'b000, reg1w,        7'b0110011};
        isEBREAK:   dcmp = EBREAK;
        isJALR:     dcmp = {12'b0,         reg1w,           3'b000, ra,           7'b1100111};
        isADD:      dcmp = {7'b0,          reg2w,    reg1w, 3'b000, reg1w,        7'b0110011};
        isFSDSP:    dcmp = {swspImm[11:5], reg2w,    sp,    3'b011, swspImm[4:0], 7'b0100111};
        isSWSP:     dcmp = {swspImm[11:5], reg2w,    sp,    3'b010, swspImm[4:0], 7'b0100011};
        isFSWSP:    dcmp = {swspImm[11:5], reg2w,    sp,    3'b010, swspImm[4:0], 7'b0100111};
        endcase
end

endmodule

