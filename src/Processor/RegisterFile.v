/*************************************************
 *File----------RegisterFile.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 24, 2025 19:45:18 UTC
 ************************************************/

module RegisterFile (
        input  wire        clk_i,
        input  wire        reset_i,
        input  wire [5:0]  rdId_i,
        input  wire [63:0] rdData_i,
        input  wire [5:0]  rs1Id_i,
        input  wire [5:0]  rs2Id_i,
        input  wire [5:0]  rs3Id_i,
        output wire [63:0] rs1Data_o,
        output wire [63:0] rs2Data_o,
        output wire [63:0] rs3Data_o
);

reg [31:0] reg_1;
reg [31:0] reg_2;
reg [31:0] reg_3;
reg [31:0] reg_4;
reg [31:0] reg_5;
reg [31:0] reg_6;
reg [31:0] reg_7;
reg [31:0] reg_8;
reg [31:0] reg_9;
reg [31:0] reg_10;
reg [31:0] reg_11;
reg [31:0] reg_12;
reg [31:0] reg_13;
reg [31:0] reg_14;
reg [31:0] reg_15;
reg [31:0] reg_16;
reg [31:0] reg_17;
reg [31:0] reg_18;
reg [31:0] reg_19;
reg [31:0] reg_20;
reg [31:0] reg_21;
reg [31:0] reg_22;
reg [31:0] reg_23;
reg [31:0] reg_24;
reg [31:0] reg_25;
reg [31:0] reg_26;
reg [31:0] reg_27;
reg [31:0] reg_28;
reg [31:0] reg_29;
reg [31:0] reg_30;
reg [31:0] reg_31;

reg [63:0] reg_F0;
reg [63:0] reg_F1;
reg [63:0] reg_F2;
reg [63:0] reg_F3;
reg [63:0] reg_F4;
reg [63:0] reg_F5;
reg [63:0] reg_F6;
reg [63:0] reg_F7;
reg [63:0] reg_F8;
reg [63:0] reg_F9;
reg [63:0] reg_F10;
reg [63:0] reg_F11;
reg [63:0] reg_F12;
reg [63:0] reg_F13;
reg [63:0] reg_F14;
reg [63:0] reg_F15;
reg [63:0] reg_F16;
reg [63:0] reg_F17;
reg [63:0] reg_F18;
reg [63:0] reg_F19;
reg [63:0] reg_F20;
reg [63:0] reg_F21;
reg [63:0] reg_F22;
reg [63:0] reg_F23;
reg [63:0] reg_F24;
reg [63:0] reg_F25;
reg [63:0] reg_F26;
reg [63:0] reg_F27;
reg [63:0] reg_F28;
reg [63:0] reg_F29;
reg [63:0] reg_F30;
reg [63:0] reg_F31;

// ABI Register Names
wire [31:0] zero = 32'b0;
wire [31:0] ra   = reg_1;
wire [31:0] sp   = reg_2;
wire [31:0] gp   = reg_3;
wire [31:0] tp   = reg_4;
wire [31:0] t0   = reg_5;
wire [31:0] t1   = reg_6;
wire [31:0] t2   = reg_7;
wire [31:0] s0   = reg_8;
wire [31:0] s1   = reg_9;
wire [31:0] a0   = reg_10;
wire [31:0] a1   = reg_11;
wire [31:0] a2   = reg_12;
wire [31:0] a3   = reg_13;
wire [31:0] a4   = reg_14;
wire [31:0] a5   = reg_15;
wire [31:0] a6   = reg_16;
wire [31:0] a7   = reg_17;
wire [31:0] s2   = reg_18;
wire [31:0] s3   = reg_19;
wire [31:0] s4   = reg_20;
wire [31:0] s5   = reg_21;
wire [31:0] s6   = reg_22;
wire [31:0] s7   = reg_23;
wire [31:0] s8   = reg_24;
wire [31:0] s9   = reg_25;
wire [31:0] s10  = reg_26;
wire [31:0] s11  = reg_27;
wire [31:0] t3   = reg_28;
wire [31:0] t4   = reg_29;
wire [31:0] t5   = reg_30;
wire [31:0] t6   = reg_31;

wire [63:0] ft0  = reg_F0;
wire [63:0] ft1  = reg_F1;
wire [63:0] ft2  = reg_F2;
wire [63:0] ft3  = reg_F3;
wire [63:0] ft4  = reg_F4;
wire [63:0] ft5  = reg_F5;
wire [63:0] ft6  = reg_F6;
wire [63:0] ft7  = reg_F7;
wire [63:0] fs0  = reg_F8;
wire [63:0] fs1  = reg_F9;
wire [63:0] fa0  = reg_F10;
wire [63:0] fa1  = reg_F11;
wire [63:0] fa2  = reg_F12;
wire [63:0] fa3  = reg_F13;
wire [63:0] fa4  = reg_F14;
wire [63:0] fa5  = reg_F15;
wire [63:0] fa6  = reg_F16;
wire [63:0] fa7  = reg_F17;
wire [63:0] fs2  = reg_F18;
wire [63:0] fs3  = reg_F19;
wire [63:0] fs4  = reg_F20;
wire [63:0] fs5  = reg_F21;
wire [63:0] fs6  = reg_F22;
wire [63:0] fs7  = reg_F23;
wire [63:0] fs8  = reg_F24;
wire [63:0] fs9  = reg_F25;
wire [63:0] fs10 = reg_F26;
wire [63:0] fs11 = reg_F27;
wire [63:0] ft8  = reg_F28;
wire [63:0] ft9  = reg_F29;
wire [63:0] ft10 = reg_F30;
wire [63:0] ft11 = reg_F31;

// Synchronus Register Writeback
always @ (posedge clk_i) begin
        if (reset_i) begin
                reg_1   <= 32'b0;
                reg_2   <= 32'b0;
                reg_3   <= 32'b0;
                reg_4   <= 32'b0;
                reg_5   <= 32'b0;
                reg_6   <= 32'b0;
                reg_7   <= 32'b0;
                reg_8   <= 32'b0;
                reg_9   <= 32'b0;
                reg_10  <= 32'b0;
                reg_11  <= 32'b0;
                reg_12  <= 32'b0;
                reg_13  <= 32'b0;
                reg_14  <= 32'b0;
                reg_15  <= 32'b0;
                reg_16  <= 32'b0;
                reg_17  <= 32'b0;
                reg_18  <= 32'b0;
                reg_19  <= 32'b0;
                reg_20  <= 32'b0;
                reg_21  <= 32'b0;
                reg_22  <= 32'b0;
                reg_23  <= 32'b0;
                reg_24  <= 32'b0;
                reg_25  <= 32'b0;
                reg_26  <= 32'b0;
                reg_27  <= 32'b0;
                reg_28  <= 32'b0;
                reg_29  <= 32'b0;
                reg_30  <= 32'b0;
                reg_31  <= 32'b0;
                reg_F0  <= 64'b0;
                reg_F1  <= 64'b0;
                reg_F2  <= 64'b0;
                reg_F3  <= 64'b0;
                reg_F4  <= 64'b0;
                reg_F5  <= 64'b0;
                reg_F6  <= 64'b0;
                reg_F7  <= 64'b0;
                reg_F8  <= 64'b0;
                reg_F9  <= 64'b0;
                reg_F10 <= 64'b0;
                reg_F11 <= 64'b0;
                reg_F12 <= 64'b0;
                reg_F13 <= 64'b0;
                reg_F14 <= 64'b0;
                reg_F15 <= 64'b0;
                reg_F16 <= 64'b0;
                reg_F17 <= 64'b0;
                reg_F18 <= 64'b0;
                reg_F19 <= 64'b0;
                reg_F20 <= 64'b0;
                reg_F21 <= 64'b0;
                reg_F22 <= 64'b0;
                reg_F23 <= 64'b0;
                reg_F24 <= 64'b0;
                reg_F25 <= 64'b0;
                reg_F26 <= 64'b0;
                reg_F27 <= 64'b0;
                reg_F28 <= 64'b0;
                reg_F29 <= 64'b0;
                reg_F30 <= 64'b0;
                reg_F31 <= 64'b0;
        end else if (rdId_i[5] == 1'b0) begin
                if (rdId_i[4:0] == 5'd1)  reg_1  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd2)  reg_2  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd3)  reg_3  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd4)  reg_4  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd5)  reg_5  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd6)  reg_6  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd7)  reg_7  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd8)  reg_8  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd9)  reg_9  <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd10) reg_10 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd11) reg_11 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd12) reg_12 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd13) reg_13 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd14) reg_14 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd15) reg_15 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd16) reg_16 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd17) reg_17 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd18) reg_18 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd19) reg_19 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd20) reg_20 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd21) reg_21 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd22) reg_22 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd23) reg_23 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd24) reg_24 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd25) reg_25 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd26) reg_26 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd27) reg_27 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd28) reg_28 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd29) reg_29 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd30) reg_30 <= rdData_i[31:0];
                if (rdId_i[4:0] == 5'd31) reg_31 <= rdData_i[31:0];
        end else begin
                if (rdId_i[4:0] == 5'd0)  reg_F0  <= rdData_i;
                if (rdId_i[4:0] == 5'd1)  reg_F1  <= rdData_i;
                if (rdId_i[4:0] == 5'd2)  reg_F2  <= rdData_i;
                if (rdId_i[4:0] == 5'd3)  reg_F3  <= rdData_i;
                if (rdId_i[4:0] == 5'd4)  reg_F4  <= rdData_i;
                if (rdId_i[4:0] == 5'd5)  reg_F5  <= rdData_i;
                if (rdId_i[4:0] == 5'd6)  reg_F6  <= rdData_i;
                if (rdId_i[4:0] == 5'd7)  reg_F7  <= rdData_i;
                if (rdId_i[4:0] == 5'd8)  reg_F8  <= rdData_i;
                if (rdId_i[4:0] == 5'd9)  reg_F9  <= rdData_i;
                if (rdId_i[4:0] == 5'd10) reg_F10 <= rdData_i;
                if (rdId_i[4:0] == 5'd11) reg_F11 <= rdData_i;
                if (rdId_i[4:0] == 5'd12) reg_F12 <= rdData_i;
                if (rdId_i[4:0] == 5'd13) reg_F13 <= rdData_i;
                if (rdId_i[4:0] == 5'd14) reg_F14 <= rdData_i;
                if (rdId_i[4:0] == 5'd15) reg_F15 <= rdData_i;
                if (rdId_i[4:0] == 5'd16) reg_F16 <= rdData_i;
                if (rdId_i[4:0] == 5'd17) reg_F17 <= rdData_i;
                if (rdId_i[4:0] == 5'd18) reg_F18 <= rdData_i;
                if (rdId_i[4:0] == 5'd19) reg_F19 <= rdData_i;
                if (rdId_i[4:0] == 5'd20) reg_F20 <= rdData_i;
                if (rdId_i[4:0] == 5'd21) reg_F21 <= rdData_i;
                if (rdId_i[4:0] == 5'd22) reg_F22 <= rdData_i;
                if (rdId_i[4:0] == 5'd23) reg_F23 <= rdData_i;
                if (rdId_i[4:0] == 5'd24) reg_F24 <= rdData_i;
                if (rdId_i[4:0] == 5'd25) reg_F25 <= rdData_i;
                if (rdId_i[4:0] == 5'd26) reg_F26 <= rdData_i;
                if (rdId_i[4:0] == 5'd27) reg_F27 <= rdData_i;
                if (rdId_i[4:0] == 5'd28) reg_F28 <= rdData_i;
                if (rdId_i[4:0] == 5'd29) reg_F29 <= rdData_i;
                if (rdId_i[4:0] == 5'd30) reg_F30 <= rdData_i;
                if (rdId_i[4:0] == 5'd31) reg_F31 <= rdData_i;
        end
end

// Asynchronus Register Read
reg [63:0] rs1Data;
reg [63:0] rs2Data;
reg [63:0] rs3Data;
always @(*) begin
        case (rs1Id_i[4:0])
                5'd0:  rs1Data = rs1Id_i[5] ? reg_F0  : 64'hFFFFFFFF00000000;
                5'd1:  rs1Data = rs1Id_i[5] ? reg_F1  : {32'hFFFFFFFF, reg_1};
                5'd2:  rs1Data = rs1Id_i[5] ? reg_F2  : {32'hFFFFFFFF, reg_2};
                5'd3:  rs1Data = rs1Id_i[5] ? reg_F3  : {32'hFFFFFFFF, reg_3};
                5'd4:  rs1Data = rs1Id_i[5] ? reg_F4  : {32'hFFFFFFFF, reg_4};
                5'd5:  rs1Data = rs1Id_i[5] ? reg_F5  : {32'hFFFFFFFF, reg_5};
                5'd6:  rs1Data = rs1Id_i[5] ? reg_F6  : {32'hFFFFFFFF, reg_6};
                5'd7:  rs1Data = rs1Id_i[5] ? reg_F7  : {32'hFFFFFFFF, reg_7};
                5'd8:  rs1Data = rs1Id_i[5] ? reg_F8  : {32'hFFFFFFFF, reg_8};
                5'd9:  rs1Data = rs1Id_i[5] ? reg_F9  : {32'hFFFFFFFF, reg_9};
                5'd10: rs1Data = rs1Id_i[5] ? reg_F10 : {32'hFFFFFFFF, reg_10};
                5'd11: rs1Data = rs1Id_i[5] ? reg_F11 : {32'hFFFFFFFF, reg_11};
                5'd12: rs1Data = rs1Id_i[5] ? reg_F12 : {32'hFFFFFFFF, reg_12};
                5'd13: rs1Data = rs1Id_i[5] ? reg_F13 : {32'hFFFFFFFF, reg_13};
                5'd14: rs1Data = rs1Id_i[5] ? reg_F14 : {32'hFFFFFFFF, reg_14};
                5'd15: rs1Data = rs1Id_i[5] ? reg_F15 : {32'hFFFFFFFF, reg_15};
                5'd16: rs1Data = rs1Id_i[5] ? reg_F16 : {32'hFFFFFFFF, reg_16};
                5'd17: rs1Data = rs1Id_i[5] ? reg_F17 : {32'hFFFFFFFF, reg_17};
                5'd18: rs1Data = rs1Id_i[5] ? reg_F18 : {32'hFFFFFFFF, reg_18};
                5'd19: rs1Data = rs1Id_i[5] ? reg_F19 : {32'hFFFFFFFF, reg_19};
                5'd20: rs1Data = rs1Id_i[5] ? reg_F20 : {32'hFFFFFFFF, reg_20};
                5'd21: rs1Data = rs1Id_i[5] ? reg_F21 : {32'hFFFFFFFF, reg_21};
                5'd22: rs1Data = rs1Id_i[5] ? reg_F22 : {32'hFFFFFFFF, reg_22};
                5'd23: rs1Data = rs1Id_i[5] ? reg_F23 : {32'hFFFFFFFF, reg_23};
                5'd24: rs1Data = rs1Id_i[5] ? reg_F24 : {32'hFFFFFFFF, reg_24};
                5'd25: rs1Data = rs1Id_i[5] ? reg_F25 : {32'hFFFFFFFF, reg_25};
                5'd26: rs1Data = rs1Id_i[5] ? reg_F26 : {32'hFFFFFFFF, reg_26};
                5'd27: rs1Data = rs1Id_i[5] ? reg_F27 : {32'hFFFFFFFF, reg_27};
                5'd28: rs1Data = rs1Id_i[5] ? reg_F28 : {32'hFFFFFFFF, reg_28};
                5'd29: rs1Data = rs1Id_i[5] ? reg_F29 : {32'hFFFFFFFF, reg_29};
                5'd30: rs1Data = rs1Id_i[5] ? reg_F30 : {32'hFFFFFFFF, reg_30};
                5'd31: rs1Data = rs1Id_i[5] ? reg_F31 : {32'hFFFFFFFF, reg_31};
                default: rs1Data = 64'hFFFFFFFF00000000;
        endcase

        case (rs2Id_i[4:0])
                5'd0:  rs2Data = rs2Id_i[5] ? reg_F0  : 64'hFFFFFFFF00000000;
                5'd1:  rs2Data = rs2Id_i[5] ? reg_F1  : {32'hFFFFFFFF, reg_1};
                5'd2:  rs2Data = rs2Id_i[5] ? reg_F2  : {32'hFFFFFFFF, reg_2};
                5'd3:  rs2Data = rs2Id_i[5] ? reg_F3  : {32'hFFFFFFFF, reg_3};
                5'd4:  rs2Data = rs2Id_i[5] ? reg_F4  : {32'hFFFFFFFF, reg_4};
                5'd5:  rs2Data = rs2Id_i[5] ? reg_F5  : {32'hFFFFFFFF, reg_5};
                5'd6:  rs2Data = rs2Id_i[5] ? reg_F6  : {32'hFFFFFFFF, reg_6};
                5'd7:  rs2Data = rs2Id_i[5] ? reg_F7  : {32'hFFFFFFFF, reg_7};
                5'd8:  rs2Data = rs2Id_i[5] ? reg_F8  : {32'hFFFFFFFF, reg_8};
                5'd9:  rs2Data = rs2Id_i[5] ? reg_F9  : {32'hFFFFFFFF, reg_9};
                5'd10: rs2Data = rs2Id_i[5] ? reg_F10 : {32'hFFFFFFFF, reg_10};
                5'd11: rs2Data = rs2Id_i[5] ? reg_F11 : {32'hFFFFFFFF, reg_11};
                5'd12: rs2Data = rs2Id_i[5] ? reg_F12 : {32'hFFFFFFFF, reg_12};
                5'd13: rs2Data = rs2Id_i[5] ? reg_F13 : {32'hFFFFFFFF, reg_13};
                5'd14: rs2Data = rs2Id_i[5] ? reg_F14 : {32'hFFFFFFFF, reg_14};
                5'd15: rs2Data = rs2Id_i[5] ? reg_F15 : {32'hFFFFFFFF, reg_15};
                5'd16: rs2Data = rs2Id_i[5] ? reg_F16 : {32'hFFFFFFFF, reg_16};
                5'd17: rs2Data = rs2Id_i[5] ? reg_F17 : {32'hFFFFFFFF, reg_17};
                5'd18: rs2Data = rs2Id_i[5] ? reg_F18 : {32'hFFFFFFFF, reg_18};
                5'd19: rs2Data = rs2Id_i[5] ? reg_F19 : {32'hFFFFFFFF, reg_19};
                5'd20: rs2Data = rs2Id_i[5] ? reg_F20 : {32'hFFFFFFFF, reg_20};
                5'd21: rs2Data = rs2Id_i[5] ? reg_F21 : {32'hFFFFFFFF, reg_21};
                5'd22: rs2Data = rs2Id_i[5] ? reg_F22 : {32'hFFFFFFFF, reg_22};
                5'd23: rs2Data = rs2Id_i[5] ? reg_F23 : {32'hFFFFFFFF, reg_23};
                5'd24: rs2Data = rs2Id_i[5] ? reg_F24 : {32'hFFFFFFFF, reg_24};
                5'd25: rs2Data = rs2Id_i[5] ? reg_F25 : {32'hFFFFFFFF, reg_25};
                5'd26: rs2Data = rs2Id_i[5] ? reg_F26 : {32'hFFFFFFFF, reg_26};
                5'd27: rs2Data = rs2Id_i[5] ? reg_F27 : {32'hFFFFFFFF, reg_27};
                5'd28: rs2Data = rs2Id_i[5] ? reg_F28 : {32'hFFFFFFFF, reg_28};
                5'd29: rs2Data = rs2Id_i[5] ? reg_F29 : {32'hFFFFFFFF, reg_29};
                5'd30: rs2Data = rs2Id_i[5] ? reg_F30 : {32'hFFFFFFFF, reg_30};
                5'd31: rs2Data = rs2Id_i[5] ? reg_F31 : {32'hFFFFFFFF, reg_31};
                default: rs2Data = 64'hFFFFFFFF00000000;
        endcase

        case (rs3Id_i[4:0])
                5'd0:  rs3Data = rs3Id_i[5] ? reg_F0  : 64'hFFFFFFFF00000000;
                5'd1:  rs3Data = rs3Id_i[5] ? reg_F1  : {32'hFFFFFFFF, reg_1};
                5'd2:  rs3Data = rs3Id_i[5] ? reg_F2  : {32'hFFFFFFFF, reg_2};
                5'd3:  rs3Data = rs3Id_i[5] ? reg_F3  : {32'hFFFFFFFF, reg_3};
                5'd4:  rs3Data = rs3Id_i[5] ? reg_F4  : {32'hFFFFFFFF, reg_4};
                5'd5:  rs3Data = rs3Id_i[5] ? reg_F5  : {32'hFFFFFFFF, reg_5};
                5'd6:  rs3Data = rs3Id_i[5] ? reg_F6  : {32'hFFFFFFFF, reg_6};
                5'd7:  rs3Data = rs3Id_i[5] ? reg_F7  : {32'hFFFFFFFF, reg_7};
                5'd8:  rs3Data = rs3Id_i[5] ? reg_F8  : {32'hFFFFFFFF, reg_8};
                5'd9:  rs3Data = rs3Id_i[5] ? reg_F9  : {32'hFFFFFFFF, reg_9};
                5'd10: rs3Data = rs3Id_i[5] ? reg_F10 : {32'hFFFFFFFF, reg_10};
                5'd11: rs3Data = rs3Id_i[5] ? reg_F11 : {32'hFFFFFFFF, reg_11};
                5'd12: rs3Data = rs3Id_i[5] ? reg_F12 : {32'hFFFFFFFF, reg_12};
                5'd13: rs3Data = rs3Id_i[5] ? reg_F13 : {32'hFFFFFFFF, reg_13};
                5'd14: rs3Data = rs3Id_i[5] ? reg_F14 : {32'hFFFFFFFF, reg_14};
                5'd15: rs3Data = rs3Id_i[5] ? reg_F15 : {32'hFFFFFFFF, reg_15};
                5'd16: rs3Data = rs3Id_i[5] ? reg_F16 : {32'hFFFFFFFF, reg_16};
                5'd17: rs3Data = rs3Id_i[5] ? reg_F17 : {32'hFFFFFFFF, reg_17};
                5'd18: rs3Data = rs3Id_i[5] ? reg_F18 : {32'hFFFFFFFF, reg_18};
                5'd19: rs3Data = rs3Id_i[5] ? reg_F19 : {32'hFFFFFFFF, reg_19};
                5'd20: rs3Data = rs3Id_i[5] ? reg_F20 : {32'hFFFFFFFF, reg_20};
                5'd21: rs3Data = rs3Id_i[5] ? reg_F21 : {32'hFFFFFFFF, reg_21};
                5'd22: rs3Data = rs3Id_i[5] ? reg_F22 : {32'hFFFFFFFF, reg_22};
                5'd23: rs3Data = rs3Id_i[5] ? reg_F23 : {32'hFFFFFFFF, reg_23};
                5'd24: rs3Data = rs3Id_i[5] ? reg_F24 : {32'hFFFFFFFF, reg_24};
                5'd25: rs3Data = rs3Id_i[5] ? reg_F25 : {32'hFFFFFFFF, reg_25};
                5'd26: rs3Data = rs3Id_i[5] ? reg_F26 : {32'hFFFFFFFF, reg_26};
                5'd27: rs3Data = rs3Id_i[5] ? reg_F27 : {32'hFFFFFFFF, reg_27};
                5'd28: rs3Data = rs3Id_i[5] ? reg_F28 : {32'hFFFFFFFF, reg_28};
                5'd29: rs3Data = rs3Id_i[5] ? reg_F29 : {32'hFFFFFFFF, reg_29};
                5'd30: rs3Data = rs3Id_i[5] ? reg_F30 : {32'hFFFFFFFF, reg_30};
                5'd31: rs3Data = rs3Id_i[5] ? reg_F31 : {32'hFFFFFFFF, reg_31};
                default: rs3Data = 64'hFFFFFFFF00000000;
        endcase
end
assign rs1Data_o = rs1Data;
assign rs2Data_o = rs2Data;
assign rs3Data_o = rs3Data;

endmodule

