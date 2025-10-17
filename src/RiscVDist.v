`include "Extern/Clockworks.v"

module SOC (
        input  CLK,        // system clock 
        input  RESET,      // reset button
        output [3:0] LEDS, // system LEDs
        input  RXD,        // UART receive
        output TXD         // UART transmit
);

wire clk;    // internal clock
wire resetn; // internal reset signal, goes low on reset

reg [31:0] MEM [0:255]; 
reg [31:0] PC;       // program counter
reg [31:0] instr;    // current instruction

initial begin
        PC = 0;
        // add x0, x0, x0
        //                   rs2   rs1  add  rd   ALUREG
        instr = 32'b0000000_00000_00000_000_00000_0110011;
        // add x1, x0, x0
        //                    rs2   rs1  add  rd  ALUREG
        MEM[0] = 32'b0000000_00000_00000_000_00001_0110011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[1] = 32'b000000000001_00001_000_00001_0010011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[2] = 32'b000000000001_00001_000_00001_0010011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[3] = 32'b000000000001_00001_000_00001_0010011;
        // addi x1, x1, 1
        //             imm         rs1  add  rd   ALUIMM
        MEM[4] = 32'b000000000001_00001_000_00001_0010011;
        // lw x2,0(x1)
        //             imm         rs1   w   rd   LOAD
        MEM[5] = 32'b000000000000_00001_010_00010_0000011;
        // sw x2,0(x1)
        //             imm   rs2   rs1   w   imm  STORE
        MEM[6] = 32'b000000_00010_00001_010_00000_0100011;

        // ebreak
        //                                        SYSTEM
        MEM[7] = 32'b000000000001_00000_000_00000_1110011;
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

always @(posedge clk) begin
        if(!resetn) begin
                PC <= 0;
                instr <= 32'b0000000_00000_00000_000_00000_0110011; // NOP
        end else if(!isSYS) begin
                instr <= MEM[PC];
                PC <= PC+1;
        end
        `ifdef BENCH      
                if(isSYS) $finish();
        `endif      
   end

   assign LEDS = isSYS ? 31 : {PC[0],isALUR,isALUI,isStore,isLoad};

   `ifdef BENCH   
           always @(posedge clk) begin
                   $display("PC=%0d",PC);
                   case (1'b1)
                           isALUR: $display(
                                   "ALUR rd=%d rs1=%d rs2=%d funct3=%b",
                                   rdId, rs1Id, rs2Id, funct3
                           );
                           isALUI: $display(
                                   "ALUI rd=%d rs1=%d imm=%0d funct3=%b",
                                   rdId, rs1Id, Iimm, funct3
                           );
                           isBranch: $display("BRANCH");
                           isJAL:    $display("JAL");
                           isJALR:   $display("JALR");
                           isAUIPC:  $display("AUIPC");
                           isLUI:    $display("LUI");	
                           isLoad:   $display("LOAD");
                           isStore:  $display("STORE");
                           isSYS:    $display("SYSTEM");
                   endcase 
           end
   `endif

Clockworks #(
        .SLOW(21)
) CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(resetn)
);

assign TXD  = 1'b0; // not used for now
endmodule
