# Set the target device
set_part        xc7a100tcsg324-1

# Read Design Files
read_verilog    ../src/Seq/SOC.v
read_xdc        ../src/Extern/NexusA7.xdc

# Synthesize the design and write synthesis report
synth_design             -top SOC
write_checkpoint         -force ./reports/post_synth
report_timing_summary    -file ./reports/post_synth_timing_summary.rpt
report_power             -file ./reports/post_synth_power.rpt
report_clock_interaction -delay_type min_max -file ./reports/post_synth_clock_interaction.rpt
report_high_fanout_nets  -fanout_greater_than 200 -max_nets 50 -file ./reports/post_synth_high_fanout_nets.rpt

# PLace the design and write the placement report
opt_design
place_design
phys_opt_design
write_checkpoint         -force ./reports/post_place
report_timing_summary    -file ./reports/post_place_timing_summary.rpt

# Route the design and write the routing report
route_design
write_checkpoint         -force ./reports/post_route
report_timing_summary    -file ./reports/post_route_timing_summary.rpt
report_timing            -sort_by group -max_paths 100 -path_type summary -file ./reports/post_route_timing.rpt
report_clock_utilization -file ./reports/clock_util.rpt
report_utilization       -file ./reports/post_route_util.rpt
report_power             -file ./reports/post_route_power.rpt
report_drc               -file ./reports/post_imp_drc.rpt

# Write the bitstream file
write_bitstream -force -bin_file ../bin/SOC.bit
exit
