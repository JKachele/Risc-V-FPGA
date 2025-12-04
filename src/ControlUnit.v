/*************************************************
 *File----------ControlUnit.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 02, 2025 20:26:52 UTC
 ************************************************/

module ControlUnit (
        input  wire HALT_i,
        input  wire dataHazard_i,
        input  wire aluBusy_i,
        input  wire E_correctPC_i,
        output wire F_stall_o,
        output wire D_stall_o,
        output wire E_stall_o,
        output wire D_flush_o,
        output wire E_flush_o,
        output wire M_flush_o
);

assign F_stall_o = aluBusy_i | dataHazard_i | HALT_i;
assign D_stall_o = aluBusy_i | dataHazard_i | HALT_i;
assign E_stall_o = aluBusy_i;

assign D_flush_o = E_correctPC_i;
assign E_flush_o = E_correctPC_i | dataHazard_i;
assign M_flush_o = aluBusy_i;

endmodule

