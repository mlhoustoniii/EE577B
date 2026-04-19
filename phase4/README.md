# Phase 4 — STA + PNR of Cardinal CMP

## Decisions locked in
- **Memory handling:** blackbox both `imem` and `dmem` (`set_dont_touch`). They stay as hierarchical instances in the netlist; the synthesized logic is only CPU + NIC + router + mesh + node-wrapper glue.
- **Clock:** 4.0 ns period / 250 MHz (matches Phase 1/2/3). If WNS fails, we re-run with 4.5 ns.
- **PNR:** Innovus GUI on the first pass (per `Innovus_setup.pdf`), then dump a Tcl transcript for the report.

## Directory layout
```
phase4/
├── mkdir_phase4.csh        <- run ONCE to create the tree
├── syn/
│   ├── design/             <- RTL (copy from Phase3/design/)
│   ├── include/            <- gscl45nm.v
│   ├── scripts/
│   │   └── cmp_syn.tcl     <- Design Compiler synthesis script
│   ├── netlist/            <- outputs: _syn.v + .sdc + .sdf
│   ├── report/             <- timing, area, power, check_design reports
│   ├── logs/
│   └── makefile            <- 'make syn' -> 'make check'
├── STA/                    <- populated AFTER synthesis closes
│   ├── designs/  libs/  sdc/  scripts/  reports/  logs/
├── PNR/                    <- populated AFTER STA signs off
│   ├── lib/  netlist/  sdc/  scripts/  reports/  output/  logs/
├── screenshots/            <- Innovus GIFs for the report
└── report/                 <- Phase_4_Report.pdf
```

## Execution order (strict)

**Step A — Scaffolding + synthesis (you are here)**
```tcsh
# 1. Create the tree
cd ~/577B/project
chmod +x mkdir_phase4.csh
./mkdir_phase4.csh

# 2. Populate syn/ with RTL + library + scripts
cp ~/577B/project/Phase3/design/*.v         phase4/syn/design/
cp ~/577B/project/EE577B/include/gscl45nm.v phase4/syn/include/

# 3. Drop in cmp_syn.tcl and the makefile (from Claude's artifacts)
#    -> phase4/syn/scripts/cmp_syn.tcl
#    -> phase4/syn/makefile

# 4. Source EE577B tools and run synthesis
source ~/577B/setup_ee577b_v26.csh  # or v25 if v26 absent
cd phase4/syn
make syn
```

**Pass criteria for Step A:**
- `report/cardinal_cmp_timing.rpt` shows `slack (MET) POSITIVE` — critical path WNS ≥ 0
- `report/check_design_post.rpt` has no ERROR lines
- `netlist/cardinal_cmp_syn.v` exists and is non-empty
- `netlist/cardinal_cmp.sdc` exists

If critical path misses by >200 ps, relax the clock to 4.5 ns (edit `CLK_PERIOD` at the top of `cmp_syn.tcl`) and re-run. Document the relaxation in the final report.

**Step B — STA** (after Step A passes): will be built once synthesis closes. The scripts are straightforward variants of the `sta_tut.tcl` sample in `Static_Timing_Analysis.pdf` adapted to the CMP netlist.

**Step C — PNR** (after Step B signs off): Innovus GUI walkthrough per `Innovus_setup.pdf`, capturing screenshots at each stage (floorplan, placement, CTS, route) for the report.

**Step D — Sign-off STA** (post-route): re-run PrimeTime with the routed netlist + `.spef` parasitics.

**Step E — Report + submission.**

## Notes on the synthesis script
- `compile_ultra -no_autoungroup` preserves the per-node hierarchy. Useful when debugging later — you can `find /-hier node01*` in Innovus and colour-code the 16 node regions in the floorplan.
- If DC complains that `imem` or `dmem` don't exist as references at all (which happens if `cardinal_node.v` instantiates them by a different module name), the `set_dont_touch` lines silently do nothing — not an error. Check `check_design_pre.rpt` to confirm they show up as unresolved references.
- The Phase-1 reports showed `133.9 μW` leakage per router. Full-CMP leakage should be roughly 16 × (router + cpu + nic) — somewhere in the 3-5 mW range. If you see < 1 mW, something got optimized away.
