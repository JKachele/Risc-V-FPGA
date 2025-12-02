/*************************************************
 *File----------WriteBackUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 20:18:29 UTC
 ************************************************/

module WriteBackUnit (
        input  wire        clk_i,
        input  wire        reset_i,
        // Register File Interface
        output wire [4:0]  rdId_o,
        output wire [31:0] rdData_o,
        // Memory Unit Interface
        input  wire [31:0] MW_PC_i,
        input  wire [31:0] MW_instr_i,
        input  wire        MW_nop_i,
        input  wire [4:0]  MW_rdId_i,
        input  wire [31:0] MW_wbData_i,
        input  wire        MW_wbEnable_i
);
assign rdData_o = MW_wbData_i;
assign rdId_o = MW_wbEnable_i ? MW_rdId_i : 5'b0;

endmodule

