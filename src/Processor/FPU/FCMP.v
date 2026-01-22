/*************************************************
 *File----------FCMP.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Dec 15, 2025 22:12:26 UTC
 ************************************************/

module FCMP #(
        parameter FLEN = 32
)(
        input  wire        [FLEN-1:0]   rs1_i,
        input  wire signed [NEXP+1:0]   rs1Exp_i,
        input  wire        [NSIG:0]     rs1Sig_i,
        input  wire        [5:0]        rs1Class_i,
        input  wire        [FLEN-1:0]   rs2_i,
        input  wire signed [NEXP+1:0]   rs2Exp_i,
        input  wire        [NSIG:0]     rs2Sig_i,
        input  wire        [5:0]        rs2Class_i,

        output wire [2:0]  fcmp_o // {FLT, FLE, FEQ}
);
`ifdef BENCH
        `include "src/Processor/FPU/FClassFlags.vh"
`else
        `include "../src/Processor/FPU/FClassFlags.vh"
`endif

localparam NEXP = (FLEN == 32) ? 8 : 11;
localparam NSIG = (FLEN == 32) ? 23 : 52;

reg [2:0] out;
assign fcmp_o = out;

always @(*) begin
        // If either input is NaN, output is 0 for all comparisons
        if (rs1Class_i[CLASS_BIT_QNAN] || rs2Class_i[CLASS_BIT_QNAN] ||
                rs1Class_i[CLASS_BIT_SNAN] || rs2Class_i[CLASS_BIT_SNAN]) begin
                out = 3'b000;
        end
        // Compare with infinity
        else if (rs1Class_i[CLASS_BIT_INF]) begin
                if (~rs1_i[FLEN-1]) begin
                        if (rs2Class_i[CLASS_BIT_INF] && !rs2_i[FLEN-1])
                                out = 3'b011;
                        else
                                out = 3'b000;
                end else begin
                        if (rs2Class_i[CLASS_BIT_INF] && rs2_i[FLEN-1])
                                out = 3'b011;
                        else
                                out = 3'b110;
                end
        end else if (rs2Class_i[CLASS_BIT_INF]) begin
                out = (rs2_i[FLEN-1]) ? 3'b000 : 3'b110;
        end
        // +0 = -0
        else if (rs1Class_i[CLASS_BIT_ZERO] && rs2Class_i[CLASS_BIT_ZERO]) begin
                out = 3'b011;
        end else begin
                out = {X_LT_Y, X_LE_Y, X_EQ_Y};
        end
end

/**************** Support Circuritry ****************/
wire signed [NSIG+1:0] signiDiff = rs2Sig_i - rs1Sig_i;
wire signed [NEXP+2:0] expDiff   = rs2Exp_i - rs1Exp_i;

/******** Comparisons ********/
wire expEQ   = (expDiff == 0);          // rs1 and rs2 exponents are equal
wire signiEQ = (signiDiff == 0);        // rs1 and rs2 significands are equal
wire fabsEQ  = (expEQ & signiEQ);       // abs(rs1) and abs(rs2) are equal

wire fabsX_LT_fabsY = (!expDiff[NEXP+2] && !expEQ) || (expEQ && !signiEQ && !signiDiff[NSIG+1]);
wire fabsX_LE_fabsY = (!expDiff[NEXP+2] && !expEQ) || (expEQ && !signiDiff[NSIG+1]);
wire fabsY_LT_fabsX = expDiff[NEXP+2]              || (expEQ && signiDiff[NSIG+1]);
wire fabsY_LE_fabsX = expDiff[NEXP+2]              || (expEQ && (signiDiff[NSIG+1] || signiEQ));

wire X_LT_Y = (rs1_i[FLEN-1]  && !rs2_i[FLEN-1])                   ||
              (rs1_i[FLEN-1]  && rs2_i[FLEN-1]  && fabsY_LT_fabsX) ||
              (!rs1_i[FLEN-1] && !rs2_i[FLEN-1] && fabsX_LT_fabsY);
wire X_LE_Y = (rs1_i[FLEN-1]  && !rs2_i[FLEN-1])                   ||
              (rs1_i[FLEN-1]  && rs2_i[FLEN-1]  && fabsY_LE_fabsX) ||
              (!rs1_i[FLEN-1] && !rs2_i[FLEN-1] && fabsX_LE_fabsY);
wire X_EQ_Y = fabsEQ && (rs1_i[FLEN-1] == rs2_i[FLEN-1]);

endmodule

