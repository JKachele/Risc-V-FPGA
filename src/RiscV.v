`include "Clockworks.v"

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

// A blinker that counts on 5 bits, wired to the 5 LEDs
reg [3:0] count = 0;
always @(posedge clk) begin
        count <= count + 1;
end

Clockworks #(
        .SLOW(21)
) CW(
        .CLK(CLK),
        .RESET(RESET),
        .clk(clk),
        .resetn(resetn)
);

assign LEDS = count;
assign TXD  = 1'b0; // not used for now
endmodule
