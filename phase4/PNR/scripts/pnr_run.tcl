##############################################################################
# pnr_run.tcl -- Cadence Innovus Place-and-Route for gold_router (Phase 4)
# EE 577B Spring 2026
#
# This script performs the complete PNR flow on the gold_router gate-level
# netlist produced by Phase-1 Design Compiler synthesis.
#
# Usage:
#   (Option A -- GUI first, then save script):
#     Launch Innovus GUI, run steps manually, then:
#     Tools -> Write Tcl Script -> save as scripts/pnr_run.tcl
#
#   (Option B -- batch):
#     innovus -files scripts/pnr_run.tcl -no_gui | tee logs/pnr_run.log
#
# The GUI flow (per Innovus_setup.pdf) is recommended for screenshots.
# This script documents every step for the report.
##############################################################################

# ============================================================
# 0. Environment -- set relative paths
# ============================================================
set NETLIST  "./netlist/gold_router_syn.v"
set SDC      "./sdc/gold_router.sdc"
set LEF      "./lib/gscl45nm.lef"
set TLF      "./lib/gscl45nm.tlf"
set TOP      "gold_router"

# ============================================================
# 1. Import Design
#    GUI equivalent: File -> Import Design
# ============================================================
puts "=== Step 1: Import Design ==="

# Read the gate-level Verilog netlist
read_netlist $NETLIST -top $TOP

# Read the timing library (TLF format for Innovus)
read_timing_lib $TLF

# Read the physical library (LEF)
read_lef $LEF

# Apply timing constraints
read_sdc $SDC

# Commit the design -- finalizes the import
commit_design

puts "=== Import complete ==="

# ============================================================
# 2. Floorplan
#    GUI equivalent: Floorplan -> Specify Floorplan
#
#    Target: ~70% utilization
#    gold_router area = 30,135 um^2
#    At 70% utilization: core_area = 30,135 / 0.70 = 43,050 um^2
#    Square core: sqrt(43,050) = ~207 um per side
#    With 5um IO boundary: die = 217 x 217 um
#
#    Start conservative at 250x250 core, iterate down.
# ============================================================
puts "=== Step 2: Floorplan ==="

floorPlan \
    -su 1.0 \
    -coreMarginsBy die \
    -site CoreSite \
    -d 260 260 5 5 5 5

# Verify floorplan
puts "Floorplan set: 260x260 um die, 5um margins"
puts "Core area: 250x250 = 62,500 um^2 (target utilization ~48% -- will shrink)"

# ============================================================
# 3. Power Planning
#    GUI equivalent: Power -> Add Rings / Add Stripes
# ============================================================
puts "=== Step 3: Power Planning ==="

# Add power/ground rings around the core
addRing \
    -nets {VDD GND} \
    -type core_rings \
    -follow core \
    -layer_top    metal3 \
    -layer_bottom metal3 \
    -layer_left   metal2 \
    -layer_right  metal2 \
    -width 2 \
    -spacing 1

# Add VDD/GND stripes across the core
addStripe \
    -nets {VDD GND} \
    -layer metal3 \
    -direction horizontal \
    -width 1 \
    -spacing 1 \
    -set_to_set_distance 20 \
    -start_from bottom \
    -switch_layer_over_obs false \
    -max_same_layer_jog_length 2 \
    -padcore_ring_top_layer_limit metal3 \
    -padcore_ring_bottom_layer_limit metal1

# Connect std-cell power rails to the rings
sroute \
    -connect {corePin} \
    -layerChangeRange {metal1 metal3} \
    -blockPinTarget {nearestTarget} \
    -corePinTarget {firstAfterRowEnd} \
    -allowJogging 1 \
    -crossoverViaLayerRange {metal1 metal3} \
    -allowLayerChange 1 \
    -targetViaLayerRange {metal1 metal3}

puts "Power planning complete"

# ============================================================
# 4. Placement
#    GUI equivalent: Place -> Place Standard Cells
# ============================================================
puts "=== Step 4: Placement ==="

# Set placement options
setPlaceMode \
    -fp false \
    -maxRouteLayer 6

# Run placement (includes trial routing)
place_design

# Report utilization
set util [dbGet top.fPlan.effectiveCoreUtil]
puts "Core utilization after placement: $util"

# Save a floorplan checkpoint
saveFPlan ./output/gold_router_placed.fp

puts "Placement complete"

# ============================================================
# 5. Pre-CTS timing optimization (optional but recommended)
# ============================================================
puts "=== Step 5: Pre-CTS Optimization ==="

setOptMode \
    -fixCap true \
    -fixTran true \
    -fixFanoutLoad false

optDesign -preCTS

puts "Pre-CTS optimization complete"

# ============================================================
# 6. Clock Tree Synthesis
#    GUI equivalent: (uses CCOpt per innovus_cts.pdf)
# ============================================================
puts "=== Step 6: Clock Tree Synthesis ==="

# Create CCOpt clock tree spec from SDC constraints
create_ccopt_clock_tree_spec

# Run CCOpt-CTS (global skew balanced, recommended engine)
ccopt_design -cts

# Report CTS results
report_ccopt_clock_trees    -filename ./reports/cts_trees.rpt
report_ccopt_skew_groups    -filename ./reports/cts_skew.rpt

puts "CTS complete -- see reports/cts_trees.rpt and reports/cts_skew.rpt"

# ============================================================
# 7. Post-CTS timing optimization
# ============================================================
puts "=== Step 7: Post-CTS Optimization ==="

setOptMode \
    -fixCap true \
    -fixTran true \
    -fixFanoutLoad false

optDesign -postCTS
optDesign -postCTS -hold

puts "Post-CTS optimization complete"

# ============================================================
# 8. Routing
#    GUI equivalent: Route -> NanoRoute -> Route
# ============================================================
puts "=== Step 8: Routing (NanoRoute) ==="

setNanoRouteMode \
    -routeWithTimingDriven true \
    -routeWithSiDriven false \
    -routeTopRoutingLayer 6 \
    -routeBottomRoutingLayer 1 \
    -drouteFixAntenna true

routeDesign

puts "Routing complete"

# ============================================================
# 9. Post-route optimization
# ============================================================
puts "=== Step 9: Post-route Optimization ==="

setOptMode \
    -fixCap true \
    -fixTran true \
    -fixFanoutLoad false

optDesign -postRoute
optDesign -postRoute -hold

puts "Post-route optimization complete"

# ============================================================
# 10. Verification
# ============================================================
puts "=== Step 10: Verification ==="

verify_drc         -report ./reports/drc.rpt
verify_connectivity -report ./reports/connectivity.rpt

puts "Verification complete -- check reports/drc.rpt for violations"

# ============================================================
# 11. Timing Analysis
# ============================================================
puts "=== Step 11: Post-route Timing ==="

timeDesign -postRoute         -reportdir ./reports -prefix postRoute
timeDesign -postRoute -hold   -reportdir ./reports -prefix postRoute_hold

# Power analysis
report_power -outfile ./reports/power_postroute.rpt

puts "Timing and power reports written"

# ============================================================
# 12. Save and Export
# ============================================================
puts "=== Step 12: Save and Export ==="

# Save Innovus session
saveDesign ./output/gold_router_pnr.enc

# Export routed Verilog netlist
saveNetlist ./output/gold_router_routed.v

# Export DEF
defOut ./output/gold_router_routed.def

# Export SPEF (parasitic data for sign-off STA)
rcOut \
    -spef ./output/gold_router_routed.spef \
    -rc_corner typical

# Export GDS (final layout)
streamOut ./output/gold_router_routed.gds \
    -mapFile ./lib/gscl45nm.map \
    -libName  gscl45nm \
    -units    2000 \
    -mode     ALL

puts ""
puts "=================================================================="
puts " PNR COMPLETE -- outputs in ./output/"
puts "=================================================================="
puts "  gold_router_pnr.enc       -- Innovus session (reload to continue)"
puts "  gold_router_routed.v      -- routed gate-level Verilog"
puts "  gold_router_routed.def    -- physical layout (DEF)"
puts "  gold_router_routed.spef   -- parasitic data for sign-off STA"
puts "  gold_router_routed.gds    -- final GDS layout"
puts ""
puts "  reports/postRoute*.rpt    -- setup and hold timing"
puts "  reports/drc.rpt           -- design rule check"
puts "  reports/power_postroute   -- dynamic + leakage power"
puts "=================================================================="
