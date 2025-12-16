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

reg [31:0] out;
assign fpuOut_o = out;

// Decode floating point numbers
wire        [9:0]  rs1FullClass;
wire        [5:0]  rs1Class;
wire signed [9:0]  rs1Exp;
wire        [23:0] rs1Sig;
FClass class1(.reg_i(rs1_i), .regExp_o(rs1Exp), .regSig_o(rs1Sig),
        .class_o(rs1Class), .fullClass_o(rs1FullClass));
wire        [5:0]  rs2Class;
wire signed [9:0]  rs2Exp;
wire        [23:0] rs2Sig;
FClass class2(.reg_i(rs2_i), .regExp_o(rs2Exp), .regSig_o(rs2Sig),
        .class_o(rs2Class), .fullClass_o());
wire        [5:0]  rs3Class;
wire signed [9:0]  rs3Exp;
wire        [23:0] rs3Sig;
FClass class3(.reg_i(rs3_i), .regExp_o(rs3Exp), .regSig_o(rs3Sig),
        .class_o(rs3Class), .fullClass_o());

// Multiplication
wire [31:0] fmulOut;
// Keep unrounded output for FMA instructions
wire        [47:0] fmulSig;
wire signed [10:0] fmulExp;
wire        [5:0]  fmulClass;
FMUL fmul(
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .rs2_i(rs2_i),
        .rs2Exp_i(rs2Exp),
        .rs2Sig_i(rs2Sig),
        .rs2Class_i(rs2Class),
        .rm_i(3'b000),
        .fmulOut_o(fmulOut),
        .exp_o(fmulExp),
        .sig_o(fmulSig),
        .class_o(fmulClass)
);

// Comparisons
wire [2:0] fcmpOut; // {FLT, FLE, FEQ}
FCMP fcmp(
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .rs2_i(rs2_i),
        .rs2Exp_i(rs2Exp),
        .rs2Sig_i(rs2Sig),
        .rs2Class_i(rs2Class),
        .fcmp_o(fcmpOut)
);

// Int to FP
wire [31:0] fcvtOut;
wire [1:0] fcvtInstr = {(isFCVTWS | isFCVTWUS), (isFCVTSWU | isFCVTWUS)};
FCVT fcvt(
        .rs1_i(rs1_i),
        .rs1Exp_i(rs1Exp),
        .rs1Sig_i(rs1Sig),
        .rs1Class_i(rs1Class),
        .instr_i(fcvtInstr),
        .rm_i(3'b000),
        .fcvtOut_o(fcvtOut)
);

always @(*) begin
        busy_o = 1'b0;
        case (1'b1)
                // Move and convert
                isFSGNJ              : out = {           rs2_i[31], rs1_i[30:0]};
	        isFSGNJN             : out = {          !rs2_i[31], rs1_i[30:0]};
	        isFSGNJX             : out = { rs1_i[31]^rs2_i[31], rs1_i[30:0]};
                isFMVXW  | isFMVWX   : out = rs1_i;
                isFCVTSW | isFCVTSWU : out = fcvtOut;
                isFCVTWS | isFCVTWUS : out = fcvtOut;

                // Compare and classify
                isFEQ                : out = {31'b0, fcmpOut[0]};
                isFLE                : out = {31'b0, fcmpOut[1]};
                isFLT                : out = {31'b0, fcmpOut[2]};
                isFMAX   | isFMIN    : out = (fcmpOut[2] ^ isFMAX) ? rs1_i : rs2_i;
                isFCLASS             : out = {22'b0, rs1FullClass};

                isFMUL               : out = fmulOut;
                default              : out = 32'b0;
        endcase
end

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

