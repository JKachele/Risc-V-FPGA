/*************************************************
 *File----------SSegDisplay.v
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Sunday Nov 02, 2025 12:48:26 EST
 *License-------GNU GPL-3.0
 ************************************************/

module SSegDisplay (
        input  wire clk,
        input  wire [31:0] num,
        output wire [7:0] SSEG_CA,
        output wire [7:0] SSEG_AN
);

reg [7:0] DIGITS [0:15];
initial begin
        DIGITS[0]  = 8'b11000000;
        DIGITS[1]  = 8'b11111001;
        DIGITS[2]  = 8'b10100100;
        DIGITS[3]  = 8'b10110000;
        DIGITS[4]  = 8'b10011001;
        DIGITS[5]  = 8'b10010010;
        DIGITS[6]  = 8'b10000010;
        DIGITS[7]  = 8'b11111000;
        DIGITS[8]  = 8'b10000000;
        DIGITS[9]  = 8'b10010000;
        DIGITS[10] = 8'b10001000;
        DIGITS[11] = 8'b10000011;
        DIGITS[12] = 8'b11000110;
        DIGITS[13] = 8'b10100001;
        DIGITS[14] = 8'b10000110;
        DIGITS[15] = 8'b10001110;
end

wire [3:0] numDigits [0:15];
assign numDigits[0] = num[31:28];
assign numDigits[1] = num[27:24];
assign numDigits[2] = num[23:20];
assign numDigits[3] = num[19:16];
assign numDigits[4] = num[15:12];
assign numDigits[5] = num[11:8];
assign numDigits[6] = num[7:4];
assign numDigits[7] = num[3:0];

reg [7:0] ssegSel = 8'b01111111;
reg [2:0] numSel = 0;
assign SSEG_AN = ssegSel;
assign SSEG_CA = DIGITS[numDigits[numSel]];

always @(posedge clk) begin
        ssegSel <= {ssegSel[0], ssegSel[7:1]};
        numSel <= numSel + 1;
end

endmodule

