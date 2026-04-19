#!/bin/tcsh
set PROJECT   = /home/viterbi/09/obhatt/577B/project
set HOPDIR    = $PROJECT/EE577B
set XYSTDDIR  = $PROJECT/v2
set TORUSDIR  = $PROJECT/v3

echo ""
echo "============================================================"
echo "  EE577B Cardinal 4x4 NoC -- Performance Sweep v2"
echo "============================================================"
echo ""

echo ">>> STEP 0: Installing new testbenches..."
cp -v $PROJECT/tb_perf_hop.v   $HOPDIR/tb/tb_perf_hop.v
cp -v $PROJECT/tb_perf_xystd.v $XYSTDDIR/tb/tb_perf_xystd.v
cp -v $PROJECT/tb_perf_torus.v $TORUSDIR/tb/tb_perf_torus.v
echo ""

echo "============================================================"
echo ">>> STEP 1: HOP simulation"
echo "============================================================"
cd $HOPDIR
echo "  Cleaning..."
make clean >& /dev/null
rm -rf INCA_libs
rm -f *.vcd tb/*.vcd perf_hop_summary.txt perf_hop_latency.txt perf_hop_sim.log
du -sh $PROJECT ; quota -s
echo "  Running HOP sim..."
ncverilog tb/tb_perf_hop.v \
    design/vc_buffer.v design/rr_arbiter.v \
    design/input_ctrl.v design/output_ctrl.v \
    design/gold_router.v design/gold_mesh.v \
    +access+r >& perf_hop_sim.log
if ($status == 0) then
    echo "  HOP: PASSED"
    cat perf_hop_summary.txt
    cp perf_hop_summary.txt $PROJECT/
    cp perf_hop_latency.txt $PROJECT/
else
    echo "  HOP: FAILED"
    grep '\*E' perf_hop_sim.log | head -5
endif
echo "  Wiping INCA_libs..."
rm -rf INCA_libs ; rm -f *.vcd tb/*.vcd
du -sh $PROJECT ; quota -s
echo ""

echo "============================================================"
echo ">>> STEP 2: XYSTD simulation"
echo "============================================================"
cd $XYSTDDIR
echo "  Cleaning..."
make clean >& /dev/null
rm -rf INCA_libs
rm -f *.vcd tb/*.vcd perf_xystd_summary.txt perf_xystd_latency.txt perf_xystd_sim.log
du -sh $PROJECT ; quota -s
echo "  Running XYSTD sim..."
ncverilog tb/tb_perf_xystd.v \
    design/vc_buffer.v design/rr_arbiter.v \
    design/input_ctrl_xystd.v design/output_ctrl_xystd.v \
    design/gold_router_xystd.v design/gold_mesh_xystd.v \
    +access+r >& perf_xystd_sim.log
if ($status == 0) then
    echo "  XYSTD: PASSED"
    cat perf_xystd_summary.txt
    cp perf_xystd_summary.txt $PROJECT/
    cp perf_xystd_latency.txt $PROJECT/
else
    echo "  XYSTD: FAILED"
    grep '\*E' perf_xystd_sim.log | head -5
endif
echo "  Wiping INCA_libs..."
rm -rf INCA_libs ; rm -f *.vcd tb/*.vcd
du -sh $PROJECT ; quota -s
echo ""

echo "============================================================"
echo ">>> STEP 3: TORUS simulation"
echo "============================================================"
cd $TORUSDIR
echo "  Cleaning..."
make clean >& /dev/null
rm -rf INCA_libs
rm -f *.vcd tb/*.vcd perf_torus_summary.txt perf_torus_latency.txt perf_torus_sim.log
du -sh $PROJECT ; quota -s
echo "  Running TORUS sim..."
ncverilog tb/tb_perf_torus.v \
    design/vc_buffer.v design/rr_arbiter.v \
    design/input_ctrl_torus.v design/output_ctrl_torus.v \
    design/gold_router_torus.v design/gold_mesh_torus.v \
    +access+r >& perf_torus_sim.log
if ($status == 0) then
    echo "  TORUS: PASSED"
    cat perf_torus_summary.txt
    cp perf_torus_summary.txt $PROJECT/
    cp perf_torus_latency.txt $PROJECT/
else
    echo "  TORUS: FAILED"
    grep '\*E' perf_torus_sim.log | head -5
endif
echo "  Wiping INCA_libs..."
rm -rf INCA_libs ; rm -f *.vcd tb/*.vcd
du -sh $PROJECT ; quota -s
echo ""

echo "============================================================"
echo ">>> STEP 4: Combined comparison"
echo "============================================================"
cd $PROJECT
python3 perf_compare.py

echo ""
echo "All done."
echo "Logs: EE577B/perf_hop_sim.log  v2/perf_xystd_sim.log  v3/perf_torus_sim.log"
ENDOFSCRIPT

chmod +x ~/577B/project/run_perf_all_v2.csh
./run_perf_all_v2.csh
