# Set the target device
set_part        xc7a100tcsg324-1

# Read Design Files
read_verilog    ../src/Seq/SOC.v
read_xdc        ../src/Extern/NexusA7.xdc

# Lint Verilog Code
synth_design -top SOC -lint
exit
