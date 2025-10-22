module Clockworks 
(
        input  CLK, // clock pin of the board
        input  RESET, // reset pin of the board
        output clk,   // (optionally divided) clock for the design.
        // divided if SLOW is different from zero.
        output resetn // (optionally timed) negative reset for the design
);               

parameter SLOW=0;

generate

        if (SLOW != 0) begin
                // Slow clock down by 2^SLOW
                // Simulator is about 16x slower than actual clock
                `ifdef BENCH
                        localparam slowBit=SLOW-10;
                `else
                        localparam slowBit=SLOW;
                `endif
                reg [slowBit:0] slow_CLK = 0;
                always @(posedge CLK) begin
                        slow_CLK <= slow_CLK + 1;
                end
                assign clk = slow_CLK[slowBit];
        end else begin
                assign clk = CLK;
        end
        assign resetn = !RESET;

endgenerate
endmodule

