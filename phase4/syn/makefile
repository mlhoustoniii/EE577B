# =============================================================================
# Phase 4 Synthesis Makefile -- cardinal_cmp
# EE 577B Spring 2026
#
# Usage (from phase4/syn/):
#   make              -- run full synthesis (alias for 'make syn')
#   make syn          -- run synthesis
#   make check        -- check WNS in the timing report
#   make clean        -- remove intermediate files (keep netlist + reports)
#   make realclean    -- nuke everything
# =============================================================================

TOP      = cardinal_cmp
DC_SHELL = dc_shell
TCL      = scripts/cmp_syn.tcl
LOG      = logs/cmp_syn.log

# ---- Default target ---------------------------------------------------------
.PHONY: all
all: syn

# ---- Synthesis --------------------------------------------------------------
.PHONY: syn
syn:
	@echo "=========================================================="
	@echo " Running Design Compiler synthesis for $(TOP)"
	@echo "=========================================================="
	@mkdir -p netlist report logs
	$(DC_SHELL) -f $(TCL) | tee $(LOG)
	@echo ""
	@echo "Synthesis complete. Key numbers:"
	@$(MAKE) -s check || true

# ---- Quick-look at critical-path slack --------------------------------------
.PHONY: check
check:
	@echo "----------------------------------------------------------"
	@echo " Critical path (from report/$(TOP)_timing.rpt):"
	@echo "----------------------------------------------------------"
	@grep -A1 "slack"  report/$(TOP)_timing.rpt | head -20 || \
		echo "  (report not found -- run 'make syn' first)"
	@echo ""
	@echo "----------------------------------------------------------"
	@echo " Total cell area (from report/$(TOP)_area.rpt):"
	@echo "----------------------------------------------------------"
	@grep -E "Total cell area|Total area" report/$(TOP)_area.rpt || true

# ---- Cleanup ----------------------------------------------------------------
.PHONY: clean
clean:
	rm -rf WORK alib-* *.svf command.log default.svf \
	       filenames.log .command_tmp_* dc_hdl.dat

.PHONY: realclean
realclean: clean
	rm -rf netlist/* report/* logs/*
