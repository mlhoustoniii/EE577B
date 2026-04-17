#!/bin/tcsh
# ============================================================
# run_perf_all.csh
# EE577B Cardinal Router -- Run ALL three performance TBs
#
# Runs tb_perf_hop, tb_perf_xystd, tb_perf_torus in sequence.
# Collects results and prints a combined comparison at the end.
#
# Usage (from ~/577B/project/):
#   source setup_ee577b_v25.csh   # if not already done
#   chmod +x run_perf_all.csh
#   ./run_perf_all.csh
# ============================================================

set PROJECT = ~/577B/project

# ── Colour codes (tcsh supports echo with escape) ──────────
set GRN = "\033[0;32m"
set RED = "\033[0;31m"
set YLW = "\033[0;33m"
set RST = "\033[0m"

echo ""
echo "============================================================"
echo "  EE577B Cardinal Router -- Performance Sweep"
echo "  HOP / XYSTD / TORUS"
echo "============================================================"
echo ""

# ── Helper: run one variant ──────────────────────────────────
# $1 = variant name (hop / xystd / torus)
# $2 = project subdir (EE577B / v2 / v3)
# $3 = space-separated list of design files

set PASS_COUNT = 0
set FAIL_COUNT = 0

# ─── HOP ─────────────────────────────────────────────────────
echo "${YLW}>>> Running HOP performance testbench...${RST}"
cd $PROJECT/EE577B

ncverilog tb/tb_perf_hop.v \
    design/vc_buffer.v \
    design/rr_arbiter.v \
    design/input_ctrl.v \
    design/output_ctrl.v \
    design/gold_router.v \
    design/gold_mesh.v \
    +access+r >& perf_hop_sim.log

if ($status == 0) then
    echo "${GRN}  HOP sim: PASSED${RST}"
    @ PASS_COUNT++
    cp perf_hop_latency.txt  $PROJECT/perf_hop_latency.txt
    cp perf_hop_summary.txt  $PROJECT/perf_hop_summary.txt
else
    echo "${RED}  HOP sim: FAILED -- see EE577B/perf_hop_sim.log${RST}"
    @ FAIL_COUNT++
endif
echo ""

# ─── XYSTD ───────────────────────────────────────────────────
echo "${YLW}>>> Running XYSTD performance testbench...${RST}"
cd $PROJECT/v2

ncverilog tb/tb_perf_xystd.v \
    design/vc_buffer.v \
    design/rr_arbiter.v \
    design/input_ctrl_xystd.v \
    design/output_ctrl_xystd.v \
    design/gold_router_xystd.v \
    design/gold_mesh_xystd.v \
    +access+r >& perf_xystd_sim.log

if ($status == 0) then
    echo "${GRN}  XYSTD sim: PASSED${RST}"
    @ PASS_COUNT++
    cp perf_xystd_latency.txt  $PROJECT/perf_xystd_latency.txt
    cp perf_xystd_summary.txt  $PROJECT/perf_xystd_summary.txt
else
    echo "${RED}  XYSTD sim: FAILED -- see v2/perf_xystd_sim.log${RST}"
    @ FAIL_COUNT++
endif
echo ""

# ─── TORUS ───────────────────────────────────────────────────
echo "${YLW}>>> Running TORUS performance testbench...${RST}"
cd $PROJECT/v3

ncverilog tb/tb_perf_torus.v \
    design/vc_buffer.v \
    design/rr_arbiter.v \
    design/input_ctrl_torus.v \
    design/output_ctrl_torus.v \
    design/gold_router_torus.v \
    design/gold_mesh_torus.v \
    +access+r >& perf_torus_sim.log

if ($status == 0) then
    echo "${GRN}  TORUS sim: PASSED${RST}"
    @ PASS_COUNT++
    cp perf_torus_latency.txt  $PROJECT/perf_torus_latency.txt
    cp perf_torus_summary.txt  $PROJECT/perf_torus_summary.txt
else
    echo "${RED}  TORUS sim: FAILED -- see v3/perf_torus_sim.log${RST}"
    @ FAIL_COUNT++
endif
echo ""

# ─── Combined report ─────────────────────────────────────────
echo "============================================================"
echo "  COMBINED PERFORMANCE RESULTS"
echo "  $PASS_COUNT/3 simulations passed"
echo "============================================================"

cd $PROJECT

foreach v (hop xystd torus)
    if (-f perf_${v}_summary.txt) then
        echo ""
        echo "---- ${v:u} ----------------------------------------"
        cat perf_${v}_summary.txt
    else
        echo ""
        echo "---- ${v:u}: no summary (sim failed or not run) ----"
    endif
end

echo ""
echo "============================================================"
echo "  Raw latency tables: perf_{hop,xystd,torus}_latency.txt"
echo "  Full summaries    : perf_{hop,xystd,torus}_summary.txt"
echo "  Sim logs          : EE577B/perf_hop_sim.log"
echo "                      v2/perf_xystd_sim.log"
echo "                      v3/perf_torus_sim.log"
echo "============================================================"
