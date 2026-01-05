/*************************************************
 *File----------FRound.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Tuesday Dec 16, 2025 17:35:02 UTC
 ************************************************/

module FRound #(
        parameter nInt = 32,
        parameter nExp = 8,
        parameter nSig = 23
)(
        input  wire                   sign_i,
        input  wire        [nInt-1:0] sig_i,       // MSB is implied 1
        input  wire signed [nExp+1:0] exp_i,
        input  wire        [2:0]      rm_i,

        output wire        [nSig:0]   sig_o,
        output wire signed [nExp+1:0] exp_o
);
localparam nRound = nInt - nSig - 1;

reg        [nSig:0]   sigOut;
reg signed [nExp+1:0] expOut;
assign sig_o = sigOut;
assign exp_o = expOut;

wire [nRound-1:0] roundBits = sig_i[nRound-1:0];
wire roundBit = roundBits[nRound-1];
wire stickyBit = |roundBits[nRound-2:0];
wire sigOdd = sig_i[nRound];

reg        roundUp; // 1 if rounding up

reg [nSig+1:0] roundedSig;

always @(*) begin
        /************************ Nearest Ties to Even ************************/
        if (rm_i == 3'b000) begin
                // Round down
                if (!roundBit) begin
                        roundUp = 1'b0;
                end
                // Round up
                else if (stickyBit) begin
                        roundUp = 1'b1;
                end
                // Ties to Even
                else if (sigOdd) begin // Odd
                        roundUp = 1'b1;
                end else begin // Even
                        roundUp = 1'b0;
                end
        end
        /************************ Round Towards Zero ************************/
        else if (rm_i == 3'b001) begin
                // Always round down
                roundUp = 1'b0;
        end
        /************************ Round Towards Negative Infinity ************************/
        else if (rm_i == 3'b010) begin
                // Positives round down, Negatives round up if needed
                // if all roundBits are 0, no rounding is needed
                if (sign_i && |roundBits) begin
                        roundUp = 1'b1;
                end else begin
                        roundUp = 1'b0;
                end
        end
        /************************ Round Towards Positive Infinity ************************/
        else if (rm_i == 3'b011) begin
                // Positives round up, Negatives round down
                // if all roundBits are 0, no rounding is needed
                if (~sign_i && |roundBits) begin
                        roundUp = 1'b1;
                end else begin
                        roundUp = 1'b0;
                end
        end
        /************************ Nearest Ties to Max Magnitude ************************/
        else if (rm_i == 3'b100) begin
                // Round down
                if (!roundBit) begin
                        roundUp = 1'b0;
                end
                // Round up
                else if (stickyBit) begin
                        roundUp = 1'b1;
                end
                // Ties to Max Magnitude (Round up)
                else begin
                        roundUp = 1'b1;
                end
        end
        // Other rounding modes are reserved. Default to truncate
        else begin
                roundUp = 1'b0;
        end

        /************************ Perform Rounding ************************/
        roundedSig = {1'b0, sig_i[nInt-1:nRound]} + {{nSig+1{1'b0}}, roundUp};
        if (roundedSig[nSig+1]) begin
                sigOut = roundedSig[nSig+1:1];
                expOut = exp_i + 1;
        end else begin
                sigOut = roundedSig[nSig:0];
                expOut = exp_i;
        end
end

endmodule

module FRoundInt (
        input  wire        sign_i,
        input  wire [31:0] int_i,
        input  wire        roundBit_i,
        input  wire        stickyBit_i,
        input  wire [2:0]  rm_i,

        output wire [31:0] int_o
);

assign int_o = int_i + {31'b0, roundUp};

reg roundUp; // 1 if rounding up

always @(*) begin
        /************************ Nearest Ties to Even ************************/
        if (rm_i == 3'b000) begin
                // Round down
                if (!roundBit_i) begin
                        roundUp = 1'b0;
                end
                // Round up
                else if (stickyBit_i) begin
                        roundUp = 1'b1;
                end
                // Ties to Even
                else if (int_i[0]) begin // Odd
                        roundUp = 1'b1;
                end else begin // Even
                        roundUp = 1'b0;
                end
        end
        /************************ Round Towards Zero ************************/
        else if (rm_i == 3'b001) begin
                // Always round down
                roundUp = 1'b0;
        end
        /************************ Round Towards Negative Infinity ************************/
        else if (rm_i == 3'b010) begin
                // Positives round down, Negatives round up if needed
                // if all roundBits are 0, no rounding is needed
                if (sign_i && roundBit_i && stickyBit_i) begin
                        roundUp = 1'b1;
                end else begin
                        roundUp = 1'b0;
                end
        end
        /************************ Round Towards Positive Infinity ************************/
        else if (rm_i == 3'b011) begin
                // Positives round up, Negatives round down
                // if all roundBits are 0, no rounding is needed
                if (~sign_i && roundBit_i && stickyBit_i) begin
                        roundUp = 1'b1;
                end else begin
                        roundUp = 1'b0;
                end
        end
        /************************ Nearest Ties to Max Magnitude ************************/
        else if (rm_i == 3'b100) begin
                // Round down
                if (!roundBit_i) begin
                        roundUp = 1'b0;
                end
                // Round up
                else if (stickyBit_i) begin
                        roundUp = 1'b1;
                end
                // Ties to Max Magnitude (Round up)
                else begin
                        roundUp = 1'b1;
                end
        end
        // Other rounding modes are reserved. Default to truncate
        else begin
                roundUp = 1'b0;
        end
end

endmodule
