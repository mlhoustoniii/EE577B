##############################################################################
# cmp_syn.tcl -- Phase 4, FINAL - True black box memories
# EE 577B Spring 2026
#
# Per Phase 4 README: "blackbox both imem and dmem (set_dont_touch)"
#
# CORRECT APPROACH:
#   imem_syn.v and dmem_syn.v have NO internal logic (empty module bodies).
#   DC cannot propagate constants through modules with no RTL model.
#   This is a true black box -- DC treats all outputs as completely unknown.
#
#   With unknown dataOut from imem:
#   - inst_in[0:31] = unknown -> opcode unknown -> all decode signals unknown
#   - is_load/is_rtype/id_reg_write all non-constant -> pipeline survives
#   - PC, ifid_inst, idex_*, exwb_*, regfile all survive
#
#   With unknown dataOut from dmem:
#   - d_in = unknown -> wb_data unknown -> regfile non-constant -> ALU alive
#
# NOTE: OPT-1318 warns that -no_boundary_optimization does NOT stop
#   constant propagation through modules that HAVE RTL. The only true
#   blackbox is a module with no logic at all.
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
echo " SYNTHESIS DONE -- cardinal_node (Phase 4, FINAL)"
echo " Netlist:  ./netlist/cardinal_node_syn.v"
echo " Area:     ./report/cardinal_node_area.rpt"
echo " Timing:   ./report/cardinal_node_timing.rpt"
echo "==================================================================="
exit
