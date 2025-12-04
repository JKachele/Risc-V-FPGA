/*************************************************
 *File----------FetchUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 15:40:10 UTC
 ************************************************/

module FetchUnit (
        input  wire        clk_i,
        input  wire        reset_i,
        // Pipeline Control Signals
        input  wire        F_stall_i,
        input  wire        D_flush_i,
        input  wire        D_predictPC_i,
        input  wire [31:0] D_PCprediction_i,
        input  wire        EM_correctPC_i,
        input  wire [31:0] EM_PCcorrection_i,
        // Memory Interface
        output wire [31:0] IMemAddr_o,
        input  wire [31:0] IMemData_i,
        // Decode Unit Interface
        output reg  [31:0] FD_PC_o,
        output reg  [31:0] FD_instr_o,
        output reg         FD_nop_o
);

reg [31:0] PC;

wire [31:0] F_PC =
        D_predictPC_i  ? D_PCprediction_i  :
        EM_correctPC_i ? EM_PCcorrection_i :
                             PC;

assign IMemAddr_o = F_PC;

always @(posedge clk_i) begin
        if (!F_stall_i) begin
                FD_instr_o <= IMemData_i;
                FD_PC_o <= F_PC;
                PC <= F_PC + 4;
        end

        FD_nop_o <= D_flush_i | reset_i;

        if (reset_i) begin
                PC <= 0;
        end

end

endmodule

