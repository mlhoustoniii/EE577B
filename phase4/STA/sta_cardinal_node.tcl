##############################################################################
# sta_cardinal_node.tcl -- PrimeTime STA for cardinal_node (Phase 4)
# EE 577B Spring 2026
#
# Run from ~/577B/project/phase4/STA/
#   pt_shell -f scripts/sta_cardinal_node.tcl |& tee logs/sta_node.log
##############################################################################

# ============================================================
# 1. Libraries (already set in .synopsys_pt.setup but explicit here)
# ============================================================
set search_path [list . ./libs ./designs ./sdc \
    /tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files]
set link_path   [list * gscl45nm.db]

# ============================================================
# 2. Read gate-level netlist
# ============================================================
echo "=== Step 1/5: Reading netlist ==="
read_verilog ./designs/cardinal_node_syn.v

# ============================================================
# 3. Link design
# ============================================================
echo "=== Step 2/5: Linking ==="
current_design cardinal_node
link_design

# ============================================================
# 4. Apply constraints from synthesis SDC
# ============================================================
echo "=== Step 3/5: Applying constraints ==="
read_sdc ./sdc/cardinal_node.sdc

# Fallback: create constraints manually if SDC missing/incomplete
if {[sizeof_collection [get_clocks *]] == 0} {
    echo "  No clocks in SDC -- creating manually"
    create_clock -period 4.0 -name clk [get_ports clk]
    set_clock_latency     0.5  [get_clocks clk]
    set_clock_uncertainty 0.10 [get_clocks clk]
    set_input_delay  0.5 -clock clk \
        [remove_from_collection [all_inputs] [get_ports clk]]
    set_output_delay 0.5 -clock clk [all_outputs]
}

# ============================================================
# 5. Analysis
# ============================================================
echo "=== Step 4/5: Timing analysis ==="

check_timing                                  > ./reports/check_timing.rpt

report_timing \
    -delay_type max \
    -max_paths  20  \
    -nworst      5  \
    -path_type  full_clock \
                                              > ./reports/timing_setup.rpt

report_timing \
    -delay_type min \
    -max_paths  10  \
                                              > ./reports/timing_hold.rpt

report_clock                                  > ./reports/clocks.rpt
report_constraint -all_violators              > ./reports/constraint_violators.rpt
report_global_timing                          > ./reports/global_timing.rpt

# ============================================================
# 6. Summary
# ============================================================
echo "=== Step 5/5: Summary ==="
echo ""
echo "  === SETUP TIMING (worst path) ==="
report_timing -delay_type max -max_paths 1 -nworst 1

echo ""
echo "  === HOLD TIMING (worst path) ==="
report_timing -delay_type min -max_paths 1 -nworst 1

echo ""
echo "=== STA DONE -- reports in ./reports/ ==="

remove_design -all
remove_lib    -all
exit
