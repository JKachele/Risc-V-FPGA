/*************************************************
 *File----------FPU.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday Dec 03, 2025 19:09:22 UTC
 ************************************************/

module FPU (
        input  wire        clk_i,
        input  wire        reset_i,

        input  wire        fpuEnable_i,
        input  wire [31:2] instr_i,
        input  wire [31:0] rs1_i,
        input  wire [31:0] rs2_i,
        input  wire [31:0] rs3_i,

        output wire        busy_o,
        output wire [31:0] fpuOut_o
);

// High res FP Registers for math opps
reg x_sign; reg signed [8:0] x_exp; reg signed [49:0] x_mant;
reg y_sign; reg signed [8:0] y_exp; reg signed [49:0] y_mant;

// Single-precision FP Registers for internal use
reg a_sign; reg [8:0] a_exp; reg [23:0] a_mant;
reg b_sign; reg [8:0] b_exp; reg [23:0] b_mant;
reg c_sign; reg [8:0] c_exp; reg [23:0] c_mant;
reg d_sign; reg [8:0] d_exp; reg [23:0] d_mant;
reg e_sign; reg [8:0] e_exp; reg [23:0] e_mant;
/* NOTE: exp is biased by 127 and mant includes implied leading 1 */

// Macros for moving values in registers
`define FP_LD32(RD,VAL)\
        {RD``_sign, RD``_exp, RD``_mant[22:0]} <= VAL; RD``_mant[23] <= 1'b1

`define FP_LD(RD,sign,exp,mant)\
        {RD``_sign, RD``_exp, RD``_mant} <= {sign,exp,mant}

`define FP_MV(RD,RS)\
        {RD``_sign, RD``_exp, RD``_mant} <= {RS``_sign, RS``_exp, RS``_mant} 

// FPU Micro-instruction States
localparam FPMI_READY           = 0;
localparam FPMI_LOAD_XY         = 1;    // x <- a, y <- b
localparam FPMI_ADD_SWAP        = 2;    // if |x|>|y|, swap, negX if sign diff
localparam FPMI_ADD_SHIFT       = 3;    // Shift x to match y exp
localparam FPMI_ADD_ADD         = 4;    // x <- x + y
localparam FPMI_ADD_NORM        = 5;    // normalize x after add
localparam FPMI_LOAD_XY_MUL     = 6;    // x <- norm(a*b), y <- c

localparam FPMI_NUM_STATES = 7;
localparam FPMI_BITS = $clog2(FPMI_NUM_STATES) + 1;

// Exit flag
localparam FPMI_EXIT_BIT  = FPMI_BITS;
localparam FPMI_EXIT_FLAG = 1 << FPMI_BITS;

// FPMI ROM to store FPU Opperation procedure
localparam FPMI_ROM_SIZE = 128;
reg [FPMI_BITS:0] FPMI_ROM[0:FPMI_ROM_SIZE-1];

task fpmi_gen; input [FPMI_BITS:0] instr; begin
        FPMI_ROM[I] = instr;
        I = I + 1;
end endtask

// Procedure Start Addresses
integer FPMPROG_ADD, FPMPROG_MUL, FPMPROG_MADD;

// Generate FPU Procedures
integer I;
initial begin
        I = 0;
        fpmi_gen(FPMI_READY | FPMI_EXIT_FLAG);

        /******** FADD, FSUB ********/
        FPMPROG_ADD = I;
        fpmi_gen(FPMI_LOAD_XY);
        fpmi_gen(FPMI_ADD_SWAP);
        fpmi_gen(FPMI_ADD_SHIFT);
        fpmi_gen(FPMI_ADD_ADD);
        fpmi_gen(FPMI_ADD_NORM | FPMI_EXIT_FLAG);

        /******** FMUL ********/
        FPMPROG_MUL = I;
        fpmi_gen(FPMI_LOAD_XY_MUL | FPMI_EXIT_FLAG);

        /******** F[N]MADD, F[N]MSUB ********/
        FPMPROG_MADD = I;
        fpmi_gen(FPMI_LOAD_XY_MUL);
        fpmi_gen(FPMI_ADD_SWAP);
        fpmi_gen(FPMI_ADD_SHIFT);
        fpmi_gen(FPMI_ADD_ADD);
        fpmi_gen(FPMI_ADD_NORM | FPMI_EXIT_FLAG);
end

// Set procedure to run based off decoded instruction
reg [7:0] fpmprog;
always @(*) begin
        case(1'b1)
                isFADD  | isFSUB                        : fpmprog = FPMPROG_ADD;
                isFMUL                                  : fpmprog = FPMPROG_MUL;
                isFMADD | isFMSUB | isFNMADD | isFNMSUB : fpmprog = FPMPROG_MUL;
        endcase
end

// Micro Instruction State Machine
reg [7:0]         fpmi_PC;
reg [FPMI_BITS:0] fpmi_instr;
(* onehot *)
wire [FPMI_NUM_STATES-1:0] fpmi_is = 1 << fpmi_instr[FPMI_BITS-1:0];

initial fpmi_PC = FPMI_READY;
assign busy_o = !fpmi_is[FPMI_READY];

wire [7:0] fpmi_next_pc =
        fpuEnable_i               ? fpmprog :
        fpmi_instr[FPMI_EXIT_BIT] ? 0       : fpmi_PC + 1;;

always @(posedge clk_i) begin
        fpmi_PC <= fpmi_next_pc;
        fpmi_instr <= FPMI_ROM[fpmi_next_PC];
end

// RV32F Instruction Decoder
wire isFMADD   = (instr[4:2] == 3'b000);
wire isFMSUB   = (instr[4:2] == 3'b001);
wire isFMNSUB  = (instr[4:2] == 3'b010);
wire isFMNADD  = (instr[4:2] == 3'b011);
wire isFMA     = !instr[4];

wire isFADD    = (!isFMA && (instr[31:27] == 5'b00000));
wire isFSUB    = (!isFMA && (instr[31:27] == 5'b00001));
wire isFMUL    = (!isFMA && (instr[31:27] == 5'b00010));
wire isFDIV    = (!isFMA && (instr[31:27] == 5'b00011));
wire isFSQRT   = (!isFMA && (instr[31:27] == 5'b01011));   

wire isFSGNJ   = (!isFMA && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b00));
wire isFSGNJN  = (!isFMA && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b01));
wire isFSGNJX  = (!isFMA && (instr[31:27]==5'b00100)&&(instr[13:12]==2'b10));

wire isFMIN    = (!isFMA && (instr[31:27] == 5'b00101) && !instr[12]);
wire isFMAX    = (!isFMA && (instr[31:27] == 5'b00101) &&  instr[12]);

wire isFEQ     = (!isFMA && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b10));
wire isFLT     = (!isFMA && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b01));
wire isFLE     = (!isFMA && (instr[31:27]==5'b10100) && (instr[13:12] == 2'b00));

wire isFCLASS  = (!isFMA && (instr[31:27] == 5'b11100) &&  instr[12]); 

wire isFCVTWS  = (!isFMA && (instr[31:27] == 5'b11000) && !instr[20]);
wire isFCVTWUS = (!isFMA && (instr[31:27] == 5'b11000) &&  instr[20]);

wire isFCVTSW  = (!isFMA && (instr[31:27] == 5'b11010) && !instr[20]);
wire isFCVTSWU = (!isFMA && (instr[31:27] == 5'b11010) &&  instr[20]);

wire isFMVXW   = (!isFMA && (instr[31:27] == 5'b11100) && !instr[12]);
wire isFMVWX   = (!isFMA && (instr[31:27] == 5'b11110));

endmodule

/******************************************************************************
 * FPU Normalization needs to detect the position of the first bit set 
 * in the A_frac register. It is easier to count the number of leading 
 * zeroes (CLZ for Count Leading Zeroes), as follows. See:
 * https://electronics.stackexchange.com/questions/196914/
 *    verilog-synthesize-high-speed-leading-zero-count */
module CLZ #(
        parameter W_IN = 64, // must be power of 2, >= 2
        parameter W_OUT = $clog2(W_IN)	     
) (
        input wire [W_IN-1:0]   in,
        output wire [W_OUT-1:0] out
);
generate
        if(W_IN == 2) begin
                assign out = !in[1];
        end else begin
                wire [W_OUT-2:0] half_count;
                wire [W_IN/2-1:0] lhs = in[W_IN/2 +: W_IN/2];
                wire [W_IN/2-1:0] rhs = in[0      +: W_IN/2];
                wire left_empty = ~|lhs;
                CLZ #(
                        .W_IN(W_IN/2)
                ) inner(
                        .in(left_empty ? rhs : lhs),
                        .out(half_count)		
                );
                assign out = {left_empty, half_count};
        end
endgenerate
endmodule 

