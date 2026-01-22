/*************************************************
 *File----------testBench.v
 *Project-------Kache-Risc-V
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Thursday Jan 22, 2026 19:30:55 UTC
 ************************************************/

module testBench (
        input wire clk,
        input wire rst
);

reg [63:0] input_a [0:999];
reg [63:0] input_b [0:999];
reg [63:0] input_c [0:999];

initial begin
        $readmemh("stim_a",input_a);
        $readmemh("stim_b",input_b);
        // $readmemh("stim_c",input_c);
end

integer outputFile;
initial begin
        outputFile = $fopen("resp_z", "w");
        $fclose(outputFile);
end

reg [31:0] instr = 32'h02007053; // FADD.D
reg [9:0] index;
reg [63:0] rs1;
reg [63:0] rs2;
reg [63:0] rs3;

wire busy;
wire [63:0] fpuOut;
FPU fpu(
        .clk_i(clk),
        .reset_i(rst),
        .fpuEnable_i(1'b1),
        .instr_i(instr),
        .rs1_i(rs1),
        .rs2_i(rs2),
        .rs3_i(rs3),
        .rm_i(3'b000),
        .fflags_o(),
        .busy_o(busy),
        .fpuOut_o(fpuOut)
);

reg state;
always @(posedge clk) begin
        if (rst == 1'b1) begin
                state <= 0;
                index <= 0;
        end
        else begin
                case(state)
                        0: begin
                                rs1 <= input_a[index];
                                rs2 <= input_b[index];
                                rs3 <= input_c[index];
                                state <= 1;
                        end
                        1: begin
                                $display("%f + %f = %f", rs1, rs2, fpuOut);
                                outputFile = $fopen("resp_z", "a");
                                $fdisplayh(outputFile, fpuOut);
                                $fclose(outputFile);
                                index <= index + 1;
                                if (index == 3)
                                        $finish;
                                state <= 0;
                        end
                endcase
        end
end

endmodule

