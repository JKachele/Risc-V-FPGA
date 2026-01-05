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
        //Read
        input  wire [11:0] csrRAddr_i,
        output wire [31:0] csrRData_o,
        // Instret update
        input wire         csrInstStep_i,
        // FPU Rounding Mode
        output wire [2:0]  csrFRM_o
);

// Counters
reg [63:0] CSR_cycle;       // 0xC00 / 0xC80 ([31:0] / [63:32])
reg [63:0] CSR_instret;     // 0xC02 / 0xC82 ([31:0] / [63:32]) 

// Floating Point Extension
reg [31:0] CSR_fcsr = 0;    // 0x001 - 0x003 (fflags, frm, fcsr)

// Register IDs
`define CYCLE_ID     12'hC00
`define CYCLEH_ID    12'hC80
`define INSTRET_ID   12'hC02
`define INSTRETH_ID  12'hC82

`define FFLAGS_ID    12'h001
`define FFLAGS_MASK  32'h0000001F
`define FRM_ID       12'h002
`define FRM_MASK     32'h000000E0
`define FCSR_ID      12'h003
`define FCSR_MASK    32'h000000FF

// CSR Read
reg [31:0] rData;
always @(*) begin
        rData = 32'b0;

        case (csrRAddr_i)
                `CYCLE_ID:    rData = CSR_cycle[31:0];
                `CYCLEH_ID:   rData = CSR_cycle[63:32];
                `INSTRET_ID:  rData = CSR_instret[31:0];
                `INSTRETH_ID: rData = CSR_instret[63:32];
                `FFLAGS_ID:   rData = {27'b0, csrWData_i[4:0]};
                `FRM_ID:      rData = {29'b0, csrWData_i[7:5]};
                `FCSR_ID:     rData = {24'b0, csrWData_i[7:0]};
                default:      rData = 32'b0;
        endcase
end
assign csrRData_o = rData;

// CSR Write
always @(*) begin
        case (csrWAddr_i)
                `FFLAGS_ID: CSR_fcsr = csrWData_i & `FFLAGS_MASK;
                `FRM_ID:    CSR_fcsr = csrWData_i & `FRM_MASK;
                `FCSR_ID:   CSR_fcsr = csrWData_i & `FCSR_MASK;
                default:;
        endcase
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

endmodule

