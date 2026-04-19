##############################################################################
# sta_run.tcl -- PrimeTime STA for gold_router (Phase 4)
# EE 577B Spring 2026
#
# Input:  ../syn/netlist/gold_router_syn.v
#         ../syn/netlist/gold_router.sdc
# Target: gscl45nm, 250 MHz (4.0 ns)
#
# Usage (from phase4/STA/):
#   source /home/obhatt@vlab.usc.edu/tools/setup_ee577b_v26.csh
#   pt_shell -f scripts/sta_run.tcl | tee logs/sta_run.log
##############################################################################

# ============================================================
# 1. Library setup -- matches new server paths
# ============================================================
set PDK_PATH "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files"

set search_path  [list . ./designs ./libs $PDK_PATH]
set link_path    [list * gscl45nm.db]
set target_library "gscl45nm.db"

# ============================================================
# 2. Read gate-level netlist
# ============================================================
echo "=================================================================="
echo " Step 1/5: Reading gate-level netlist"
echo "=================================================================="
read_verilog ./designs/gold_router_syn.v

# ============================================================
# 3. Set top-level design and link
# ============================================================
echo "=================================================================="
echo " Step 2/5: Linking design"
echo "=================================================================="
current_design gold_router
link_design

# ============================================================
# 4. Apply timing constraints from synthesis SDC
# ============================================================
echo "=================================================================="
echo " Step 3/5: Applying SDC constraints"
echo "=================================================================="
read_sdc ./sdc/gold_router.sdc

# Override clock if SDC is missing or wrong period
# (Phase-1 synthesis used 4.0 ns -- confirm and set explicitly)
if {[sizeof_collection [get_clocks *]] == 0} {
    echo "  No clocks found in SDC -- creating clock manually"
    create_clock -period 4.0 -name clk [get_ports clk]
    set_clock_latency     0.5 [get_clocks clk]
    set_clock_uncertainty 0.1 [get_clocks clk]
    set_input_delay  0.5 -clock clk \
        [remove_from_collection [all_inputs] [get_ports clk]]
    set_output_delay 0.5 -clock clk [all_outputs]
}

# ============================================================
# 5. Timing checks and reports
# ============================================================
echo "=================================================================="
echo " Step 4/5: Running timing analysis"
echo "=================================================================="

# Pre-analysis sanity check
check_timing > ./reports/check_timing.rpt
echo "  check_timing done -- see reports/check_timing.rpt"

# Setup (max delay) -- most important for frequency closure
report_timing \
    -delay_type max \
    -max_paths  20  \
    -nworst      5  \
    -path_type  full_clock \
    > ./reports/timing_setup.rpt

# Hold (min delay)
report_timing \
    -delay_type min \
    -max_paths  10  \
    > ./reports/timing_hold.rpt

# Clock summary
report_clock          > ./reports/clocks.rpt
report_clock  -skew   > ./reports/clock_skew.rpt

# Port delays
report_port -input_delay  > ./reports/ports_input_delay.rpt
report_port -output_delay > ./reports/ports_output_delay.rpt

# Constraint violations
report_constraint -all_violators > ./reports/constraint_violators.rpt

# Global timing summary
report_global_timing > ./reports/global_timing.rpt

# ============================================================
# 6. Summary to stdout
# ============================================================
echo "=================================================================="
echo " Step 5/5: Summary"
echo "=================================================================="
echo ""
echo "  === SETUP TIMING (worst path) ==="
report_timing -delay_type max -max_paths 1 -nworst 1
echo ""
echo "  === HOLD TIMING (worst path) ==="
report_timing -delay_type min -max_paths 1 -nworst 1

echo ""
echo "=================================================================="
echo " STA DONE -- reports in ./reports/"
echo "=================================================================="
echo "  check_timing.rpt       -- constraint coverage"
echo "  timing_setup.rpt       -- setup analysis (WNS must be >= 0)"
echo "  timing_hold.rpt        -- hold analysis"
echo "  clocks.rpt             -- clock definitions"
echo "  constraint_violators   -- any violations"
echo "=================================================================="

# Clean up session
remove_design -all
remove_lib    -all
exit
