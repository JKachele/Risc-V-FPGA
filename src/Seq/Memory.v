/*************************************************
 *File----------Memory.v
 *Project-------Risc-V-FPGA
 *License-------GNU GPL-3.0
 *Author--------Justin Kachele
 *Created-------Monday Nov 17, 2025 20:59:49 UTC
 ************************************************/

module Memory (
        input  wire        clk,
        // input  wire [31:0] progRomAddr,
        // output reg  [31:0] progRomData,
        input  wire [31:0] memAddr,  // Address to be read
        output reg  [31:0] memRData, // Data read from memory
        input  wire        memRstrb, // Goes high when processor wants to read
        input  wire [31:0] memWData, // Data to be written to memory
        input  wire [3:0]  memWMask  // Mask for writing to memory
);

// reg [31:0] PROGROM [0:16383];
reg [31:0] DATARAM [0:16383];

initial begin
        // $readmemh("../bin/program.hex",PROGROM);
        $readmemh("../bin/RAM.hex",DATARAM);
        // progRomData <= PROGROM[0];
end

wire [29:0] wordAddr = memAddr[31:2];
always @(posedge clk) begin
        // progRomData <= PROGROM[progRomAddr[31:2]];
        if(memRstrb) begin
                memRData <= DATARAM[memAddr[31:2]];
        end
        if (memWMask[0]) DATARAM[wordAddr][ 7:0 ] <= memWData[ 7:0 ];
        if (memWMask[1]) DATARAM[wordAddr][15:8 ] <= memWData[15:8 ];
        if (memWMask[2]) DATARAM[wordAddr][23:16] <= memWData[23:16];
        if (memWMask[3]) DATARAM[wordAddr][31:24] <= memWData[31:24];
end

endmodule

