# Set the target device
set_part        xc7a100tcsg324-1

if { $argc < 1 } {
        puts "Usage: vivado -mode batch -source run_vivado.tcl -- <verilog files>"
        exit 1
}

# Read Design Files
foreach filename $argv {
        set fullpath "$filename"
        if { ![file exists $fullpath] } {
                puts "ERROR: File '$fullpath' does not exist."
                exit 2
        }
        puts "Reading Verilog file: $fullpath"
        read_verilog $fullpath
}
read_xdc        src/Extern/ArtyA7.xdc

# Lint Verilog Code
synth_design -top SOC -lint
exit
