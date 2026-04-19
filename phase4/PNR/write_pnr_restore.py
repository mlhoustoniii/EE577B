script = r"""set TOP  "cardinal_node"
set MMMC "./Default.view"
set LEF  "./lib/gscl45nm.lef"

puts "=== Restore with MMMC ==="
set init_lef_file  $LEF
set init_mmmc_file $MMMC
set init_pwr_net   VDD
set init_gnd_net   VSS

restoreDesign ./output/cardinal_node_routed.enc.dat cardinal_node

puts "=== Activate analysis views ==="
set_analysis_view -setup view1 -hold view1

puts "=== Verify DRC (real count) ==="
verify_drc -limit 0 -report ./reports/drc_restored.rpt

puts "=== Fix DRC ==="
ecoRoute -fix_drc

puts "=== Verify DRC after fix ==="
verify_drc -limit 0 -report ./reports/drc_after_fix.rpt

puts "=== Export SPEF ==="
rcOut -spef ./output/cardinal_node_routed.spef -rc_corner typical

puts "=== Save clean design ==="
saveDesign ./output/cardinal_node_clean.enc
saveNetlist ./output/cardinal_node_final.v
defOut ./output/cardinal_node_final.def

puts "=== ALL DONE ==="
"""

with open("pnr_restore_fix.tcl", "w") as f:
    f.write(script)
print("Done")
