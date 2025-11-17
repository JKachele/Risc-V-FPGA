/*************************************************
 *File----------Memory.v
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Saturday Nov 01, 2025 06:47:20 EDT
 *License-------GNU GPL-3.0
 ************************************************/

module Memory (
        input             clk,
        input      [31:0] memAddr,  // Address to be read
        output reg [31:0] memRData, // Data read fomr memory
        input             memRstrb, // Goes high when processor wants to read
        input      [31:0] memWData, // Data to be written to memory
        input      [3:0]  memWMask  // Mask for writing to memory
);

reg [31:0] MEM [0:16383];

initial begin
        $readmemh("../bin/out.hex",MEM);
end

wire [29:0] wordAddr = memAddr[31:2];
always @(posedge clk) begin
        if(memRstrb) begin
                memRData <= MEM[memAddr[31:2]];
        end
        if (memWMask[0]) MEM[wordAddr][ 7:0 ] <= memWData[ 7:0 ];
        if (memWMask[1]) MEM[wordAddr][15:8 ] <= memWData[15:8 ];
        if (memWMask[2]) MEM[wordAddr][23:16] <= memWData[23:16];
        if (memWMask[3]) MEM[wordAddr][31:24] <= memWData[31:24];
end

endmodule

