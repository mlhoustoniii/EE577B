#!/bin/csh
# Run from ~/577B/project/phase4/syn/
# Dumps all synthesis design files into one big file for debugging

set OUT = "/tmp/syn_all_files.txt"
echo "" > $OUT

foreach f (design/imem_syn.v design/dmem_syn.v design/cardinal_nic.v design/cardinal_node.v design/cardinal_cpu.v design/IF.v design/id_stage.v design/ex_mem_stage.v design/cardinal_router.v scripts/cmp_syn.tcl makefile)
    echo "========================================" >> $OUT
    echo "FILE: $f" >> $OUT
    echo "========================================" >> $OUT
    cat $f >> $OUT
    echo "" >> $OUT
end

# Also dump last 100 lines of the synthesis log
echo "========================================" >> $OUT
echo "FILE: logs/cmp_syn.log (last 200 lines)" >> $OUT
echo "========================================" >> $OUT
tail -200 logs/cmp_syn.log >> $OUT

# Dump the area report
echo "========================================" >> $OUT
echo "FILE: report/cardinal_node_area.rpt" >> $OUT
echo "========================================" >> $OUT
cat report/cardinal_node_area.rpt >> $OUT

# Dump timing report
echo "========================================" >> $OUT
echo "FILE: report/cardinal_node_timing.rpt (first 80 lines)" >> $OUT
echo "========================================" >> $OUT
head -80 report/cardinal_node_timing.rpt >> $OUT

echo "Done. File at: $OUT"
echo "Line count:"
wc -l $OUT
