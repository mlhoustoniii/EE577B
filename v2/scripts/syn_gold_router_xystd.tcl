##############################################################
## syn_gold_router_xystd.tcl
## Synopsys DC Synthesis -- gold_router_xystd
## EE577B Cardinal Mesh NoC -- xystd comparison variant
##
## Standard XY routing: coordinate-comparison at each router
## No hop-shift logic, but adds 8-bit comparators per router
##
## COMPARISON TARGET: run alongside gold_router synthesis
## to compare area, power, critical path between:
##   - gold_router      (hop-based: shift logic, no coords)
##   - gold_router_xystd (coord-based: comparators, no shift)
##
## Run from project root:
##   cp design/vc_buffer.v    src/
##   cp design/rr_arbiter.v   src/
##   cp design/input_ctrl_xystd.v   src/
##   cp design/output_ctrl_xystd.v  src/
##   cp design/gold_router_xystd.v  src/
##   dc_shell-t -f scripts/syn_gold_router_xystd.tcl | tee report/xystd_syn.log
##############################################################

set design_name gold_router_xystd

##############################################################
## 1. Library Setup
##############################################################
set search_path [list . \
    /home/scf-22/ee577/NCSU45PDK/FreePDK45/osu_soc/lib/files]

set target_library   { gscl45nm.db }
set synthetic_library [list dw_foundation.sldb standard.sldb]
set link_library     [list * gscl45nm.db dw_foundation.sldb standard.sldb]

##############################################################
## 2. Read RTL (bottom-up order: shared primitives first)
##############################################################
analyze -library work -format verilog {
    ./src/vc_buffer.v
    ./src/rr_arbiter.v
    ./src/input_ctrl_xystd.v
    ./src/output_ctrl_xystd.v
    ./src/gold_router_xystd.v
}

## Note: gold_router_xystd has parameters ROUTER_X/ROUTER_Y
## DC elaborates with default values (0,0) for single-instance synth.
## Area/power results are per-router and valid for comparison since
## all 16 mesh instances synthesize to the same netlist (parameters
## only affect constants folded into routing logic at compile time --
## comparators are same size for any X,Y value).
elaborate gold_router_xystd

##############################################################
## 3. Clock Constraint -- 250 MHz = 4.0 ns period
##############################################################
create_clock -name clk -period 4.0 -waveform {0 2.0} [get_ports clk]

set_input_delay  0.8 -clock clk [all_inputs]
set_output_delay 0.8 -clock clk [all_outputs]

##############################################################
## 4. Compile
##############################################################
set_max_area 0
set_flatten  false
set_structure true

check_design > ./report/${design_name}.check_design
compile -map_effort medium

##############################################################
## 5. Reports
##############################################################
report_timing > ./report/${design_name}.timing
report_area   > ./report/${design_name}.area
report_power  > ./report/${design_name}.power

##############################################################
## 6. Write Outputs
##############################################################
write -format verilog -hierarchy \
      -output ./netlist/${design_name}_syn.v

write_sdf -version 2.1 \
          ./netlist/${design_name}_syn.sdf

write_sdc ./netlist/${design_name}_syn.sdc

echo ""
echo "==================================================="
echo " Synthesis COMPLETE: gold_router_xystd"
echo ""
echo " Compare with gold_router results:"
echo "   diff report/gold_router.area  report/gold_router_xystd.area"
echo "   diff report/gold_router.power report/gold_router_xystd.power"
echo "==================================================="

quit
