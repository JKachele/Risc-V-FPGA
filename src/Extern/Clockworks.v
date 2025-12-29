/*************************************************
 *File----------Clockworks.v
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Sunday Nov 02, 2025 13:25:08 EST
 *License-------GNU GPL-3.0
 ************************************************/

module Clockworks 
(
        input  wire CLK, // clock pin of the board
        input  wire RESET, // reset pin of the board
        output wire clk,   // (optionally divided) clock for the design.
        // divided if SLOW is different from zero.
        output wire resetn // (optionally timed) negative reset for the design
);               

parameter SLOW=0;

generate

        if (SLOW != 0) begin
                // Slow clock down by 2^SLOW
                reg [SLOW:0] slow_CLK = 0;
                always @(posedge CLK) begin
                        slow_CLK <= slow_CLK + 1;
                end
                assign clk = slow_CLK[SLOW-1];
        end else begin
                assign clk = CLK;
        end
        `ifdef BENCH
                assign resetn = RESET;
        `else
                assign resetn = !RESET;
        `endif   

endgenerate
endmodule
