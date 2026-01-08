/*************************************************
 *File----------CSR_RegFile.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 24, 2025 20:27:50 UTC
 ************************************************/

module CSR_RegFile (
        input  wire        clk_i,
        input  wire        reset_i,
        // Write
        input  wire [11:0] csrWAddr_i,
        input  wire [31:0] csrWData_i,
        input  wire        csrWEnable_i,
        //Read
        input  wire [11:0] csrRAddr_i,
        output wire [31:0] csrRData_o,
        // Instret update
        input wire         csrInstStep_i,
        // FPU Rounding Mode and flags
        input  wire [4:0]  csrFFlagsSet_i,
        output wire [2:0]  csrFRM_o,
        // Machine Mode CSRs
        output wire [63:0] csrMStatus_o,
        output wire [63:0] csrMedeleg_o,
        output wire [31:0] csrMideleg_o,
        output wire [31:0] csrMtvec_o,
        output wire [31:0] csrMepc_o,
        output wire [31:0] csrMCause_o,
        // Supervisor Mode CSRs
        output wire [31:0] csrStvec_o,
        output wire [31:0] csrSepc_o,
        output wire [31:0] csrSCause_o,
        // Set Trap CSRs
        input  wire [6:0]  csrMStatusSet_i, // {MPP[1:0], MPIE, MIE, SPP, SPIE, SIE}
        input  wire [31:0] csrMepcSet_i,
        input  wire [31:0] csrMCauseSet_i,
        input  wire [31:0] csrSepcSet_i,
        input  wire [31:0] csrSCauseSet_i,
        input  wire        csrTrapSetEn_i,
        // Privilege Level
        output wire [1:0]  privilege_o,
        input  wire [1:0]  privilegeSet_i,
        input  wire        privilegeSetEn_i
);

// Counters
reg [63:0] CSR_cycle = 0;   // 0xC00 / 0xC80 ([31:0] / [63:32])
reg [63:0] CSR_instret = 0; // 0xC02 / 0xC82 ([31:0] / [63:32]) 

// Floating Point Extension
reg [31:0] CSR_fcsr = 0;    // 0x001 - 0x003 (fflags, frm, fcsr)

// Machine Mode CSRs
reg [31:0] CSR_mstatus  = 0;
reg [31:0] CSR_mstatush = 0;
reg [63:0] CSR_medeleg  = 0;
reg [31:0] CSR_mideleg  = 0;
reg [31:0] CSR_mtvec    = 0;
reg [31:0] CSR_mepc     = 0;
reg [31:0] CSR_mcause   = 0;

// Supervisor Mode CSRs
// sstatus CSR is subset of mstatus CSR
reg [31:0] CSR_stvec    = 0;
reg [31:0] CSR_sepc     = 0;
reg [31:0] CSR_scause   = 0;

// Register IDs
localparam CYCLE_ID      = 12'hC00;
localparam CYCLEH_ID     = 12'hC80;
localparam INSTRET_ID    = 12'hC02;
localparam INSTRETH_ID   = 12'hC82;

localparam FFLAGS_ID     = 12'h001;
localparam FRM_ID        = 12'h002;
localparam FCSR_ID       = 12'h003;
localparam FFLAGS_MASK   = 32'h0000001F;
localparam FRM_MASK      = 32'h000000E0;
localparam FCSR_MASK     = 32'h000000FF;

localparam MSTATUS_ID    = 12'h300;
localparam MSTATUSH_ID   = 12'h310;
localparam MEDELEG_ID    = 12'h302;
localparam MEDELEGH_ID   = 12'h312;
localparam MIDELEG_ID    = 12'h303;
localparam MTVEC_ID      = 12'h305;
localparam MEPC_ID       = 12'h341;
localparam MCAUSE_ID     = 12'h342;
localparam MSTATUS_MASK  = 32'h81FFFFEA;
localparam MSTATUSH_MASK = 32'h000006F0;

localparam SSTATUS_ID    = 12'h100;
localparam STVEC_ID      = 12'h105;
localparam SEPC_ID       = 12'h141;
localparam SCAUSE_ID     = 12'h142;
localparam SSTATUS_MASK  = 32'h818DE762;

// CSR Read
reg [31:0] rData;
always @(*) begin
        rData = 32'b0;

        case (csrRAddr_i)
                CYCLE_ID:    rData = CSR_cycle[31:0];
                CYCLEH_ID:   rData = CSR_cycle[63:32];
                INSTRET_ID:  rData = CSR_instret[31:0];
                INSTRETH_ID: rData = CSR_instret[63:32];
                FFLAGS_ID:   rData = {27'b0, csrWData_i[4:0]};
                FRM_ID:      rData = {29'b0, csrWData_i[7:5]};
                FCSR_ID:     rData = {24'b0, csrWData_i[7:0]};

                MSTATUS_ID:  rData = CSR_mstatus  & MSTATUS_MASK;
                MSTATUSH_ID: rData = CSR_mstatush & MSTATUSH_MASK;
                MEDELEG_ID:  rData = CSR_medeleg[31:0];
                MEDELEGH_ID: rData = CSR_medeleg[63:32];
                MIDELEG_ID:  rData = CSR_mideleg;
                MTVEC_ID:    rData = CSR_mtvec;
                MEPC_ID:     rData = CSR_mepc;
                MCAUSE_ID:   rData = CSR_mcause;

                SSTATUS_ID:  rData = CSR_mstatus & SSTATUS_MASK;
                STVEC_ID:    rData = CSR_stvec;
                SEPC_ID:     rData = CSR_sepc;
                SCAUSE_ID:   rData = CSR_scause;
                default:     rData = 32'b0;
        endcase
end
assign csrRData_o   = rData;
assign csrMStatus_o = {CSR_mstatush, CSR_mstatus};
assign csrMedeleg_o = CSR_medeleg;
assign csrMideleg_o = CSR_mideleg;
assign csrMtvec_o   = CSR_mtvec;
assign csrMepc_o    = CSR_mepc;
assign csrMCause_o  = CSR_mcause;

assign csrStvec_o   = CSR_stvec;
assign csrSepc_o    = CSR_sepc;
assign csrSCause_o  = CSR_scause;

// CSR Write
always @(posedge clk_i) begin
        if (reset_i) begin
                CSR_fcsr           <= 32'b0;
                CSR_mstatus        <= 32'b0;
                CSR_mstatush       <= 32'b0;
                CSR_medeleg        <= 64'b0;
                CSR_mideleg        <= 32'b0;
                CSR_mtvec          <= 32'b0;
                CSR_mepc           <= 32'b0;
                CSR_mcause         <= 32'b0;
                CSR_mstatus        <= 32'b0;
                CSR_stvec          <= 32'b0;
                CSR_sepc           <= 32'b0;
                CSR_scause         <= 32'b0;
        end else if (csrWEnable_i) begin
                case (csrWAddr_i)
                        FFLAGS_ID:   CSR_fcsr           <= csrWData_i & FFLAGS_MASK;
                        FRM_ID:      CSR_fcsr           <= csrWData_i & FRM_MASK;
                        FCSR_ID:     CSR_fcsr           <= csrWData_i & FCSR_MASK;

                        MSTATUS_ID:  CSR_mstatus        <= csrWData_i & MSTATUS_MASK;
                        MSTATUSH_ID: CSR_mstatush       <= csrWData_i & MSTATUSH_MASK;
                        MEDELEG_ID:  CSR_medeleg[31:0]  <= csrWData_i;
                        MEDELEGH_ID: CSR_medeleg[63:32] <= csrWData_i;
                        MIDELEG_ID:  CSR_mideleg        <= csrWData_i;
                        MTVEC_ID:    CSR_mtvec          <= csrWData_i;
                        MEPC_ID:     CSR_mepc           <= csrWData_i;
                        MCAUSE_ID:   CSR_mcause         <= csrWData_i;

                        SSTATUS_ID:  CSR_mstatus        <= csrWData_i & SSTATUS_MASK;
                        STVEC_ID:    CSR_stvec          <= csrWData_i;
                        SEPC_ID:     CSR_sepc           <= csrWData_i;
                        SCAUSE_ID:   CSR_scause         <= csrWData_i;
                        default:;
                endcase
        end
        // Set FPU Flags
        CSR_fcsr[4:0] <= CSR_fcsr[4:0] | csrFFlagsSet_i;
end

// CSR Update
always @(posedge clk_i) begin
        if (reset_i) begin
                CSR_cycle   <= 64'b0;
                CSR_instret <= 64'b0;
        end else begin
                CSR_cycle   <= CSR_cycle + 1'b1;
                if (csrInstStep_i)
                        CSR_instret <= CSR_instret + 1'b1;
        end
end

// Current Privilege Level (Not visible to software; Hardware use only)
// 0: User, 1: Supervisor, 3: Machine
reg[1:0] privilege = 2'b11;

always @(posedge clk_i) begin
        if (reset_i) begin
                // Processor starts in machine mode;
                privilege <= 2'b11;
        end else begin
                if (privilegeSetEn_i)
                        privilege <= privilegeSet_i;
        end
end

endmodule

