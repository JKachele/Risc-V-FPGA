/*************************************************
 *File----------FPU2.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 17:36:54 UTC
 ************************************************/

module FPU (
        input  wire        clk_i,
        input  wire        reset_i,

        input  wire        fpuEnable_i,
        input  wire [31:0] instr_i,
        input  wire [63:0] rs1_i,
        input  wire [63:0] rs2_i,
        input  wire [63:0] rs3_i,
        input  wire [2:0]  rm_i,
        output wire [4:0]  fflags_o,

        output wire        busy_o,
        output wire [63:0] fpuOut_o
);

reg [31:0] out_s;
reg [63:0] out_d;
assign fpuOut_o = isRV32D ? out_d : {{32{1'b1}}, out_s};
assign busy_o = fpuEnable_i & ((isFDIV_S & ~fdivReady)   | (isFSQRT_S & ~fsqrtReady) | 
                               (isFDIV_D & ~fdivReady_d));

reg [4:0] fflags = 0;
assign fflags_o = fflags;

wire [31:0] rs1_s = rs1_i[31:0];
wire [31:0] rs2_s = rs2_i[31:0];
wire [31:0] rs3_s = rs3_i[31:0];

// Decode floating point numbers
wire        [9:0]  rs1FullClass;
wire        [5:0]  rs1Class;
wire signed [9:0]  rs1Exp;
wire        [23:0] rs1Sig;
FClass class1(.reg_i(rs1_s), .regExp_o(rs1Exp), .regSig_o(rs1Sig),
        .class_o(rs1Class), .fullClass_o(rs1FullClass));
wire        [5:0]  rs2Class;
wire signed [9:0]  rs2Exp;
wire        [23:0] rs2Sig;
FClass class2(.reg_i(rs2_s), .regExp_o(rs2Exp), .regSig_o(rs2Sig),
        .class_o(rs2Class), .fullClass_o());
wire        [5:0]  rs3Class;
wire signed [9:0]  rs3Exp;
wire        [23:0] rs3Sig;
FClass class3(.reg_i(rs3_s), .regExp_o(rs3Exp), .regSig_o(rs3Sig),
        .class_o(rs3Class), .fullClass_o());

// Multiplication
wire [31:0] fmulOut;
// Keep unrounded output for FMA instructions
wire        [47:0] fmulSig;
wire signed [10:0] fmulExp;
wire        [5:0]  fmulClass;
FMUL fmul(
        .rs1_i(rs1_s),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .rs2_i(rs2_s),
        .rs2Exp_i(rs2Exp),
        .rs2Sig_i(rs2Sig),
        .rs2Class_i(rs2Class),
        .rm_i(rm_i),
        .fmulOut_o(fmulOut),
        .exp_o(fmulExp),
        .sig_o(fmulSig),
        .class_o(fmulClass)
);

// Addition / Subtraction
// Need to Determine what inputs to use and negate the second one if subtracting
// rs1 + rs2 for add/sub and mulOut + rs3 for madd/msub
reg        [31:0] addRs1;
reg        [47:0] addRs1Sig;
reg signed [10:0] addRs1Exp;
reg        [5:0]  addRs1Class;
reg        [31:0] addRs2;
reg        [47:0] addRs2Sig;
reg signed [10:0] addRs2Exp;
reg        [5:0]  addRs2Class;

always @(*) begin
        if (isFMA) begin
                addRs1      = (isFNMADD || isFNMSUB) ? {~fmulOut[31], fmulOut[30:0]} : fmulOut;
                addRs1Sig   = fmulSig;
                addRs1Exp   = fmulExp;
                addRs1Class = fmulClass;

                addRs2      = (isFNMADD || isFMSUB) ? {~rs3_s[31], rs3_s[30:0]} : rs3_s;
                addRs2Sig   = {rs3Sig, 24'b0};
                addRs2Exp   = {rs3Exp[9], rs3Exp};
                addRs2Class = rs3Class;
        end else begin
                addRs1      = rs1_s;
                addRs1Sig   = {rs1Sig, 24'b0};
                addRs1Exp   = {rs1Exp[9], rs1Exp};
                addRs1Class = rs1Class;

                addRs2      = (isFSUB_S) ? {~rs2_s[31], rs2_s[30:0]} : rs2_s;
                addRs2Sig   = {rs2Sig, 24'b0};
                addRs2Exp   = {rs2Exp[9], rs2Exp};
                addRs2Class = rs2Class;
        end
end

wire [31:0] faddOut;
FADDd fadd(
        .rs1_i(addRs1),
        .rs1Exp_i(addRs1Exp),
        .rs1Sig_i(addRs1Sig),
        .rs1Class_i(addRs1Class),
        .rs2_i(addRs2),
        .rs2Exp_i(addRs2Exp),
        .rs2Sig_i(addRs2Sig),
        .rs2Class_i(addRs2Class),
        .rm_i(rm_i),
        .faddOut_o(faddOut)
);

// Division
wire [31:0] fdivOut;
wire        fdivReady;
FDIV fdiv(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .divEnable_i(fpuEnable_i & isFDIV_S),
        .rs1_i(rs1_s),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .rs2_i(rs2_s),
        .rs2Exp_i(rs2Exp),
        .rs2Sig_i(rs2Sig),
        .rs2Class_i(rs2Class),
        .rm_i(rm_i),
        .ready_o(fdivReady),
        .fdivOut_o(fdivOut)
);

// Square Root
wire [31:0] fsqrtOut;
wire        fsqrtReady;
FSQRT fsqrt(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .sqrtEnable_i(fpuEnable_i & isFSQRT_S),
        .rs1_i(rs1_s),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .rm_i(rm_i),
        .ready_o(fsqrtReady),
        .fsqrtOut_o(fsqrtOut)
);

// Comparisons
wire [2:0] fcmpOut; // {FLT, FLE, FEQ}
FCMP fcmp(
        .rs1_i(rs1_s),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .rs2_i(rs2_s),
        .rs2Exp_i(rs2Exp),
        .rs2Sig_i(rs2Sig),
        .rs2Class_i(rs2Class),
        .fcmp_o(fcmpOut)
);

// Int-Float Conversion
wire [31:0] fcvtOut;
wire [1:0] fcvtInstr = {(isFCVTWS | isFCVTWUS), (isFCVTSWU | isFCVTWUS)};
FCVT fcvt(
        .rs1_i(rs1_s),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .instr_i(fcvtInstr),
        .rm_i(3'b001),
        .fcvtOut_o(fcvtOut)
);


/************************ Double Precision ************************/
wire        [9:0]  rs1FullClass_d;
wire        [5:0]  rs1Class_d;
wire signed [12:0]  rs1Exp_d;
wire        [52:0] rs1Sig_d;
FClass #(.FLen(64), .SigLen(52), .ExpLen(11)
)class1_d(.reg_i(rs1_i), .regExp_o(rs1Exp_d), .regSig_o(rs1Sig_d),
        .class_o(rs1Class_d), .fullClass_o(rs1FullClass_d));
wire        [5:0]  rs2Class_d;
wire signed [12:0]  rs2Exp_d;
wire        [52:0] rs2Sig_d;
FClass #(.FLen(64), .SigLen(52), .ExpLen(11)
)class2_d(.reg_i(rs2_i), .regExp_o(rs2Exp_d), .regSig_o(rs2Sig_d),
        .class_o(rs2Class_d), .fullClass_o());
wire        [5:0]  rs3Class_d;
wire signed [12:0]  rs3Exp_d;
wire        [52:0] rs3Sig_d;
FClass #(.FLen(64), .SigLen(52), .ExpLen(11)
)class3_d(.reg_i(rs3_i), .regExp_o(rs3Exp_d), .regSig_o(rs3Sig_d),
        .class_o(rs3Class_d), .fullClass_o());

// Multiplication
wire [63:0] fmulOut_d;
// Keep unrounded output for FMA instructions
wire        [105:0] fmulSig_d;
wire signed [13:0] fmulExp_d;
wire        [5:0]  fmulClass_d;
FMUL #(
        .FLEN(64)
)fmul_d(
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp_d),
        .rs1Sig_i(rs1Sig_d),
        .rs1Class_i(rs1Class_d),
        .rs2_i(rs2_i),
        .rs2Exp_i(rs2Exp_d),
        .rs2Sig_i(rs2Sig_d),
        .rs2Class_i(rs2Class_d),
        .rm_i(rm_i),
        .fmulOut_o(fmulOut_d),
        .exp_o(fmulExp_d),
        .sig_o(fmulSig_d),
        .class_o(fmulClass_d)
);

// Addition / Subtraction
// Need to Determine what inputs to use and negate the second one if subtracting
// rs1 + rs2 for add/sub and mulOut + rs3 for madd/msub
reg        [63:0]  addRs1_d;
reg        [105:0] addRs1Sig_d;
reg signed [13:0]  addRs1Exp_d;
reg        [5:0]   addRs1Class_d;
reg        [63:0]  addRs2_d;
reg        [105:0] addRs2Sig_d;
reg signed [13:0]  addRs2Exp_d;
reg        [5:0]   addRs2Class_d;

always @(*) begin
        if (isFMA) begin
                addRs1_d      = (isFNMADD || isFNMSUB) ? {~fmulOut_d[63], fmulOut_d[62:0]} : fmulOut_d;
                addRs1Sig_d   = fmulSig_d;
                addRs1Exp_d   = fmulExp_d;
                addRs1Class_d = fmulClass_d;

                addRs2_d      = (isFNMADD || isFMSUB) ? {~rs3_i[63], rs3_i[62:0]} : rs3_i;
                addRs2Sig_d   = {rs3Sig_d, 53'b0};
                addRs2Exp_d   = {rs3Exp_d[9], rs3Exp_d};
                addRs2Class_d = rs3Class_d;
        end else begin
                addRs1_d      = rs1_i;
                addRs1Sig_d   = {rs1Sig_d, 53'b0};
                addRs1Exp_d   = {rs1Exp_d[12], rs1Exp_d};
                addRs1Class_d = rs1Class_d;

                addRs2_d      = (isFSUB_D) ? {~rs2_i[63], rs2_i[62:0]} : rs2_i;
                addRs2Sig_d   = {rs2Sig_d, 53'b0};
                addRs2Exp_d   = {rs2Exp_d[12], rs2Exp_d};
                addRs2Class_d = rs2Class_d;
        end
end

wire [63:0] faddOut_d;
FADDd #(
        .FLEN(64)
)fadd_d(
        .rs1_i(addRs1_d),
        .rs1Exp_i(addRs1Exp_d),
        .rs1Sig_i(addRs1Sig_d),
        .rs1Class_i(addRs1Class_d),
        .rs2_i(addRs2_d),
        .rs2Exp_i(addRs2Exp_d),
        .rs2Sig_i(addRs2Sig_d),
        .rs2Class_i(addRs2Class_d),
        .rm_i(rm_i),
        .faddOut_o(faddOut_d)
);

// Division
wire [63:0] fdivOut_d;
wire        fdivReady_d;
FDIV #(
        .FLEN(64)
)fdiv_d(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .divEnable_i(fpuEnable_i & isFDIV_D),
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp_d),
        .rs1Sig_i(rs1Sig_d),
        .rs1Class_i(rs1Class_d),
        .rs2_i(rs2_i),
        .rs2Exp_i(rs2Exp_d),
        .rs2Sig_i(rs2Sig_d),
        .rs2Class_i(rs2Class_d),
        .rm_i(rm_i),
        .ready_o(fdivReady_d),
        .fdivOut_o(fdivOut_d)
);

// Comparisons
wire [2:0] fcmpOut_d; // {FLT, FLE, FEQ}
FCMP #(
        .FLEN(64)
)fcmp_d(
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp_d),
        .rs1Sig_i(rs1Sig_d),
        .rs1Class_i(rs1Class_d),
        .rs2_i(rs2_i),
        .rs2Exp_i(rs2Exp_d),
        .rs2Sig_i(rs2Sig_d),
        .rs2Class_i(rs2Class_d),
        .fcmp_o(fcmpOut_d)
);

// Int-Double Conversion
wire [63:0] fcvtOut_d;
wire [1:0] fcvtInstr_d = {(isFCVTWD | isFCVTWUD), (isFCVTDWU | isFCVTWUD)};
FCVTD fcvt_d(
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp_d),
        .rs1Sig_i(rs1Sig_d),
        .rs1Class_i(rs1Class_d),
        .instr_i(fcvtInstr_d),
        .rm_i(rm_i),
        .fcvtOut_o(fcvtOut_d)
);

// Float-Double Conversion
wire [31:0] fcvtOut_sd;
FCVTSD fcvt_sd(
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp_d),
        .rs1Sig_i(rs1Sig_d),
        .rs1Class_i(rs1Class_d),
        .rm_i(rm_i),
        .fcvtOut_o(fcvtOut_sd)
);

wire [63:0] fcvtOut_ds;
FCVTDS fcvt_ds(
        .rs1_i(rs1_i),
        .fcvtOut_o(fcvtOut_ds),
        .exp_o(),
        .sig_o(),
        .class_o(),
        .fullClass_o()
);

/************************ Instruction Decoding ************************/
always @(*) begin
        case (1'b1)
                /******** Single Precision ********/
                // Move and convert
                isFSGNJ_S                : out_s = {           rs2_s[31], rs1_s[30:0]};
	        isFSGNJN_S               : out_s = {          !rs2_s[31], rs1_s[30:0]};
	        isFSGNJX_S               : out_s = { rs1_s[31]^rs2_s[31], rs1_s[30:0]};
                isFMVXW  | isFMVWX       : out_s = rs1_s;
                isFCVTSW | isFCVTSWU     : out_s = fcvtOut;
                isFCVTWS | isFCVTWUS     : out_s = fcvtOut;

                // Compare and classify
                isFEQ_S                  : out_s = {31'b0, fcmpOut[0]};
                isFLE_S                  : out_s = {31'b0, fcmpOut[1]};
                isFLT_S                  : out_s = {31'b0, fcmpOut[2]};
                isFMAX_S | isFMIN_S      : out_s = (fcmpOut[2] ^ isFMAX) ? rs1_s : rs2_s;
                isFCLASS_S               : out_s = {22'b0, rs1FullClass};

                // Computations
                isFMUL_S                 : out_s = fmulOut;
                isFADD_S   | isFSUB_S    : out_s = faddOut;
                isFMADD_S  | isFMSUB_S   : out_s = faddOut;
                isFNMADD_S | isFNMSUB_S  : out_s = faddOut;
                isFDIV_S                 : out_s = fdivOut;
                isFSQRT_S                : out_s = fsqrtOut;

                /******** Double Precision ********/
                // Move and convert
                isFSGNJ_D                : out_d = {           rs2_i[63], rs1_i[62:0]};
	        isFSGNJN_D               : out_d = {          !rs2_i[63], rs1_i[62:0]};
	        isFSGNJX_D               : out_d = { rs1_i[63]^rs2_i[63], rs1_i[62:0]};
                isFCVTSD                 : out_s = fcvtOut_sd;
                isFCVTDS                 : out_d = fcvtOut_ds;
                isFCVTDW | isFCVTDWU     : out_d = fcvtOut_d;
                isFCVTWD | isFCVTWUD     : out_d = fcvtOut_d;

                // Compare and classify
                isFEQ_D                  : out_d = {63'b0, fcmpOut_d[0]};
                isFLE_D                  : out_d = {63'b0, fcmpOut_d[1]};
                isFLT_D                  : out_d = {63'b0, fcmpOut_d[2]};
                isFMAX_D | isFMIN_D      : out_d = (fcmpOut_d[2] ^ isFMAX_D) ? rs1_i : rs2_i;
                isFCLASS_D               : out_d = {54'b0, rs1FullClass_d};

                // Computations
                isFMUL_D                 : out_d = fmulOut_d;
                isFADD_D   | isFSUB_D    : out_d = faddOut_d;
                isFMADD_D  | isFMSUB_D   : out_d = faddOut_d;
                isFNMADD_D | isFNMSUB_D  : out_d = faddOut_d;
                isFDIV_D                 : out_d = fdivOut_d;
                // isFSQRT_D                : out_d = fsqrtOut_d;
                default                  : out_d = 0;
        endcase
end

/**************** RV32F Instruction Decoder ****************/
wire isRV32D    = instr_i[25];
/******** Fused Multiply-Add ********/
wire isFMA      = !instr_i[4];
wire isFMADD    = (instr_i[4:2] == 3'b000);
wire isFMSUB    = (instr_i[4:2] == 3'b001);
wire isFNMSUB   = (instr_i[4:2] == 3'b010);
wire isFNMADD   = (instr_i[4:2] == 3'b011);

wire isFMADD_S  = isFMADD  && !isRV32D;
wire isFMSUB_S  = isFMSUB  && !isRV32D;
wire isFNMSUB_S = isFNMSUB && !isRV32D;
wire isFNMADD_S = isFNMADD && !isRV32D;
wire isFMADD_D  = isFMADD  &&  isRV32D;
wire isFMSUB_D  = isFMSUB  &&  isRV32D;
wire isFNMSUB_D = isFNMSUB &&  isRV32D;
wire isFNMADD_D = isFNMADD &&  isRV32D;

/******** Computational Instructions ********/
wire isFADD     = (!isFMA && (instr_i[31:27] == 5'b00000));
wire isFSUB     = (!isFMA && (instr_i[31:27] == 5'b00001));
wire isFMUL     = (!isFMA && (instr_i[31:27] == 5'b00010));
wire isFDIV     = (!isFMA && (instr_i[31:27] == 5'b00011));
wire isFSQRT    = (!isFMA && (instr_i[31:27] == 5'b01011));   

wire isFADD_S   = isFADD  && !isRV32D;
wire isFSUB_S   = isFSUB  && !isRV32D;
wire isFMUL_S   = isFMUL  && !isRV32D;
wire isFDIV_S   = isFDIV  && !isRV32D;
wire isFSQRT_S  = isFSQRT && !isRV32D;
wire isFADD_D   = isFADD  &&  isRV32D;
wire isFSUB_D   = isFSUB  &&  isRV32D;
wire isFMUL_D   = isFMUL  &&  isRV32D;
wire isFDIV_D   = isFDIV  &&  isRV32D;
wire isFSQRT_D  = isFSQRT &&  isRV32D;

/******** Sign Injection Instructions ********/
wire isFSGNJ    = (!isFMA && (instr_i[31:27]==5'b00100)&&(instr_i[13:12]==2'b00));
wire isFSGNJN   = (!isFMA && (instr_i[31:27]==5'b00100)&&(instr_i[13:12]==2'b01));
wire isFSGNJX   = (!isFMA && (instr_i[31:27]==5'b00100)&&(instr_i[13:12]==2'b10));

wire isFSGNJ_S  = isFSGNJ  && !isRV32D;
wire isFSGNJN_S = isFSGNJN && !isRV32D;
wire isFSGNJX_S = isFSGNJX && !isRV32D;
wire isFSGNJ_D  = isFSGNJ  &&  isRV32D;
wire isFSGNJN_D = isFSGNJN &&  isRV32D;
wire isFSGNJX_D = isFSGNJX &&  isRV32D;

/******** Comparison Instructions ********/
wire isFMIN     = (!isFMA && (instr_i[31:27] == 5'b00101) && !instr_i[12]);
wire isFMAX     = (!isFMA && (instr_i[31:27] == 5'b00101) &&  instr_i[12]);
wire isFEQ      = (!isFMA && (instr_i[31:27]==5'b10100)   && (instr_i[13:12] == 2'b10));
wire isFLT      = (!isFMA && (instr_i[31:27]==5'b10100)   && (instr_i[13:12] == 2'b01));
wire isFLE      = (!isFMA && (instr_i[31:27]==5'b10100)   && (instr_i[13:12] == 2'b00));
wire isFCLASS   = (!isFMA && (instr_i[31:27] == 5'b11100) &&  instr_i[12]); 

wire isFMIN_S   = isFMIN   && !isRV32D;
wire isFMAX_S   = isFMAX   && !isRV32D;
wire isFEQ_S    = isFEQ    && !isRV32D;
wire isFLT_S    = isFLT    && !isRV32D;
wire isFLE_S    = isFLE    && !isRV32D;
wire isFCLASS_S = isFCLASS && !isRV32D;
wire isFMIN_D   = isFMIN   &&  isRV32D;
wire isFMAX_D   = isFMAX   &&  isRV32D;
wire isFEQ_D    = isFEQ    &&  isRV32D;
wire isFLT_D    = isFLT    &&  isRV32D;
wire isFLE_D    = isFLE    &&  isRV32D;
wire isFCLASS_D = isFCLASS &&  isRV32D;

/******** Convert/Move Instructions ********/
wire isFCVTWS   = (!isFMA && (instr_i[31:27] == 5'b11000) && !instr_i[20] && !isRV32D);
wire isFCVTWUS  = (!isFMA && (instr_i[31:27] == 5'b11000) &&  instr_i[20] && !isRV32D);
wire isFCVTWD   = (!isFMA && (instr_i[31:27] == 5'b11000) && !instr_i[20] &&  isRV32D);
wire isFCVTWUD  = (!isFMA && (instr_i[31:27] == 5'b11000) &&  instr_i[20] &&  isRV32D);

wire isFCVTSW   = (!isFMA && (instr_i[31:27] == 5'b11010) && !instr_i[20] && !isRV32D);
wire isFCVTSWU  = (!isFMA && (instr_i[31:27] == 5'b11010) &&  instr_i[20] && !isRV32D);
wire isFCVTDW   = (!isFMA && (instr_i[31:27] == 5'b11010) && !instr_i[20] &&  isRV32D);
wire isFCVTDWU  = (!isFMA && (instr_i[31:27] == 5'b11010) &&  instr_i[20] &&  isRV32D);

wire isFCVTSD   = (!isFMA && (instr_i[31:27] == 5'b01000) &&  instr_i[20] && !isRV32D); 
wire isFCVTDS   = (!isFMA && (instr_i[31:27] == 5'b01000) && !instr_i[20] &&  isRV32D); 

wire isFMVXW    = (!isFMA && (instr_i[31:27] == 5'b11100) && !instr_i[12]);
wire isFMVWX    = (!isFMA && (instr_i[31:27] == 5'b11110));
endmodule

