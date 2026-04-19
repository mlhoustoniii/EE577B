##############################################################################
# cmp_syn.tcl -- Phase 4, FINAL FAST - No uniquify, compile not compile_ultra
# EE 577B Spring 2026
#
# KEY CHANGES per TA discussion (4/10/2026):
#   1. REMOVED uniquify -- was causing DC to optimize each of 16 instances
#      separately, making synthesis 16x+ slower. Delete it.
#   2. REPLACED compile_ultra with compile -- much faster, sufficient quality
#      for Phase 4 deliverable.
#   3. True black box imem/dmem (empty module bodies) -- DC treats outputs
#      as completely unknown, full pipeline survives.
##############################################################################

set PDK_PATH "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files"

set search_path    [list . ./design ./include $PDK_PATH]
set target_library "gscl45nm.db"
set link_library   [list * gscl45nm.db]

set TOP       "cardinal_node"
set CLK_PORT  "clk"

set RTL_FILES [list \
    rr_arbiter.v      \
    vc_buffer.v       \
    input_ctrl.v      \
    output_ctrl.v     \
    cardinal_router.v \
    cardinal_nic.v    \
    IF.v              \
    id_stage.v        \
    ex_mem_stage.v    \
    cardinal_cpu.v    \
    imem_syn.v        \
    dmem_syn.v        \
    cardinal_node.v   \
]

echo "=== Step 1/6: Analyze ==="
foreach f $RTL_FILES {
    analyze -format verilog -lib WORK ./design/$f
}

echo "=== Step 2/6: Elaborate ==="
elaborate $TOP -lib WORK
# NOTE: uniquify REMOVED per TA guidance -- it caused 16x slowdown
#       by optimizing each instance separately
current_design $TOP
link

echo "=== Step 3/6: Constraints (4.0 ns / 250 MHz) ==="
create_clock -period 4.0 -name $CLK_PORT [get_ports $CLK_PORT]
set_clock_uncertainty  0.10  [get_clocks $CLK_PORT]
set_clock_latency      0.5   [get_clocks $CLK_PORT]
set_input_delay  0.5 -clock $CLK_PORT \
    [remove_from_collection [all_inputs] [get_ports $CLK_PORT]]
set_output_delay 0.5 -clock $CLK_PORT [all_outputs]
set_max_fanout     8   [current_design]
set_max_transition 0.5 [current_design]

check_design > ./report/check_design_pre.rpt

echo "=== Step 4/6: compile ==="
# compile (not compile_ultra) -- faster, sufficient for Phase 4
compile

echo "=== Step 5/6: Write outputs ==="
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output ./netlist/${TOP}_syn.v
write_sdc   ./netlist/${TOP}.sdc
write_sdf   ./netlist/${TOP}.sdf

echo "=== Step 6/6: Reports ==="
report_timing     -max_paths 20 -nworst 5  > ./report/${TOP}_timing.rpt
report_timing     -delay_type min           > ./report/${TOP}_timing_hold.rpt
report_area       -hierarchy                > ./report/${TOP}_area.rpt
report_power      -hierarchy                > ./report/${TOP}_power.rpt
report_constraint -all_violators            > ./report/${TOP}_constraints.rpt
report_qor                                   > ./report/${TOP}_qor.rpt
report_reference  -hierarchy                 > ./report/${TOP}_reference.rpt
check_design                                 > ./report/check_design_post.rpt

echo ""
echo "==================================================================="
echo " SYNTHESIS DONE -- cardinal_node (Phase 4, FINAL FAST)"
echo " Netlist:  ./netlist/cardinal_node_syn.v"
echo " Area:     ./report/cardinal_node_area.rpt"
echo " Timing:   ./report/cardinal_node_timing.rpt"
echo "==================================================================="
exit
