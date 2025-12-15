/*************************************************
 *File----------FCMP.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Dec 15, 2025 22:12:26 UTC
 ************************************************/

module FCMP (
        input  wire        [31:0] rs1_i,
        input  wire signed [9:0]  rs1Exp_i,
        input  wire        [23:0] rs1Sig_i,
        input  wire        [5:0]  rs1Class_i,
        input  wire        [31:0] rs2_i,
        input  wire signed [9:0]  rs2Exp_i,
        input  wire        [23:0] rs2Sig_i,
        input  wire        [5:0]  rs2Class_i,

        output wire [2:0]  fcmp_o // {FLT, FLE, FEQ}
);
localparam CLASS_ZERO = 0;
localparam CLASS_SUB  = 1;
localparam CLASS_NORM = 2;
localparam CLASS_INF  = 3;
localparam CLASS_SNAN = 4;
localparam CLASS_QNAN = 5;

reg [2:0] out;
assign fcmp_o = out;

always @(*) begin
        // If either input is NaN, output is 0 for all comparisons
        if (rs1Class_i[CLASS_QNAN] || rs2Class_i[CLASS_QNAN] ||
                rs1Class_i[CLASS_SNAN] || rs2Class_i[CLASS_SNAN]) begin
                out = 3'b0;
        end else if (rs1Class_i[CLASS_INF]) begin
                if (rs2Class_i[CLASS_INF])
                        out = 3'b011;
                else 
                        out = 3'b0;
        end else if (rs2Class_i[CLASS_INF]) begin
                out = 3'b110;
        end else begin
                out = {X_LT_Y, X_LE_Y, X_EQ_Y};
        end
end

/**************** Support Circuritry ****************/
wire signed [24:0] signiDiff = rs2Sig_i - rs1Sig_i;
wire signed [10:0] expDiff   = rs2Exp_i - rs1Exp_i;

/******** Comparisons ********/
wire expEQ   = (expDiff == 0);          // rs1 and rs2 exponents are equal
wire signiEQ = (signiDiff == 0);        // rs1 and rs2 significands are equal
wire fabsEQ  = (expEQ & signiEQ);       // abs(rs1) and abs(rs2) are equal

wire fabsX_LT_fabsY = (!expDiff[10] && !expEQ) || (expEQ && !signiEQ && !signiDiff[24]);
wire fabsX_LE_fabsY = (!expDiff[10] && !expEQ) || (expEQ && !signiDiff[24]);
wire fabsY_LT_fabsX = expDiff[10]              || (expEQ && signiDiff[24]);
wire fabsY_LE_fabsX = expDiff[10]              || (expEQ && (signiDiff[24] || signiEQ));

wire X_LT_Y = (rs1_i[31]  && !rs2_i[31])                   ||
              (rs1_i[31]  && rs2_i[31]  && fabsY_LT_fabsX) ||
              (!rs1_i[31] && !rs2_i[31] && fabsX_LT_fabsY);
wire X_LE_Y = (rs1_i[31]  && !rs2_i[31])                   ||
              (rs1_i[31]  && rs2_i[31]  && fabsY_LE_fabsX) ||
              (!rs1_i[31] && !rs2_i[31] && fabsX_LE_fabsY);
wire X_EQ_Y = fabsEQ && (rs1_i[31] == rs2_i[31]);

endmodule

