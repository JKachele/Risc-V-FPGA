/*************************************************
 *File----------CLZ.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Dec 11, 2025 22:31:27 UTC
 ************************************************/

module CLZ #(
   parameter W_IN = 64, // must be power of 2, >= 2
   parameter W_OUT = $clog2(W_IN)	     
) (
   input wire [W_IN-1:0]   in,
   output wire [W_OUT-1:0] out
);
  generate
     if(W_IN == 2) begin
	assign out = !in[1];
     end else begin
	wire [W_OUT-2:0] half_count;
	wire [W_IN/2-1:0] lhs = in[W_IN/2 +: W_IN/2];
	wire [W_IN/2-1:0] rhs = in[0      +: W_IN/2];
	wire left_empty = ~|lhs;
	CLZ #(
	  .W_IN(W_IN/2)
        ) inner(
           .in(left_empty ? rhs : lhs),
           .out(half_count)		
	);
	assign out = {left_empty, half_count};
     end
  endgenerate
endmodule
