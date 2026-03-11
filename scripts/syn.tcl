##############################################################
## scripts/syn.tcl
## Synopsys DC Synthesis — EE577B Cardinal Mesh NoC
## Design: gold_router (with all sub-modules)
## Clock:  250 MHz  =>  4.0 ns period
## Target: NCSU FreePDK 45nm (gscl45nm)
##
## Run from project root as:
##   make syn DESIGN_NAME=gold_router
## OR:
##   dc_shell-t -f scripts/syn.tcl | tee report/dc_run.log
##############################################################

set design_name $env(DESIGN_NAME)

##############################################################
## 1. Library Setup
##############################################################
set search_path [list . \
    /home/scf-22/ee577/NCSU45PDK/FreePDK45/osu_soc/lib/files]

set target_library   { gscl45nm.db }
set synthetic_library [list dw_foundation.sldb standard.sldb]
set link_library     [list * gscl45nm.db dw_foundation.sldb standard.sldb]

##############################################################
## 2. Read RTL — branch on which design is being synthesized
##############################################################
if { $design_name == "gold_router" } {

    # Read all 5 sub-modules in bottom-up order
    analyze -library work -format verilog {
        ./src/vc_buffer.v
        ./src/rr_arbiter.v
        ./src/input_ctrl.v
        ./src/output_ctrl.v
        ./src/gold_router.v
    }
    elaborate gold_router

} elseif { $design_name == "cardinal_nic" } {

    analyze -library work -format verilog { ./src/cardinal_nic.v }
    elaborate cardinal_nic

} else {
    # Generic single-file fallback
    analyze -library work -format verilog [list ./src/${design_name}.v]
    elaborate $design_name
}

##############################################################
## 3. Clock Constraint — 250 MHz = 4.0 ns period
##############################################################
create_clock -name clk -period 4.0 -waveform {0 2.0} [get_ports clk]

# Conservative I/O delays: 20% of clock period
set_input_delay  0.8 -clock clk [all_inputs]
set_output_delay 0.8 -clock clk [all_outputs]

##############################################################
## 4. Compile Options
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
## 6. Write Netlist + SDF + SDC
##############################################################
write -format verilog -hierarchy \
      -output ./netlist/${design_name}_syn.v

write_sdf -version 2.1 \
          ./netlist/${design_name}_syn.sdf

write_sdc ./netlist/${design_name}_syn.sdc

echo ""
echo "==================================================="
echo " Synthesis COMPLETE: $design_name"
echo "   netlist/${design_name}_syn.v"
echo "   netlist/${design_name}_syn.sdf"
echo "   report/${design_name}.timing"
echo "   report/${design_name}.area"
echo "   report/${design_name}.power"
echo "==================================================="

quit
