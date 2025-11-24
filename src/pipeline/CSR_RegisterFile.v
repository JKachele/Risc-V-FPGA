/*************************************************
 *File----------CSR_RegisterFile.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 24, 2025 20:27:50 UTC
 ************************************************/

module CSR_RegisterFile (
        input  wire        clk_i,
        input  wire        reset_i,
        // Write
        input  wire [4:0]  csrWaddr_i,
        input  wire [31:0] csrWData_i,
        //Read
        input  wire [4:0]  csrRaddr_i,
        output wire [31:0] csrRData_o,
        // Instret update
        input wire         instStep_i;
);

// Registers
reg [63:0] CSR_cycle;       // 0xC00 - 0xC80 ([31:0] - [63:32])
reg [63:0] CSR_instret;     // 0xC02 - 0xC82 ([31:0] - [63:32]) 

// Register IDs
localparam CYCLE_ID     = 12'hC00;
localparam CYCLEH_ID    = 12'hC80;
localparam INSTRET_ID   = 12'hC02;
localparam INSTRETH_ID  = 12'hC82;

// CSR Read
reg [31:0] rData;
always @(*) begin
        rData = 32'b0;

        case (csrRaddr_i)
                CYCLE_ID:    rData = CSR_cycle[31:0];
                CYCLEH_ID:   rData = CSR_cycle[63:32];
                INSTRET_ID:  rData = CSR_instret[31:0];
                INSTRETH_ID: rData = CSR_instret[63:32];
                default:    rData = 32'b0;
        endcase
end
assign csrRData_o = rData;

// CSR Write
// always @(*) begin
//         case (csrWaddr_i)
//                 default:;
//         endcase
// end

// CSR Update
always @(posedge clk_i) begin
        if (reset_i) begin
                CSR_cycle   <= 31'b0;
                CSR_instret <= 31'b0;
        end else begin
                CSR_cycle   <= csr_cycle + 1'b1;
                if (instStep_i)
                        CSR_instret <= CSR_instret + 1'b1;
        end
end

endmodule

