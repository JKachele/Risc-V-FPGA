/*************************************************
 *File----------FPU2.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 17:36:54 UTC
 ************************************************/

module FPU2 (
        input  wire        clk_i,
        input  wire        reset_i,

        input  wire        fpuEnable_i,
        input  wire [31:0] instr_i,
        input  wire [31:0] rs1_i,
        input  wire [31:0] rs2_i,
        input  wire [31:0] rs3_i,

        output reg         busy_o,
        output wire [31:0] fpuOut_o
);

/**************** RV32F Instruction Decoder ****************/
wire isFMADD   = (instr_i[4:2] == 3'b000);
wire isFMSUB   = (instr_i[4:2] == 3'b001);
wire isFMNSUB  = (instr_i[4:2] == 3'b010);
wire isFMNADD  = (instr_i[4:2] == 3'b011);
wire isFMA     = !instr_i[4];

wire isFADD    = (!isFMA && (instr_i[31:27] == 5'b00000));
wire isFSUB    = (!isFMA && (instr_i[31:27] == 5'b00001));
wire isFMUL    = (!isFMA && (instr_i[31:27] == 5'b00010));
wire isFDIV    = (!isFMA && (instr_i[31:27] == 5'b00011));
wire isFSQRT   = (!isFMA && (instr_i[31:27] == 5'b01011));   

wire isFSGNJ   = (!isFMA && (instr_i[31:27]==5'b00100)&&(instr_i[13:12]==2'b00));
wire isFSGNJN  = (!isFMA && (instr_i[31:27]==5'b00100)&&(instr_i[13:12]==2'b01));
wire isFSGNJX  = (!isFMA && (instr_i[31:27]==5'b00100)&&(instr_i[13:12]==2'b10));

wire isFMIN    = (!isFMA && (instr_i[31:27] == 5'b00101) && !instr_i[12]);
wire isFMAX    = (!isFMA && (instr_i[31:27] == 5'b00101) &&  instr_i[12]);

wire isFEQ     = (!isFMA && (instr_i[31:27]==5'b10100) && (instr_i[13:12] == 2'b10));
wire isFLT     = (!isFMA && (instr_i[31:27]==5'b10100) && (instr_i[13:12] == 2'b01));
wire isFLE     = (!isFMA && (instr_i[31:27]==5'b10100) && (instr_i[13:12] == 2'b00));

wire isFCLASS  = (!isFMA && (instr_i[31:27] == 5'b11100) &&  instr_i[12]); 

wire isFCVTWS  = (!isFMA && (instr_i[31:27] == 5'b11000) && !instr_i[20]);
wire isFCVTWUS = (!isFMA && (instr_i[31:27] == 5'b11000) &&  instr_i[20]);

wire isFCVTSW  = (!isFMA && (instr_i[31:27] == 5'b11010) && !instr_i[20]);
wire isFCVTSWU = (!isFMA && (instr_i[31:27] == 5'b11010) &&  instr_i[20]);

wire isFMVXW   = (!isFMA && (instr_i[31:27] == 5'b11100) && !instr_i[12]);
wire isFMVWX   = (!isFMA && (instr_i[31:27] == 5'b11110));
endmodule

