##############################################################################
# cmp_syn.tcl  -- Phase 4, v14 - BOUNDARY OPTIMIZATION DISABLED
# EE 577B Spring 2026
#
# ROOT CAUSE: DC's compile_ultra propagates constants across hierarchy
# boundaries. Since imem outputs FIXED opcodes, DC proves all control
# signals (mem_en, is_load, nicEn etc.) constant and prunes the pipeline.
#
# FIX: set_boundary_optimization false on all sub-instances.
# This forces DC to treat sub-module I/O as potentially varying,
# preventing cross-boundary constant propagation that kills the pipeline.
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
uniquify
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

echo "=== Step 3b: Disable boundary optimization ==="
# Prevent DC from propagating constants across module boundaries.
# Without this, DC sees fixed opcode bits from imem -> proves all
# control signals constant -> prunes the entire CPU pipeline.
set_boundary_optimization [get_cells u_cpu]   false
set_boundary_optimization [get_cells u_nic]   false
set_boundary_optimization [get_cells u_dmem]  false
set_boundary_optimization [get_cells u_imem]  false

check_design > ./report/check_design_pre.rpt

echo "=== Step 4/6: compile_ultra ==="
compile_ultra -no_autoungroup

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
echo " SYNTHESIS DONE -- cardinal_node (Phase 4, v14)"
echo " Netlist:  ./netlist/cardinal_node_syn.v"
echo " Area:     ./report/cardinal_node_area.rpt"
echo " Timing:   ./report/cardinal_node_timing.rpt"
echo "==================================================================="
exit
