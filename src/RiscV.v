/*************************************************
*File----------RiscV.v
*Project-------Risc-V-FPGA
*Author--------Justin Kachele
*Created-------Friday Oct 17, 2025 15:26:01 UTC
*License-------GNU GPL-3.0
************************************************/
`include "Extern/Clockworks.v"

module SOC (
        input  CLK,        // system clock 
        input  RESET,      // reset button
        output [7:0] LEDS, // system LEDs
        input  RXD,        // UART receive
        output TXD         // UART transmit
);

wire clk;    // internal clock
wire resetn; // internal reset signal, goes low on reset

// LEDs
reg [7:0] leds;
assign LEDS = leds;

reg [31:0] MEM [0:255]; 
reg [31:0] PC = 0;   // program counter
reg [31:0] instr;    // current instruction

`include "Extern/RiscvAssembler.v"
integer L0_ = 16;
initial begin
        LUI(x1, 32'b11111111111111111111111111111111);     // Just takes the 20 MSBs (12 LSBs ignored)
        ORI(x1, x1, 32'b11111111111111111111111111111111); // Sets the 12 LSBs (20 MSBs ignored)
        ADD(x1,x0,x0);
        ADDI(x2,x0,32);
        Label(L0_); 
        ADDI(x1,x1,1); 
        BNE(x1, x2, LabelRef(L0_));
        EBREAK();
        endASM();
end

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

// Register File
reg  [31:0] RegisterFile [0:31];
reg  [31:0] rs1;
reg  [31:0] rs2;
wire [31:0] writeBackData;
wire        writeBackEn;

// Initalize Registers if using sim
`ifdef BENCH   
        integer i;
        initial begin
                for(i=0; i<32; ++i) begin
                        RegisterFile[i] = 0;
                end
        end
`endif

// ALU
wire [31:0] aluIn1 = rs1;
wire [31:0] aluIn2 = isALUR ? rs2 : Iimm;
wire [4:0]  shamt  = isALUR ? rs2[4:0] : Iimm[4:0]; // Shift Amount
reg  [31:0] aluOut;

always @(*) begin
        case (funct3)
                AddSub: begin
                        if (funct7[5] == 1'b1 && isALUR) begin
                                aluOut = aluIn1 - aluIn2;
                        end else begin
                                aluOut = aluIn1 + aluIn2;
                        end
                end
                ShiftL: aluOut = aluIn1 << shamt;
                Less:   aluOut = $signed(aluIn1) < $signed(aluIn2);
                LessU:  aluOut = aluIn1 < aluIn2;
                Xor:    aluOut = aluIn1 ^ aluIn2;
                ShiftR: begin
                        if (funct7[5] == 1'b1) begin
                                aluOut = $signed(aluIn1) >>> shamt;
                        end else begin
                                aluOut = aluIn1 >> shamt;
                        end
                end
                Or:     aluOut = aluIn1 | aluIn2;
                And:    aluOut = aluIn1 & aluIn2;
        endcase
end

// Branch
reg takeBranch;
always @(*) begin
        case (funct3)
                INS_BEQ:  takeBranch = (rs1 == rs2);
                INS_BNE:  takeBranch = (rs1 != rs2);
                INS_BLT:  takeBranch = ($signed(rs1)  < $signed(rs2));
                INS_BGE:  takeBranch = ($signed(rs1) >= $signed(rs2)); 
                INS_BLTU: takeBranch = (rs1 < rs2);
                INS_BGEU: takeBranch = (rs1 >= rs2);
                default:  takeBranch = 1'b0;
        endcase
end

// Jumps
always @(*) begin
        if (isBranch && takeBranch) begin
                nextPC = PC + Bimm;
        end else if (isJAL) begin
                nextPC = PC + Jimm;
        end else if (isJALR) begin
                nextPC = rs1 + Iimm;
        end else begin
                nextPC = PC + 4;
        end
end

// State Machine
localparam FETCH_INSTR = 0;
localparam FETCH_REG   = 1;
localparam EXECUTE     = 2;
reg [1:0] state = FETCH_INSTR;
reg [31:0] nextPC;

assign writeBackData = (isJAL || isJALR) ? (PC + 4) :
        (isLUI) ? Uimm :
        (isAUIPC) ? (PC + Uimm) :
        aluOut;

assign writeBackEn   = (state == EXECUTE && (
        isALUR ||
        isALUI ||
        isJAL  ||
        isJALR ||
        isLUI  ||
        isAUIPC
));

always @(posedge clk) begin
        if (!resetn) begin
                PC <= 0;
                state <= FETCH_INSTR;
        end else if (writeBackEn && rdId != 0) begin
                RegisterFile[rdId] <= writeBackData;
                // For displaying what happens.
                if(rdId == 1) begin
                        leds <= writeBackData;
                end
                `ifdef BENCH	 
                        $display("x%0d <= %b",rdId,writeBackData);
                `endif
        end

        case(state)
                FETCH_INSTR: begin
                        instr <= MEM[PC[31:2]];
                        state <= FETCH_REG;
                end
                FETCH_REG: begin
                        rs1 <= RegisterFile[rs1Id];
                        rs2 <= RegisterFile[rs2Id];
                        state <= EXECUTE;
                end
                EXECUTE: begin
                        if (!isSYS) begin
                                PC <= nextPC;
                        end
                        state <= FETCH_INSTR;
                        `ifdef BENCH      
                                if(isSYS) $finish();
                        `endif      
        end
endcase
end

// `ifdef BENCH   
//         always @(posedge clk) begin
//                 if (state == FETCH_REG) begin
//                         case (1'b1)
//                                 isALUR: $display(
//                                         "ALUR rd=%d rs1=%d rs2=%d funct3=%b",
//                                         rdId, rs1Id, rs2Id, funct3
//                                 );
//                                 isALUI: $display(
//                                         "ALUI rd=%d rs1=%d imm=%0d funct3=%b",
//                                         rdId, rs1Id, Iimm, funct3
//                                 );
//                                 isBranch: $display("BRANCH");
//                                 isJAL:    $display("JAL");
//                                 isJALR:   $display("JALR");
//                                 isAUIPC:  $display("AUIPC");
//                                 isLUI:    $display("LUI");	
//                                 isLoad:   $display("LOAD");
//                                 isStore:  $display("STORE");
//                                 isSYS:    $display("SYSTEM");
//                         endcase 
//                         if(isSYS) begin
//                                 $finish();
//                         end
//                 end
//         end
// `endif

Clockworks #(
        .SLOW(19)
) CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(resetn)
);

assign TXD  = 1'b0; // not used for now

// Local Params (Enums)
// OpCodes
localparam OP_LUI      = 0;
localparam OP_AUIPC    = 1;
localparam OP_JAL      = 2;
localparam OP_JALR     = 3;
localparam OP_BRANCH   = 4;
localparam OP_LOAD     = 5;
localparam OP_STORE    = 6;
localparam OP_ALUI     = 7;
localparam OP_ALUR     = 8;
localparam OP_FENCE    = 9;
localparam OP_SYS      = 10;

// ALU Instructions
localparam AddSub = 3'b000;
localparam ShiftL = 3'b001;
localparam Less   = 3'b010;
localparam LessU  = 3'b011;
localparam Xor    = 3'b100;
localparam ShiftR = 3'b101;
localparam Or     = 3'b110;
localparam And    = 3'b111;

// Branch Instructions
localparam INS_BEQ  = 3'b000;
localparam INS_BNE  = 3'b001;
localparam INS_BLT  = 3'b100;
localparam INS_BGE  = 3'b101;
localparam INS_BLTU = 3'b110;
localparam INS_BGEU = 3'b111;

endmodule

