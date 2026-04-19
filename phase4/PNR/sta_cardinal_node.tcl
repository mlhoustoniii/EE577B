# STA flow for Phase 4 cardinal_node
# Run from: ~/577B/project/phase4/STA

set TOP            cardinal_node
set CLK_NAME       CLK
set CLK_PERIOD     4.0
set CLK_LATENCY    0.5
set IN_DELAY       0.5
set OUT_DELAY      0.5

# Prefer local project libraries first
set search_path [list . ./designs ./libs ../PNR/output ../PNR/lib]
set target_library [list ./libs/gscl45nm.db]
set link_library   [concat "*" $target_library]

file mkdir reports
file mkdir logs

puts "=== Read Design ==="
read_verilog ../PNR/output/cardinal_node_routed.v
current_design $TOP
link_design

puts "=== Create Clock ==="
create_clock -period $CLK_PERIOD -name $CLK_NAME [get_ports clk]
set_clock_latency $CLK_LATENCY [get_clocks $CLK_NAME]

puts "=== Apply IO Delays ==="
set data_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay $IN_DELAY -clock $CLK_NAME $data_inputs
set_output_delay $OUT_DELAY -clock $CLK_NAME [all_outputs]

puts "=== Basic Timing Checks ==="
redirect -file ./reports/report_clock_skew.rpt {
    report_clock -skew
}
redirect -file ./reports/report_port_input_delay.rpt {
    report_port -input_delay
}
redirect -file ./reports/report_port_output_delay.rpt {
    report_port -output_delay
}
redirect -file ./reports/check_timing.rpt {
    check_timing
}
redirect -file ./reports/report_timing_max.rpt {
    report_timing -delay_type max -max_paths 10 -slack_lesser_than 0 -input_pins -nets
}

puts "=== Done: reports written to ./reports ==="

# Optional cleanup (uncomment if you want the script to close the session itself)
# remove_design -all
# remove_lib -all
# exit
