/*************************************************
 *File----------LEDS.v
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Sunday Nov 09, 2025 20:02:48 EST
 *License-------GNU GPL-3.0
 ************************************************/

module LedDim (
        input  wire        clk,
        input  wire [3:0] leds_i,
        output reg  [3:0] leds_o
);

reg count;
always @(posedge clk) begin
        if (count == 1'b1) begin
                leds_o <= leds_i;
        end else begin
                leds_o <= 4'b0;
        end
        count <= ~count;
end

endmodule

