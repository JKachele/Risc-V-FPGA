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
        input  wire [31:0] rdData_i,
        input  wire [5:0]  rs1Id_i,
        input  wire [5:0]  rs2Id_i,
        output wire [31:0] rs1Data_o,
        output wire [31:0] rs2Data_o
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
reg [31:0] reg_F1;
reg [31:0] reg_F2;
reg [31:0] reg_F3;
reg [31:0] reg_F4;
reg [31:0] reg_F5;
reg [31:0] reg_F6;
reg [31:0] reg_F7;
reg [31:0] reg_F8;
reg [31:0] reg_F9;
reg [31:0] reg_F10;
reg [31:0] reg_F11;
reg [31:0] reg_F12;
reg [31:0] reg_F13;
reg [31:0] reg_F14;
reg [31:0] reg_F15;
reg [31:0] reg_F16;
reg [31:0] reg_F17;
reg [31:0] reg_F18;
reg [31:0] reg_F19;
reg [31:0] reg_F20;
reg [31:0] reg_F21;
reg [31:0] reg_F22;
reg [31:0] reg_F23;
reg [31:0] reg_F24;
reg [31:0] reg_F25;
reg [31:0] reg_F26;
reg [31:0] reg_F27;
reg [31:0] reg_F28;
reg [31:0] reg_F29;
reg [31:0] reg_F30;
reg [31:0] reg_F31;

// ABI Register Names
wire [31:0] x0_zero = 32'b0;
wire [31:0] x1_ra   = reg_1;
wire [31:0] x2_sp   = reg_2;
wire [31:0] x3_gp   = reg_3;
wire [31:0] x4_tp   = reg_4;
wire [31:0] x5_t0   = reg_5;
wire [31:0] x6_t1   = reg_6;
wire [31:0] x7_t2   = reg_7;
wire [31:0] x8_s0   = reg_8;
wire [31:0] x9_s1   = reg_9;
wire [31:0] x10_a0  = reg_10;
wire [31:0] x11_a1  = reg_11;
wire [31:0] x12_a2  = reg_12;
wire [31:0] x13_a3  = reg_13;
wire [31:0] x14_a4  = reg_14;
wire [31:0] x15_a5  = reg_15;
wire [31:0] x16_a6  = reg_16;
wire [31:0] x17_a7  = reg_17;
wire [31:0] x18_s2  = reg_18;
wire [31:0] x19_s3  = reg_19;
wire [31:0] x20_s4  = reg_20;
wire [31:0] x21_s5  = reg_21;
wire [31:0] x22_s6  = reg_22;
wire [31:0] x23_s7  = reg_23;
wire [31:0] x24_s8  = reg_24;
wire [31:0] x25_s9  = reg_25;
wire [31:0] x26_s10 = reg_26;
wire [31:0] x27_s11 = reg_27;
wire [31:0] x28_t3  = reg_28;
wire [31:0] x29_t4  = reg_29;
wire [31:0] x30_t5  = reg_30;
wire [31:0] x31_t6  = reg_31;

// Synchronus Register Writeback
always @ (posedge clk_i) begin
        if (reset_i) begin
                reg_1   <= 32'h00000000;
                reg_2   <= 32'h00000000;
                reg_3   <= 32'h00000000;
                reg_4   <= 32'h00000000;
                reg_5   <= 32'h00000000;
                reg_6   <= 32'h00000000;
                reg_7   <= 32'h00000000;
                reg_8   <= 32'h00000000;
                reg_9   <= 32'h00000000;
                reg_10  <= 32'h00000000;
                reg_11  <= 32'h00000000;
                reg_12  <= 32'h00000000;
                reg_13  <= 32'h00000000;
                reg_14  <= 32'h00000000;
                reg_15  <= 32'h00000000;
                reg_16  <= 32'h00000000;
                reg_17  <= 32'h00000000;
                reg_18  <= 32'h00000000;
                reg_19  <= 32'h00000000;
                reg_20  <= 32'h00000000;
                reg_21  <= 32'h00000000;
                reg_22  <= 32'h00000000;
                reg_23  <= 32'h00000000;
                reg_24  <= 32'h00000000;
                reg_25  <= 32'h00000000;
                reg_26  <= 32'h00000000;
                reg_27  <= 32'h00000000;
                reg_28  <= 32'h00000000;
                reg_29  <= 32'h00000000;
                reg_30  <= 32'h00000000;
                reg_31  <= 32'h00000000;
                reg_F1  <= 32'h00000000;
                reg_F2  <= 32'h00000000;
                reg_F3  <= 32'h00000000;
                reg_F4  <= 32'h00000000;
                reg_F5  <= 32'h00000000;
                reg_F6  <= 32'h00000000;
                reg_F7  <= 32'h00000000;
                reg_F8  <= 32'h00000000;
                reg_F9  <= 32'h00000000;
                reg_F10 <= 32'h00000000;
                reg_F11 <= 32'h00000000;
                reg_F12 <= 32'h00000000;
                reg_F13 <= 32'h00000000;
                reg_F14 <= 32'h00000000;
                reg_F15 <= 32'h00000000;
                reg_F16 <= 32'h00000000;
                reg_F17 <= 32'h00000000;
                reg_F18 <= 32'h00000000;
                reg_F19 <= 32'h00000000;
                reg_F20 <= 32'h00000000;
                reg_F21 <= 32'h00000000;
                reg_F22 <= 32'h00000000;
                reg_F23 <= 32'h00000000;
                reg_F24 <= 32'h00000000;
                reg_F25 <= 32'h00000000;
                reg_F26 <= 32'h00000000;
                reg_F27 <= 32'h00000000;
                reg_F28 <= 32'h00000000;
                reg_F29 <= 32'h00000000;
                reg_F30 <= 32'h00000000;
                reg_F31 <= 32'h00000000;
        end else if (rdId_i[5] == 1'b0) begin
                if (rdId_i[4:0] == 5'd1)  reg_1  <= rdData_i;
                if (rdId_i[4:0] == 5'd2)  reg_2  <= rdData_i;
                if (rdId_i[4:0] == 5'd3)  reg_3  <= rdData_i;
                if (rdId_i[4:0] == 5'd4)  reg_4  <= rdData_i;
                if (rdId_i[4:0] == 5'd5)  reg_5  <= rdData_i;
                if (rdId_i[4:0] == 5'd6)  reg_6  <= rdData_i;
                if (rdId_i[4:0] == 5'd7)  reg_7  <= rdData_i;
                if (rdId_i[4:0] == 5'd8)  reg_8  <= rdData_i;
                if (rdId_i[4:0] == 5'd9)  reg_9  <= rdData_i;
                if (rdId_i[4:0] == 5'd10) reg_10 <= rdData_i;
                if (rdId_i[4:0] == 5'd11) reg_11 <= rdData_i;
                if (rdId_i[4:0] == 5'd12) reg_12 <= rdData_i;
                if (rdId_i[4:0] == 5'd13) reg_13 <= rdData_i;
                if (rdId_i[4:0] == 5'd14) reg_14 <= rdData_i;
                if (rdId_i[4:0] == 5'd15) reg_15 <= rdData_i;
                if (rdId_i[4:0] == 5'd16) reg_16 <= rdData_i;
                if (rdId_i[4:0] == 5'd17) reg_17 <= rdData_i;
                if (rdId_i[4:0] == 5'd18) reg_18 <= rdData_i;
                if (rdId_i[4:0] == 5'd19) reg_19 <= rdData_i;
                if (rdId_i[4:0] == 5'd20) reg_20 <= rdData_i;
                if (rdId_i[4:0] == 5'd21) reg_21 <= rdData_i;
                if (rdId_i[4:0] == 5'd22) reg_22 <= rdData_i;
                if (rdId_i[4:0] == 5'd23) reg_23 <= rdData_i;
                if (rdId_i[4:0] == 5'd24) reg_24 <= rdData_i;
                if (rdId_i[4:0] == 5'd25) reg_25 <= rdData_i;
                if (rdId_i[4:0] == 5'd26) reg_26 <= rdData_i;
                if (rdId_i[4:0] == 5'd27) reg_27 <= rdData_i;
                if (rdId_i[4:0] == 5'd28) reg_28 <= rdData_i;
                if (rdId_i[4:0] == 5'd29) reg_29 <= rdData_i;
                if (rdId_i[4:0] == 5'd30) reg_30 <= rdData_i;
                if (rdId_i[4:0] == 5'd31) reg_31 <= rdData_i;
        end else begin
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
reg [31:0] rs1Data;
reg [31:0] rs2Data;
always @(*) begin
        case (rs1Id_i[4:0])
                5'd1:  rs1Data = rs1Id_i[5] ? reg_F1  : reg_1;
                5'd2:  rs1Data = rs1Id_i[5] ? reg_F2  : reg_2;
                5'd3:  rs1Data = rs1Id_i[5] ? reg_F3  : reg_3;
                5'd4:  rs1Data = rs1Id_i[5] ? reg_F4  : reg_4;
                5'd5:  rs1Data = rs1Id_i[5] ? reg_F5  : reg_5;
                5'd6:  rs1Data = rs1Id_i[5] ? reg_F6  : reg_6;
                5'd7:  rs1Data = rs1Id_i[5] ? reg_F7  : reg_7;
                5'd8:  rs1Data = rs1Id_i[5] ? reg_F8  : reg_8;
                5'd9:  rs1Data = rs1Id_i[5] ? reg_F9  : reg_9;
                5'd10: rs1Data = rs1Id_i[5] ? reg_F10 : reg_10;
                5'd11: rs1Data = rs1Id_i[5] ? reg_F11 : reg_11;
                5'd12: rs1Data = rs1Id_i[5] ? reg_F12 : reg_12;
                5'd13: rs1Data = rs1Id_i[5] ? reg_F13 : reg_13;
                5'd14: rs1Data = rs1Id_i[5] ? reg_F14 : reg_14;
                5'd15: rs1Data = rs1Id_i[5] ? reg_F15 : reg_15;
                5'd16: rs1Data = rs1Id_i[5] ? reg_F16 : reg_16;
                5'd17: rs1Data = rs1Id_i[5] ? reg_F17 : reg_17;
                5'd18: rs1Data = rs1Id_i[5] ? reg_F18 : reg_18;
                5'd19: rs1Data = rs1Id_i[5] ? reg_F19 : reg_19;
                5'd20: rs1Data = rs1Id_i[5] ? reg_F20 : reg_20;
                5'd21: rs1Data = rs1Id_i[5] ? reg_F21 : reg_21;
                5'd22: rs1Data = rs1Id_i[5] ? reg_F22 : reg_22;
                5'd23: rs1Data = rs1Id_i[5] ? reg_F23 : reg_23;
                5'd24: rs1Data = rs1Id_i[5] ? reg_F24 : reg_24;
                5'd25: rs1Data = rs1Id_i[5] ? reg_F25 : reg_25;
                5'd26: rs1Data = rs1Id_i[5] ? reg_F26 : reg_26;
                5'd27: rs1Data = rs1Id_i[5] ? reg_F27 : reg_27;
                5'd28: rs1Data = rs1Id_i[5] ? reg_F28 : reg_28;
                5'd29: rs1Data = rs1Id_i[5] ? reg_F29 : reg_29;
                5'd30: rs1Data = rs1Id_i[5] ? reg_F30 : reg_30;
                5'd31: rs1Data = rs1Id_i[5] ? reg_F31 : reg_31;
                default: rs1Data = 32'h00000000;
        endcase

        case (rs2Id_i[4:0])
                5'd1:  rs2Data = rs2Id_i[5] ? reg_F1  : reg_1;
                5'd2:  rs2Data = rs2Id_i[5] ? reg_F2  : reg_2;
                5'd3:  rs2Data = rs2Id_i[5] ? reg_F3  : reg_3;
                5'd4:  rs2Data = rs2Id_i[5] ? reg_F4  : reg_4;
                5'd5:  rs2Data = rs2Id_i[5] ? reg_F5  : reg_5;
                5'd6:  rs2Data = rs2Id_i[5] ? reg_F6  : reg_6;
                5'd7:  rs2Data = rs2Id_i[5] ? reg_F7  : reg_7;
                5'd8:  rs2Data = rs2Id_i[5] ? reg_F8  : reg_8;
                5'd9:  rs2Data = rs2Id_i[5] ? reg_F9  : reg_9;
                5'd10: rs2Data = rs2Id_i[5] ? reg_F10 : reg_10;
                5'd11: rs2Data = rs2Id_i[5] ? reg_F11 : reg_11;
                5'd12: rs2Data = rs2Id_i[5] ? reg_F12 : reg_12;
                5'd13: rs2Data = rs2Id_i[5] ? reg_F13 : reg_13;
                5'd14: rs2Data = rs2Id_i[5] ? reg_F14 : reg_14;
                5'd15: rs2Data = rs2Id_i[5] ? reg_F15 : reg_15;
                5'd16: rs2Data = rs2Id_i[5] ? reg_F16 : reg_16;
                5'd17: rs2Data = rs2Id_i[5] ? reg_F17 : reg_17;
                5'd18: rs2Data = rs2Id_i[5] ? reg_F18 : reg_18;
                5'd19: rs2Data = rs2Id_i[5] ? reg_F19 : reg_19;
                5'd20: rs2Data = rs2Id_i[5] ? reg_F20 : reg_20;
                5'd21: rs2Data = rs2Id_i[5] ? reg_F21 : reg_21;
                5'd22: rs2Data = rs2Id_i[5] ? reg_F22 : reg_22;
                5'd23: rs2Data = rs2Id_i[5] ? reg_F23 : reg_23;
                5'd24: rs2Data = rs2Id_i[5] ? reg_F24 : reg_24;
                5'd25: rs2Data = rs2Id_i[5] ? reg_F25 : reg_25;
                5'd26: rs2Data = rs2Id_i[5] ? reg_F26 : reg_26;
                5'd27: rs2Data = rs2Id_i[5] ? reg_F27 : reg_27;
                5'd28: rs2Data = rs2Id_i[5] ? reg_F28 : reg_28;
                5'd29: rs2Data = rs2Id_i[5] ? reg_F29 : reg_29;
                5'd30: rs2Data = rs2Id_i[5] ? reg_F30 : reg_30;
                5'd31: rs2Data = rs2Id_i[5] ? reg_F31 : reg_31;
                default: rs2Data = 32'h00000000;
        endcase
end
assign rs1Data_o = rs1Data;
assign rs2Data_o = rs2Data;

endmodule

