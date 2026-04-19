##############################################################
## syn_gold_router_torus.tcl
## Synopsys DC Synthesis -- gold_router_torus
## EE577B Cardinal Mesh NoC -- torus comparison variant
##
## Torus routing: 2-bit modular subtraction per port
## Packet passes through unchanged (no hop-shift logic)
## All edge ports have wrap-around links (no tied-off inputs)
##
## COMPARISON TARGET: run alongside gold_router and
## gold_router_xystd synthesis for 3-way PPA comparison.
##
## Expected vs xystd: slightly smaller routing logic
##   (2-bit subtractor < 8-bit comparator per input port)
## Expected vs hop:   no hop-shift adder in output_ctrl
##
## Run from project root (v3/ directory):
##   cp design/vc_buffer.v            src/
##   cp design/rr_arbiter.v           src/
##   cp design/input_ctrl_torus.v     src/
##   cp design/output_ctrl_torus.v    src/
##   cp design/gold_router_torus.v    src/
##   dc_shell-t -f scripts/syn_gold_router_torus.tcl | tee report/torus_syn.log
##############################################################

set design_name gold_router_torus

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
    ./src/input_ctrl_torus.v
    ./src/output_ctrl_torus.v
    ./src/gold_router_torus.v
}

## Note: gold_router_torus has parameters ROUTER_X/ROUTER_Y.
## DC elaborates with default values (0,0).
## The routing logic synthesizes identically for any (X,Y) --
## the 2-bit subtractor gates are the same size regardless of
## which constant ROUTER_X/Y is folded in at elaboration.
## All 16 mesh instances map to the same synthesized netlist.
elaborate gold_router_torus

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
echo " Synthesis COMPLETE: gold_router_torus"
echo ""
echo " 3-way PPA comparison (from project root):"
echo "   python3 ppa3_compare.py"
echo "==================================================="

quit
