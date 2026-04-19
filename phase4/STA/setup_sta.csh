#!/bin/tcsh
# =============================================================================
# setup_sta.csh -- Populate phase4/STA/ with inputs from Phase-1 synthesis
# EE 577B Spring 2026, Phase 4
#
# Run from ~/577B/project/phase4/STA/
# =============================================================================

set PHASE4     = /home/obhatt@vlab.usc.edu/577B/project/phase4
set EE577B     = /home/obhatt@vlab.usc.edu/577B/project/EE577B
set PDK        = /tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files

echo "============================================================"
echo " Setting up Phase 4 STA directory"
echo "============================================================"

# ---- 1. Gate-level netlist from Phase-1 synthesis
echo " Copying gate-level netlist..."
cp $EE577B/netlist/gold_router_syn.v  $PHASE4/STA/designs/
cp $EE577B/netlist/cardinal_nic_syn.v $PHASE4/STA/designs/

# ---- 2. SDC constraints from Phase-1 synthesis
echo " Copying SDC files..."
cp $EE577B/netlist/gold_router.sdc    $PHASE4/STA/sdc/ 2>/dev/null || \
cp $EE577B/netlist/gold_router_syn.sdc $PHASE4/STA/sdc/gold_router.sdc 2>/dev/null || \
echo "  WARNING: No SDC found -- sta_run.tcl will create constraints manually"

# ---- 3. gscl45nm.db library
echo " Checking for gscl45nm.db..."
if (-f $PDK/gscl45nm.db) then
    cp $PDK/gscl45nm.db $PHASE4/STA/libs/
    echo "  gscl45nm.db found and copied."
else
    echo "  WARNING: gscl45nm.db not at $PDK"
    echo "           STA will use search_path to find it automatically"
endif

# ---- 4. Create .synopsys_pt.setup for pt_shell
echo " Writing .synopsys_pt.setup..."
cat > $PHASE4/STA/.synopsys_pt.setup << 'EOF'
# PrimeTime session setup for cardinal_router STA
# EE 577B Spring 2026, Phase 4
set search_path  [list . ./libs ./designs ./sdc /tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files]
set link_path    [list * gscl45nm.db]
set target_library "gscl45nm.db"
EOF

echo ""
echo " Verifying files:"
echo "  designs/: `ls $PHASE4/STA/designs/`"
echo "  sdc/:     `ls $PHASE4/STA/sdc/`"
echo "  libs/:    `ls $PHASE4/STA/libs/`"
echo ""
echo "============================================================"
echo " STA setup complete."
echo " To run STA:"
echo "   cd $PHASE4/STA"
echo "   source /home/obhatt@vlab.usc.edu/tools/setup_ee577b_v26.csh"
echo "   pt_shell -f scripts/sta_run.tcl | tee logs/sta_run.log"
echo "============================================================"
