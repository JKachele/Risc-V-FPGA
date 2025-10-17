// Defines timescale for simulation: <time_unit> / <time_precision>
`timescale 1 ns / 10 ps

module bench();
reg CLK;
wire RESET = 0; 
wire [7:0] LEDS;
reg  RXD = 1'b0;
wire TXD;

SOC uut(
        .CLK(CLK),
        .RESET(RESET),
        .LEDS(LEDS),
        .RXD(RXD),
        .TXD(TXD)
);

reg[7:0] prev_LEDS = 0;
initial begin
        CLK = 0;
        forever begin
                #1 CLK = ~CLK;
                if(LEDS != prev_LEDS) begin
                        $display("LEDS = %b",LEDS);
                end
                prev_LEDS <= LEDS;
        end
end
endmodule   

