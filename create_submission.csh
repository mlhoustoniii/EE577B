#!/bin/tcsh
# 1. Define your group number
set GROUP_NUM = 1
set GRPNAME = Phase_1_Group_${GROUP_NUM}

echo "=== Packaging Submission for $GRPNAME ==="

# 2. Create the required folder structure
mkdir -p $GRPNAME/design
mkdir -p $GRPNAME/tb
mkdir -p $GRPNAME/netlist
mkdir -p $GRPNAME/report
mkdir -p $GRPNAME/simvision_router
mkdir -p $GRPNAME/simvision_nic

# 3. Copy Core HOP Design Files
cp EE577B/design/gold_router.v    $GRPNAME/design/
cp EE577B/design/gold_mesh.v      $GRPNAME/design/
cp EE577B/design/input_ctrl.v     $GRPNAME/design/
cp EE577B/design/output_ctrl.v    $GRPNAME/design/
cp EE577B/design/vc_buffer.v      $GRPNAME/design/
cp EE577B/design/rr_arbiter.v     $GRPNAME/design/
cp EE577B/design/cardinal_nic.v   $GRPNAME/design/

# 4. Copy v2 (XYSTD) and v3 (Torus) Design Files
cp v2/design/input_ctrl_xystd.v   $GRPNAME/design/
cp v2/design/output_ctrl_xystd.v  $GRPNAME/design/
cp v2/design/gold_router_xystd.v  $GRPNAME/design/
cp v2/design/gold_mesh_xystd.v    $GRPNAME/design/
cp v3/design/input_ctrl_torus.v   $GRPNAME/design/
cp v3/design/gold_router_torus.v  $GRPNAME/design/
cp v3/design/gold_mesh_torus.v    $GRPNAME/design/

# 5. Copy Testbenches
cp EE577B/tb/tb_gold_mesh.v       $GRPNAME/tb/
cp EE577B/tb/tb_cardinal_nic.v    $GRPNAME/tb/
cp EE577B/tb/tb_gold_router.v     $GRPNAME/tb/ >& /dev/null

# 6. Copy Simulation Output Logs (Phase 0-15)
cp EE577B/gather_phase*.res       $GRPNAME/
cp EE577B/start_end_time.out      $GRPNAME/

# 7. Copy Netlists and Synthesis Reports
cp EE577B/netlist/*syn* $GRPNAME/netlist/ >& /dev/null
cp EE577B/report/* $GRPNAME/report/ >& /dev/null

# 8. Copy the Report PDF (Assuming you upload it as EE577B_Phase1_Report.pdf)
cp EE577B_Phase1_Report.pdf       $GRPNAME/report/ >& /dev/null
if ( ! -f $GRPNAME/report/EE577B_Phase1_Report.pdf ) then
    echo "WARNING: EE577B_Phase1_Report.pdf not found. Don't forget to add it to $GRPNAME/report/!"
endif

# 9. Copy SimVision Database
if ( -d EE577B/ncsim.shm ) then
    cp -r EE577B/ncsim.shm        $GRPNAME/simvision_router/
else
    echo "WARNING: ncsim.shm missing! Re-run 'ncverilog ... +access+r' in EE577B to generate it."
endif

# 10. Zip the folder
zip -r ${GRPNAME}.zip $GRPNAME/

echo "=== Done! Generated ${GRPNAME}.zip ==="
