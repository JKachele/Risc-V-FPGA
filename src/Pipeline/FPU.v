/*************************************************
 *File----------FPU.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Wednesday Dec 03, 2025 19:09:22 UTC
 ************************************************/

// TODO: Handle Full IEEE-754 (Full rounding, Subnormals, NaN, Infinity)
module FPU (
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

// High res FP Registers for math opps
reg x_sign; reg signed [8:0] x_exp; reg signed [49:0] x_signi;
reg y_sign; reg signed [8:0] y_exp; reg signed [49:0] y_signi;

// Macro used to write to the X register with 32 bits
`define X {x_sign, x_exp[7:0], x_signi[46:24]}
assign fpuOut_o = `X;

// Single-precision FP Registers for internal use
reg a_sign; reg [7:0] a_exp; reg [23:0] a_signi;
reg b_sign; reg [7:0] b_exp; reg [23:0] b_signi;
reg c_sign; reg [7:0] c_exp; reg [23:0] c_signi;
reg d_sign; reg [7:0] d_exp; reg [23:0] d_signi;
reg e_sign; reg [7:0] e_exp; reg [23:0] e_signi;
/* NOTE: exp is biased by 127 and signi includes implied leading 1 */

// Macros for moving values in registers
`define FP_LD32(RD,VAL)\
        {RD``_sign, RD``_exp, RD``_signi[22:0]} <= VAL; RD``_signi[23] <= 1'b1

`define FP_LD(RD,sign,exp,signi)\
        {RD``_sign, RD``_exp, RD``_signi} <= {sign,exp,signi}

`define FP_MV(RD,RS)\
        {RD``_sign, RD``_exp, RD``_signi} <= {RS``_sign, RS``_exp, RS``_signi} 

// FPU Micro-instruction States
localparam FPMI_READY           =  0;
localparam FPMI_LOAD_XY         =  1;   // x <- a, y <- b
localparam FPMI_ADD_SWAP        =  2;   // if |x|>|y|, swap, negX if sign diff
localparam FPMI_ADD_SHIFT       =  3;   // Shift x to match y exp
localparam FPMI_ADD_ADD         =  4;   // x <- x + y
localparam FPMI_ADD_NORM        =  5;   // normalize x after add
localparam FPMI_LOAD_XY_MUL     =  6;   // x <- norm(a*b), y <- c
localparam FPMI_CMP             =  7;   // X <- test(x,y) (FLT, FLE, FEQ)
localparam FPMI_FP_TO_INT       =  8;   // x <- fpoint_to_int(A)
localparam FPMI_INT_TO_FP       =  9;   // x <- int_to_fpoint(x)
localparam FPMI_MIN_MAX         = 10;   // x <- min/max(x,y)
// localparam FPMI_TEST            = 10;

localparam FPMI_NUM_STATES = 11;
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
integer FPMPROG_ADD, FPMPROG_MUL, FPMPROG_MADD,
        FPMPROG_CMP, FPMPROG_MIN_MAX,
        FPMPROG_FP_TO_INT, FPMPROG_INT_TO_FP;

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

        /******** FLT, FLE, FEQ ********/
        FPMPROG_CMP = I;
        fpmi_gen(FPMI_LOAD_XY);
        fpmi_gen(FPMI_CMP | FPMI_EXIT_FLAG);

        /******** FCVT.W.S, FCVT.WU.S ********/
        FPMPROG_FP_TO_INT = I;
        fpmi_gen(FPMI_LOAD_XY);
        fpmi_gen(FPMI_FP_TO_INT | FPMI_EXIT_FLAG);

        /******** FCVT.S.W, FCVT.S.WU ********/
        FPMPROG_INT_TO_FP = I;
        fpmi_gen(FPMI_INT_TO_FP);
        fpmi_gen(FPMI_ADD_ADD); // Fake add to prepare normalization
        fpmi_gen(FPMI_ADD_NORM | FPMI_EXIT_FLAG);

        /******** FMIN, FMAX ********/
        FPMPROG_MIN_MAX = I;
        fpmi_gen(FPMI_LOAD_XY);
        fpmi_gen(FPMI_MIN_MAX | FPMI_EXIT_FLAG);
end

// Set procedure to run based off decoded instruction
reg [6:0] fpmprog;
always @(*) begin
        case(1'b1)
                isFADD  | isFSUB                        : fpmprog = FPMPROG_ADD[6:0];
                isFMUL                                  : fpmprog = FPMPROG_MUL[6:0];
                isFMADD | isFMSUB | isFMNADD | isFMNSUB : fpmprog = FPMPROG_MADD[6:0];
                isFLT   | isFLE   | isFEQ               : fpmprog = FPMPROG_CMP[6:0];
                isFMIN  | isFMAX                        : fpmprog = FPMPROG_MIN_MAX[6:0];
                default                                 : fpmprog = 0;
        endcase
end

// Micro Instruction State Machine
reg [6:0]         fpmi_PC;
reg [FPMI_BITS:0] fpmi_instr;
(* onehot *)
wire [FPMI_NUM_STATES-1:0] fpmi_is = 1 << fpmi_instr[FPMI_BITS-1:0];

initial fpmi_PC = 0;
initial fpmi_instr = FPMI_ROM[0];

assign busy_o = fpuEnable_i | ~fpmi_is[FPMI_READY];

wire [6:0] fpmi_next_PC =
        fpuEnable_i               ? fpmprog :
        fpmi_instr[FPMI_EXIT_BIT] ? 0       : fpmi_PC + 1;;

always @(posedge clk_i) begin
        fpmi_PC <= fpmi_next_PC;
        fpmi_instr <= FPMI_ROM[fpmi_next_PC];
end

always @(posedge clk_i) begin
        if (fpuEnable_i) begin
                // Load rs1-3 into a, b, and c registers. Flush subnormals to 0
                `FP_LD(a, rs1_i[31], rs1_i[30:23], (|rs1_i[30:23] ? {1'b1,rs1_i[22:0]} : 24'b0));
                `FP_LD(b, rs2_i[31], rs2_i[30:23], (|rs2_i[30:23] ? {1'b1,rs2_i[22:0]} : 24'b0));
                `FP_LD(c, rs3_i[31], rs3_i[30:23], (|rs3_i[30:23] ? {1'b1,rs3_i[22:0]} : 24'b0));

                // Store copy of rs1 in E without flushing
                `FP_LD32(e, rs1_i);

                // Single cycle instructions
                (* parallel_case *)
                case(1'b1)
                        isFSGNJ           : `X <= {           rs2_i[31], rs1_i[30:0]};
	                isFSGNJN          : `X <= {          !rs2_i[31], rs1_i[30:0]};
	                isFSGNJX          : `X <= { rs1_i[31]^rs2_i[31], rs1_i[30:0]};
                        isFCLASS          : `X <= fclass;
                        isFMVXW | isFMVWX : `X <= rs1_i;
                endcase
        end else if (busy_o) begin
                // Implementation of Micro Instructions
                (* parallel_case *)
                case (1'b1)
                        // x <- a, y <- b
                        fpmi_is[FPMI_LOAD_XY]: begin
                                x_sign  <= a_sign;
                                x_signi <= {2'b0, a_signi, 24'b0};
                                x_exp   <= {1'b0, a_exp};
                                y_sign  <= b_sign;
                                y_signi <= {2'b0, b_signi, 24'b0};
                                y_exp   <= {1'b0, b_exp};
                        end

                        // if |x|>|y|, swap, negX if sign diff
                        fpmi_is[FPMI_ADD_SWAP]: begin
                                if (fabsY_LT_fabsX) begin
                                        x_signi <= (x_sign ^ y_sign) ? -y_signi : y_signi;
                                        y_signi <= x_signi;
                                        x_exp  <= y_exp; 
                                        y_exp  <= x_exp;
                                        x_sign <= y_sign;
                                        y_sign <= x_sign;
                                end else if (x_sign ^ y_sign) begin
                                        x_signi <= -x_signi;
                                end
                        end

                        // Shift x to match y exp
                        fpmi_is[FPMI_ADD_SHIFT]: begin
                                x_signi <= x_signi >>> expDiff;
                                x_exp <= y_exp;
                        end

                        // x <- x + y
                        fpmi_is[FPMI_ADD_ADD]: begin
                                x_signi <= signiSum[49:0];
                                x_sign  <= y_sign;
                                // normalization left shamt = 47 - first_bit_set = clz - 16
                                normLshamt <= signiSumCLZ - 16;
                                // Exponent of X once normalized = X_exp + first_bit_set - 47
                                //                 = X_exp + 63 - clz - 47 = X_exp + 16 - clz
                                xExpNorm <= x_exp + 16 - {3'b000,signiSumCLZ};
                        end

                        // normalize x after add
                        fpmi_is[FPMI_ADD_NORM]: begin
                                if(xExpNorm <= 0 || (x_signi == 0)) begin
                                        x_signi <= 0;
                                        x_exp   <= 0;
                                end else begin
                                        x_signi <= x_signi[48] ? (x_signi >> 1) :
                                                x_signi << normLshamt;
                                        x_exp  <= xExpNorm;
                                end
                        end

                        // x <- norm(a*b), y <- c
                        fpmi_is[FPMI_LOAD_XY_MUL]: begin
                                x_sign <= a_sign ^ b_sign ^ (isFMNADD | isFMNSUB);
                                x_signi <= prod_Z ? 0 :
                                        (prod_signi[47] ? prod_signi : {prod_signi[48:0], 1'b0});
                                x_exp <= prod_Z ? 0 : prod_exp_norm;
                                y_sign <= c_sign ^ (isFMSUB | isFMNADD);
                                y_signi <= {2'b0, c_signi, 24'd0};
                                y_exp  <= {1'b0, c_exp};
                        end

                        fpmi_is[FPMI_CMP]: begin
                                `X <= {31'b0,
                                        (isFLT && X_LT_Y) ||
                                        (isFLE && X_LE_Y) ||
                                        (isFEQ && X_EQ_Y)};
                        end

                        fpmi_is[FPMI_FP_TO_INT]: begin
                                `X <= (isFCVTWUS | !x_sign) ?
                                        x_ftoiShiftd : -$signed(x_ftoiShiftd);
                        end

                        fpmi_is[FPMI_INT_TO_FP]: begin
                                x_signi <= 0;
                                x_exp <= 127+23+6;
                                y_signi <= (isFCVTSWU | !e_sign) ?
                                        {e_sign, e_exp, e_signi[22:0], 18'b0} :
                                        {-$signed({e_sign, e_exp, e_signi[22:0]}), 18'b0};
                                y_sign <= isFCVTSW & e_sign;
                        end

                        fpmi_is[FPMI_MIN_MAX]: begin
                                `X <= (X_LT_Y ^ isFMAX) ?
                                        {x_sign, x_exp[7:0], x_signi[46:24]} :
                                        {y_sign, y_exp[7:0], y_signi[46:24]};
                        end
                endcase
        end
end

/**************** Support Circuritry ****************/
/******** Add / Subtract ********/
wire signed [50:0] signiSum  = y_signi + x_signi;
wire signed [50:0] signiDiff = y_signi - x_signi;

wire signed [8:0] expSum  = y_exp + x_exp;
wire signed [8:0] expDiff = y_exp - x_exp;

/******** Multiply ********/
wire [49:0] prod_signi = a_signi * b_signi;

// exponent of product, once normalized
// (obtained by writing expression of product and inspecting exponent)
// Two cases: first bit set = 47 or 46 (only possible cases with normals)
wire signed [8:0] prod_exp_norm = a_exp+b_exp-127+{7'b0,prod_signi[47]};

// detect null product and underflows (all denormals are flushed to zero)
wire prod_Z = (prod_exp_norm <= 0) || !(|prod_signi[47:46]);

/******** Comparisons ********/
wire expEQ   = (expDiff == 0);          // X and Y exponents are equal
wire signiEQ = (signiDiff == 0);        // X and Y significands are equal
wire fabsEQ  = (expEQ & signiEQ);       // abs(X) and abs(Y) are equal

wire fabsX_LT_fabsY = (!expDiff[8] && !expEQ) || (expEQ && !signiEQ && !signiDiff[50]);
wire fabsX_LE_fabsY = (!expDiff[8] && !expEQ) || (expEQ && !signiDiff[50]);
wire fabsY_LT_fabsX = expDiff[8]              || (expEQ && signiDiff[50]);
wire fabsY_LE_fabsX = expDiff[8]              || (expEQ && (signiDiff[50] || signiEQ));

wire X_LT_Y = (x_sign  && !y_sign)                   ||
              (x_sign  && y_sign  && fabsY_LT_fabsX) ||
              (!x_sign && !y_sign && fabsX_LT_fabsY);
wire X_LE_Y = (x_sign  && !y_sign)                   ||
              (x_sign  && y_sign  && fabsY_LE_fabsX) ||
              (!x_sign && !y_sign && fabsX_LE_fabsY);
wire X_EQ_Y = fabsEQ && (x_sign == y_sign);

/******** Normalization ********/
wire       [5:0] signiSumCLZ;
reg        [5:0] normLshamt;
reg signed [8:0] xExpNorm;

CLZ clz ({13'b0,signiSum}, signiSumCLZ);

/******** Float to Integer conversion ********/
// Exponent bias = 127 and significand shift is 23.
// -6 because it is bit 29 of X that corresponds to bit 47 of X_frac,
// instead of bit 23 (and 23-29 = -6).
wire signed [8:0] ftoiShift = a_exp - 9'd127 - 9'd23 - 9'd6;
wire signed [8:0] negFtoiShift = -ftoiShift;

wire [31:0] x_ftoiShiftd = ftoiShift[8] ?
        (|negFtoiShift[8:5] ? 0 :
        ({x_signi[49:18]} >> negFtoiShift[4:0])) :
        ({x_signi[49:18]} << ftoiShift[4:0]);

/******** Classification ********/
wire rs1ExpZ   = (rs1_i[30:23] == 0);
wire rs1Exp255 = (rs1_i[30:23] == 255);
wire rs1SigniZ = (rs1_i[22:0]  == 0);

wire [31:0] fclass = {
        22'b0,
        rs1Exp255   &  rs1_i[22],                 // 9: quiet NaN
        rs1Exp255   & !rs1_i[22] & (|rs1_i[21:0]),// 8: sig NaN
        !rs1_i[31]  &  rs1Exp255 &  rs1SigniZ,    // 7: +infinity
        !rs1_i[31]  & !rs1ExpZ   & !rs1Exp255,    // 6: +normal
        !rs1_i[31]  &  rs1ExpZ   & !rs1SigniZ,    // 5: +subnormal
        !rs1_i[31]  &  rs1ExpZ   &  rs1SigniZ,    // 4: +0
        rs1_i[31]   &  rs1ExpZ   &  rs1SigniZ,    // 3: -0
        rs1_i[31]   &  rs1ExpZ   & !rs1SigniZ,    // 2: -subnormal
        rs1_i[31]   & !rs1ExpZ   & !rs1Exp255,    // 1: -normal
        rs1_i[31]   &  rs1Exp255 &  rs1SigniZ     // 0: -infinity
        };

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

