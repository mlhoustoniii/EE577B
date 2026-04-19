set TOP     "cardinal_node"
set NETLIST "./netlist/cardinal_node_syn.v"
set LEF     "./lib/gscl45nm.lef"
set MMMC    "./Default.view"

puts "=== Step 1: Import ==="
set init_verilog       $NETLIST
set init_top_cell      $TOP
set init_lef_file      $LEF
set init_mmmc_file     $MMMC
set init_pwr_net       VDD
set init_gnd_net       VSS
init_design

puts "=== Step 2: Floorplan ==="
floorPlan -coreMarginsBy die -site CoreSite -d 880 880 5 5 5 5

puts "=== Step 3: Power ==="
globalNetConnect VDD -type pgpin -pin VDD -inst * -verbose
globalNetConnect VSS -type pgpin -pin GND -inst * -verbose
sroute -connect {corePin} -layerChangeRange {metal1 metal3} -allowJogging 1 -allowLayerChange 1

puts "=== Step 4: Placement ==="
setPlaceMode -fp false
place_design
saveDesign ./output/cardinal_node_placed.enc
puts "CHECKPOINT: placed"

puts "=== Step 5: Routing ==="
setNanoRouteMode -routeTopRoutingLayer 6 -routeBottomRoutingLayer 1 -drouteFixAntenna true
routeDesign
saveDesign ./output/cardinal_node_routed.enc
puts "CHECKPOINT: routed"

puts "=== Step 6: Reports ==="
verify_drc -report ./reports/drc_final.rpt
saveNetlist ./output/cardinal_node_routed.v
defOut ./output/cardinal_node_routed.def
puts "PNR COMPLETE"
