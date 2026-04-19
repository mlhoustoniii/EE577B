#!/bin/tcsh
# =============================================================================
# setup_pnr.csh -- Populate phase4/PNR/ with inputs for Innovus
# EE 577B Spring 2026, Phase 4
#
# Run from ~/577B/project/phase4/PNR/
# =============================================================================

set PHASE4  = /home/obhatt@vlab.usc.edu/577B/project/phase4
set EE577B  = /home/obhatt@vlab.usc.edu/577B/project/EE577B
set TOOLS   = /home/obhatt@vlab.usc.edu/tools

echo "============================================================"
echo " Setting up Phase 4 PNR directory"
echo "============================================================"

# ---- 1. Gate-level netlist
echo " Copying netlist..."
cp $EE577B/netlist/gold_router_syn.v  $PHASE4/PNR/netlist/

# ---- 2. SDC constraints
echo " Copying SDC..."
cp $EE577B/netlist/gold_router_syn.sdc $PHASE4/PNR/sdc/gold_router.sdc 2>/dev/null || \
cp $EE577B/netlist/gold_router.sdc     $PHASE4/PNR/sdc/gold_router.sdc 2>/dev/null || \
echo "  WARNING: No SDC found in EE577B/netlist/"

# ---- 3. Physical library files from prelabpnr
echo " Copying LEF/TLF/MAP library files..."
if (-d $TOOLS/prelabpnr/lib) then
    cp $TOOLS/prelabpnr/lib/gscl45nm.lef $PHASE4/PNR/lib/
    cp $TOOLS/prelabpnr/lib/gscl45nm.tlf $PHASE4/PNR/lib/
    cp $TOOLS/prelabpnr/lib/gscl45nm.map $PHASE4/PNR/lib/ 2>/dev/null || true
    echo "  Physical libs copied from prelabpnr/lib/"
else
    echo "  WARNING: prelabpnr/lib not found at $TOOLS/prelabpnr/lib"
    echo "           Check the correct path and copy manually:"
    echo "           cp <path>/gscl45nm.lef $PHASE4/PNR/lib/"
    echo "           cp <path>/gscl45nm.tlf $PHASE4/PNR/lib/"
endif

echo ""
echo " Verifying files:"
echo "  netlist/: `ls $PHASE4/PNR/netlist/`"
echo "  sdc/:     `ls $PHASE4/PNR/sdc/`"
echo "  lib/:     `ls $PHASE4/PNR/lib/`"
echo ""
echo "============================================================"
echo " PNR setup complete. Ready for Innovus GUI."
echo "============================================================"
