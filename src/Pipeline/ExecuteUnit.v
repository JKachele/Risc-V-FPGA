/*************************************************
 *File----------ExecuteUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 17:21:18 UTC
 ************************************************/
/* verilator lint_off WIDTH */

module ExecuteUnit (
        input  wire clk_i,
        input  wire reset_i,
        // Pipeline Control Signals
        input  wire        E_stall_i,
        input  wire        M_flush_i,
        input  wire        dataHazard_i,
        output wire        HALT_o,
        output wire        E_takeBranch_o,
        output wire        E_correctPC_o,
        output wire        aluBusy_o,
        // Register File Interface
        output wire [5:0]  rs1Id_o,
        output wire [5:0]  rs2Id_o,
        output wire [5:0]  rs3Id_o,
        input  wire [31:0] rs1Data_i,
        input  wire [31:0] rs2Data_i,
        input  wire [31:0] rs3Data_i,
        // FPU Rounding Modes
        input  wire [2:0]  csrFRM_i,
        // Memory Interface
        output wire [31:0] DMemRAddr_o,
        input  wire [31:0] DMemRData_i,
        // Register Forwarding
        input  wire        MW_wbEnable_i,
        input  wire [5:0]  MW_rdId_i,
        input  wire [31:0] MW_wbData_i,
        // Decode Unit Interface
        input  wire [31:0] DE_PC_i,
        input  wire [31:0] DE_instr_i,
        input  wire        DE_nop_i,
        input  wire        DE_isLUI_i,
        input  wire        DE_isAUIPC_i,
        input  wire        DE_isJAL_i,
        input  wire        DE_isJALR_i,
        input  wire        DE_isBranch_i,
        input  wire        DE_isLoad_i,
        input  wire        DE_isStore_i,
        input  wire        DE_isALUI_i,
        input  wire        DE_isALUR_i,
        input  wire        DE_isFENCE_i,
        input  wire        DE_isSYS_i,
        input  wire        DE_isEBREAK_i,
        input  wire        DE_isCSR_i,
        input  wire        DE_isFPU_i,
        input  wire [5:0]  DE_rdId_i,
        input  wire [5:0]  DE_rs1Id_i,
        input  wire [5:0]  DE_rs2Id_i,
        input  wire [5:0]  DE_rs3Id_i,
        input  wire [11:0] DE_csrId_i,
        input  wire [2:0]  DE_funct3_i,
        input  wire [7:0]  DE_funct3_is_i,
        input  wire [6:0]  DE_funct7_i,
        input  wire [31:0] DE_Iimm_i,
        input  wire [31:0] DE_Simm_i,
        input  wire [31:0] DE_Bimm_i,
        input  wire [31:0] DE_Uimm_i,
        input  wire        DE_isRV32M_i,
        input  wire        DE_isMUL_i,
        input  wire        DE_isDIV_i,
        input  wire        DE_wbEnable_i,
        input  wire        DE_predictBranch_i,
        input  wire [31:0] DE_predictRA_i,
        // Memory Unit Interface
        output reg  [31:0] EM_PC_o,
        output reg  [31:0] EM_instr_o,
        output reg         EM_nop_o,
        output reg         EM_isLoad_o,
        output reg         EM_isStore_o,
        output reg         EM_isCSR_o,
        output reg  [5:0]  EM_rdId_o,
        output reg  [5:0]  EM_rs1Id_o,
        output reg  [5:0]  EM_rs2Id_o,
        output reg  [11:0] EM_csrId_o,
        output reg  [31:0] EM_rs2_o,
        output reg  [2:0]  EM_funct3_o,
        output reg  [31:0] EM_Eresult_o,
        output reg  [31:0] EM_addr_o,
        output reg  [31:0] EM_Mdata_o,
        output reg         EM_correctPC_o,
        output reg  [31:0] EM_PCcorrection_o,
        output reg         EM_wbEnable_o
);
localparam NOP = 32'b0000000_00000_00000_000_00000_0110011;

/*---------------REGISTER FORWARDING--------------*/
// Forward from End of Execute Unit
wire EMfwd_rs1 = EM_wbEnable_o && (EM_rdId_o == DE_rs1Id_i);
wire EMfwd_rs2 = EM_wbEnable_o && (EM_rdId_o == DE_rs2Id_i);
wire EMfwd_rs3 = EM_wbEnable_o && (EM_rdId_o == DE_rs3Id_i);

// Forward from End of Memory Unit
wire EWfwd_rs1 = MW_wbEnable_i && (MW_rdId_i == DE_rs1Id_i);
wire EWfwd_rs2 = MW_wbEnable_i && (MW_rdId_i == DE_rs2Id_i);
wire EWfwd_rs3 = MW_wbEnable_i && (MW_rdId_i == DE_rs3Id_i);

assign rs1Id_o = DE_rs1Id_i;
assign rs2Id_o = DE_rs2Id_i;
assign rs3Id_o = DE_rs3Id_i;

wire [31:0] E_rs1 = EMfwd_rs1 ? EM_Eresult_o :
        EWfwd_rs1 ? MW_wbData_i : rs1Data_i;

wire [31:0] E_rs2 = EMfwd_rs2 ? EM_Eresult_o :
        EWfwd_rs2 ? MW_wbData_i : rs2Data_i;

wire [31:0] E_rs3 = EMfwd_rs3 ? EM_Eresult_o :
        EWfwd_rs3 ? MW_wbData_i : rs3Data_i;

/*---------------ADD/SUBTRACT/SHIFT---------------*/
wire [31:0] E_aluIn1 = E_rs1;
wire [31:0] E_aluIn2 =
        DE_isALUR_i | DE_isBranch_i ? E_rs2 : DE_Iimm_i;

// Add Subtract
wire E_isMinus = DE_funct7_i[5] & DE_isALUR_i;
wire [31:0] E_aluPlus = E_aluIn1 + E_aluIn2;
wire [32:0] E_aluMinus = {1'b0, E_aluIn1} + {1'b1, ~E_aluIn2} + 33'b1;

// Comparisons
wire E_LT  = (E_aluIn1[31] ^ E_aluIn2[31]) ? E_aluIn1[31] : E_aluMinus[32];
wire E_LTU = E_aluMinus[32];
wire E_EQ  = (E_aluMinus[31:0] == 0);

// Flip a 32 bit word. Used by the shifter
function [31:0] flip32;
        input [31:0] x;
        flip32 = {x[ 0], x[ 1], x[ 2], x[ 3], x[ 4], x[ 5], x[ 6], x[ 7],
                x[ 8], x[ 9], x[10], x[11], x[12], x[13], x[14], x[15],
                x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
                x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
endfunction

// Bit Shifts
wire E_arithShift = DE_funct7_i[5];
wire [31:0] E_shifterIn = 
        (DE_funct3_i == 3'b001) ? flip32(E_aluIn1) : E_aluIn1;
wire [31:0] E_shifter =
        $signed({E_arithShift & E_aluIn1[31], E_shifterIn}) >>> E_aluIn2[4:0];
wire [31:0] E_leftShift = flip32(E_shifter);

wire [31:0] E_aluOutBase = 
        (DE_funct3_is_i[0] ? (E_isMinus ? E_aluMinus[31:0] : E_aluPlus) : 32'b0) |
        (DE_funct3_is_i[1] ? E_leftShift                                : 32'b0) |
        (DE_funct3_is_i[2] ? {31'b0, E_LT}                              : 32'b0) |
        (DE_funct3_is_i[3] ? {31'b0, E_LTU}                             : 32'b0) |
        (DE_funct3_is_i[4] ? E_aluIn1 ^ E_aluIn2                        : 32'b0) |
        (DE_funct3_is_i[5] ? E_shifter                                  : 32'b0) |
        (DE_funct3_is_i[6] ? E_aluIn1 | E_aluIn2                        : 32'b0) |
        (DE_funct3_is_i[7] ? E_aluIn1 & E_aluIn2                        : 32'b0) ;

/*--------------------MULTIPLY--------------------*/
wire E_isMULH   = DE_funct3_is_i[1];
wire E_isMULHSU = DE_funct3_is_i[2];

wire E_mulSign1 = E_rs1[31] & E_isMULH;
wire E_mulSign2 = E_rs2[31] & (E_isMULH | E_isMULHSU);

wire signed [32:0] E_mulSigned1 = {E_mulSign1, E_rs1};
wire signed [32:0] E_mulSigned2 = {E_mulSign2, E_rs2};
wire signed [63:0] E_multiply   = E_mulSigned1 * E_mulSigned2;

/*---------------------DIVIDE---------------------*/
reg [31:0] EE_dividend;
reg [62:0] EE_divisor;
reg [31:0] EE_quotient;
reg [31:0] EE_quotientMsk;

reg EE_divSign;
reg EE_divBusy     = 1'b0;
reg EE_divFinished = 1'b0;

wire E_divstepDo = (EE_divisor <= {31'b0, EE_dividend});

always @(posedge clk_i) begin
        if (!EE_divBusy) begin
                if (DE_isDIV_i & !dataHazard_i & !EE_divFinished) begin
                        EE_quotientMsk <= 1 << 31;
                        EE_divBusy <= 1'b1;
                end
                EE_dividend <= ~DE_funct3_i[0] & E_rs1[31] ? -E_rs1 : E_rs1;
                EE_divisor <=
                        {(~DE_funct3_i[0] & E_rs2[31] ? -E_rs2 : E_rs2), 31'b0};
                EE_quotient <= 0;
                EE_divSign <= ~DE_funct3_i[0] & (DE_funct3_i[1] ? E_rs1[31] :
                        (E_rs1[31] != E_rs2[31]) & |E_rs2);
        end else begin
                EE_dividend <= E_divstepDo ? EE_dividend - EE_divisor[31:0] :
                                             EE_dividend;
                EE_divisor <= EE_divisor >> 1;
                EE_quotient <= E_divstepDo ? EE_quotient | EE_quotientMsk :
                                             EE_quotient;
                EE_quotientMsk <=EE_quotientMsk >> 1;
                EE_divBusy <= EE_divBusy & !EE_quotientMsk[0];
        end
        EE_divFinished <= EE_quotientMsk[0];
end

wire [2:0] E_divsel = {DE_isDIV_i, DE_funct3_i[1], EE_divSign};

wire [31:0] E_aluOutM = 
        (  DE_funct3_is_i[0]    ?  E_multiply[31:0]  : 32'b0) | // MUL
        ( |DE_funct3_is_i[3:1]  ?  E_multiply[63:32] : 32'b0) | // MULH[[S]U]
        (  E_divsel == 3'b100 ?  EE_quotient       : 32'b0) | // DIV
        (  E_divsel == 3'b101 ? -EE_quotient       : 32'b0) | // DIV Negative
        (  E_divsel == 3'b110 ?  EE_dividend       : 32'b0) | // REM
        (  E_divsel == 3'b111 ? -EE_dividend       : 32'b0) ; // REM Negative

/*----------------------FPU-----------------------*/
wire E_fpuBusy;
wire [2:0] E_fpuRound = (&DE_funct3_i) ? csrFRM_i : DE_funct3_i;
wire [31:0] E_fpuOut;
FPU fpu(
        .clk_i(clk_i),
        .reset_i(reset_i),
        .fpuEnable_i(DE_isFPU_i),
        .instr_i(DE_instr_i),
        .rs1_i(E_rs1),
        .rs2_i(E_rs2),
        .rs3_i(E_rs3),
        .rm_i(E_fpuRound),
        .busy_o(E_fpuBusy),
        .fpuOut_o(E_fpuOut)
);

wire [31:0] E_aluOut = DE_isRV32M_i ? E_aluOutM : 
                       DE_isFPU_i   ? E_fpuOut  : E_aluOutBase;

assign aluBusy_o = EE_divBusy | (DE_isDIV_i & !EE_divFinished) | E_fpuBusy;

/*------------------JUMP/BRANCH-------------------*/
wire E_takeBranch = 
        (DE_funct3_is_i[0] &  E_EQ ) | // BEQ
        (DE_funct3_is_i[1] & !E_EQ ) | // BNE
        (DE_funct3_is_i[4] &  E_LT ) | // BLT
        (DE_funct3_is_i[5] & !E_LT ) | // BGE
        (DE_funct3_is_i[6] &  E_LTU) | // BLTU
        (DE_funct3_is_i[7] & !E_LTU) ; // BGEU
assign E_takeBranch_o = E_takeBranch;

wire [31:0] E_JALRaddr/*verilator public_flat_rw*/;
assign E_JALRaddr = {E_aluPlus[31:1],1'b0};

wire E_correctPC = (
        (DE_isJALR_i    && (DE_predictRA_i != E_JALRaddr)   ) ||
        (DE_isBranch_i  && (E_takeBranch^DE_predictBranch_i))
);
assign E_correctPC_o = E_correctPC;

wire [31:0] E_PCcorrection = 
        DE_isBranch_i ? DE_PC_i + (DE_predictBranch_i ? 4 : DE_Bimm_i) :
        /* JALR */                                 E_JALRaddr;

wire [31:0] E_result = 
        (DE_isJAL_i | DE_isJALR_i) ? DE_PC_i + 4              :
        DE_isLUI_i                      ? DE_Uimm_i         :
        DE_isAUIPC_i                    ? DE_PC_i + DE_Uimm_i :
        /* ALU OP */                           E_aluOut ;

/*------------------------------------------------*/
// Memory access address
wire [31:0] E_addr =
        DE_isStore_i ? E_rs1 + DE_Simm_i : E_rs1 + DE_Iimm_i;
assign DMemRAddr_o = E_addr;

always @(posedge clk_i) begin
        if (!E_stall_i) begin
                EM_PC_o <= DE_PC_i;
                EM_instr_o <= DE_instr_i;
                EM_nop_o <= DE_nop_i;

                EM_isLoad_o <= DE_isLoad_i;
                EM_isStore_o <= DE_isStore_i;
                EM_isCSR_o <= DE_isCSR_i;
                EM_rdId_o <= DE_rdId_i;
                EM_rs1Id_o <= DE_rs1Id_i;
                EM_rs2Id_o <= DE_rs2Id_i;
                EM_csrId_o <= DE_csrId_i;
                EM_funct3_o <= DE_funct3_i;
                EM_rs2_o <= E_rs2;
                EM_Eresult_o <= E_result;
                EM_addr_o <= E_addr;
                EM_Mdata_o <= DMemRData_i;
                EM_correctPC_o <= E_correctPC;
                EM_PCcorrection_o <= E_PCcorrection;
                EM_wbEnable_o <= DE_wbEnable_i && (DE_rdId_i != 0);
        end

        if (M_flush_i) begin
                EM_instr_o     <= NOP;
                EM_nop_o       <= 1'b1;
                EM_isLoad_o    <= 1'b0;
                EM_isStore_o   <= 1'b0;
                EM_isCSR_o     <= 1'b0;
                EM_correctPC_o <= 1'b0;
                EM_wbEnable_o  <= 1'b0;
        end
end

assign HALT_o = (!reset_i && DE_isEBREAK_i);

endmodule
/* verilator lint_on WIDTH */

