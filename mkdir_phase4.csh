#!/bin/tcsh
# =============================================================================
# mkdir_phase4.csh -- Phase 4 directory scaffolding
# EE 577B Spring 2026  --  Cardinal CMP STA + PNR
#
# Run this ONCE from ~/577B/project/ to create the Phase 4 tree.
# Mirrors the layout that worked for Phase 1 (EE577B/, v2/, v3/).
#
# Usage:
#   cd ~/577B/project
#   chmod +x mkdir_phase4.csh
#   ./mkdir_phase4.csh
# =============================================================================

set PHASE4_ROOT = ~/577B/project/phase4

echo "=============================================================="
echo "  Creating Phase 4 scaffolding at: $PHASE4_ROOT"
echo "=============================================================="

# ---- Top-level structure
mkdir -p $PHASE4_ROOT
mkdir -p $PHASE4_ROOT/syn
mkdir -p $PHASE4_ROOT/STA
mkdir -p $PHASE4_ROOT/PNR
mkdir -p $PHASE4_ROOT/report
mkdir -p $PHASE4_ROOT/screenshots

# ---- Synthesis subdirs (mirrors EE577B/ layout)
mkdir -p $PHASE4_ROOT/syn/design
mkdir -p $PHASE4_ROOT/syn/include
mkdir -p $PHASE4_ROOT/syn/scripts
mkdir -p $PHASE4_ROOT/syn/netlist
mkdir -p $PHASE4_ROOT/syn/report
mkdir -p $PHASE4_ROOT/syn/logs

# ---- STA subdirs (from Static_Timing_Analysis.pdf layout)
mkdir -p $PHASE4_ROOT/STA/designs
mkdir -p $PHASE4_ROOT/STA/libs
mkdir -p $PHASE4_ROOT/STA/sdc
mkdir -p $PHASE4_ROOT/STA/scripts
mkdir -p $PHASE4_ROOT/STA/reports
mkdir -p $PHASE4_ROOT/STA/logs

# ---- PNR subdirs (from Innovus_setup.pdf requirements)
mkdir -p $PHASE4_ROOT/PNR/lib
mkdir -p $PHASE4_ROOT/PNR/netlist
mkdir -p $PHASE4_ROOT/PNR/sdc
mkdir -p $PHASE4_ROOT/PNR/scripts
mkdir -p $PHASE4_ROOT/PNR/reports
mkdir -p $PHASE4_ROOT/PNR/output
mkdir -p $PHASE4_ROOT/PNR/logs

echo ""
echo "Tree created:"
echo ""
find $PHASE4_ROOT -type d | sort

echo ""
echo "=============================================================="
echo "  Next steps (run manually, in order):"
echo ""
echo "  1. Copy Phase-3 RTL to syn/design/"
echo "     cp ~/577B/project/Phase3/design/*.v $PHASE4_ROOT/syn/design/"
echo ""
echo "  2. Copy gscl45nm.v to syn/include/"
echo "     cp ~/577B/project/EE577B/include/gscl45nm.v $PHASE4_ROOT/syn/include/"
echo ""
echo "  3. Copy library .db for DC + STA:"
echo "     set LIB=/home/scf-22/ee577/NCSU45PDK/FreePDK45/osu_soc/lib/files"
echo "     cp \$LIB/gscl45nm.db $PHASE4_ROOT/syn/"
echo "     cp \$LIB/gscl45nm.db $PHASE4_ROOT/STA/libs/"
echo ""
echo "  4. Copy library .lef/.tlf/.map for Innovus:"
echo "     cp \$LIB/gscl45nm.lef $PHASE4_ROOT/PNR/lib/ # may be in a different dir"
echo "     cp \$LIB/gscl45nm.tlf $PHASE4_ROOT/PNR/lib/"
echo "     cp \$LIB/gscl45nm.map $PHASE4_ROOT/PNR/lib/"
echo ""
echo "  5. Drop the synthesis scripts (cmp_syn.tcl + makefile) into syn/scripts/"
echo ""
echo "=============================================================="
