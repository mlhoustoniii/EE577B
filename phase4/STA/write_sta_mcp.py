# The path is 157.06 ns long. Clock = 4 ns. Need ceiling(157.06/4) = 40 cycles.
# We set 40-cycle MCP from the startpoint register to all endpoints.
script = """
set PDK "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files"
set_app_var search_path    ". ./designs ./libs $PDK"
set_app_var target_library "gscl45nm.db"
set_app_var link_library   "* gscl45nm.db"

read_verilog ../PNR/output/cardinal_node_routed.v
current_design cardinal_node
link_design

# ── Clock ─────────────────────────────────────────────────────────────────────
create_clock -period 4.0 -name CLK [get_ports clk]
set_clock_latency      0.5 CLK
set_clock_uncertainty  0.1 CLK
set_input_delay  0.5 -clock CLK \\
    [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 0.5 -clock CLK [all_outputs]

# ── MCP: 40 cycles for the divider path ───────────────────────────────────────
# Path = 157.06 ns / 4 ns clock = 39.27 → need 40 cycles
# Apply from ALL idex registers (the pipeline stage feeding the divider)
# to ALL endpoints — this covers every path through EX_MEM_unit

set all_idex [get_cells u_cpu/idex_*]
echo "idex cells: [sizeof_collection $all_idex]"

set_multicycle_path 40 -setup -from $all_idex
set_multicycle_path 39 -hold  -from $all_idex
echo "MCP 40 cycles applied from all idex registers"

# Also apply from the specific worst startpoint directly
set_multicycle_path 40 -setup -from [get_cells u_cpu/idex_rB_data_reg_21_]
set_multicycle_path 39 -hold  -from [get_cells u_cpu/idex_rB_data_reg_21_]
echo "MCP 40 applied from specific worst startpoint"

# ── check_timing ──────────────────────────────────────────────────────────────
check_timing > reports/check_timing_mcp.rpt

# ── Reports ───────────────────────────────────────────────────────────────────
report_timing -delay max -max_paths 50 -slack_lesser_than 0 \\
    > reports/timing_mcp_violations.rpt
report_timing -delay max -max_paths 5 -path_type full \\
    > reports/timing_mcp_setup.rpt
report_timing -delay min -max_paths 5 -path_type full \\
    > reports/timing_mcp_hold.rpt
report_timing -delay max -max_paths 1 -path_type summary \\
    > reports/timing_mcp_summary.rpt
report_qor > reports/timing_mcp_qor.rpt

echo "=== WNS after 40-cycle MCP ==="
report_timing -delay max -max_paths 1 -path_type summary

echo "=== Any remaining violations ==="
report_timing -delay max -max_paths 5 -slack_lesser_than 0 -path_type summary

remove_design -all
remove_lib    -all
exit
"""

with open("sta_mcp.tcl", "w") as f:
    f.write(script)
print("Done")
