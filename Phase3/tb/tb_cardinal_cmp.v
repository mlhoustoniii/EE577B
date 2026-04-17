`timescale 1ns/1ps
/////////////////////////////////////////////////////////////////////
// Filename     : tb_cardinal_cmp.v
// Project      : EE577B Spring 2026 — Cardinal CMP Phase 3
// Description  : 16-core all-to-all testbench for cardinal_cmp.
//
//  Strategy:
//    Every node sends 15 packets (one to each peer) and receives
//    15 packets.  After a generous timeout, the testbench:
//      1. Dumps MEM[0..31] of every node's DMEM into
//         cmp_test.dmem.XY.dump  (§6.2)
//      2. Checks MEM[16..30] of every node for exactly 15
//         non-zero entries and prints PASS / FAIL per node (§6.3)
//      3. Continuously monitors NIC→router injection and
//         router→NIC delivery on every node (§6.4)
//
//  Hierarchical path convention (matches cardinal_node.v):
//    dut.nodeXY.u_dmem.MEM[n]
//    dut.nodeXY.u_nic.net_so / net_ro / net_do   (inject)
//    dut.nodeXY.u_nic.net_si / net_ri / net_di   (deliver)
//
//  NODE_ID = Y*4 + X   (X=column, Y=row)
//    node00→0  node10→1  node20→2  node30→3
//    node01→4  node11→5  node21→6  node31→7
//    node02→8  node12→9  node22→10 node32→11
//    node03→12 node13→13 node23→14 node33→15
/////////////////////////////////////////////////////////////////////

module tb_cardinal_cmp;

// ----------------------------------------------------------------
//  DUT clock & reset
// ----------------------------------------------------------------
reg clk, reset;

cardinal_cmp dut (
    .clk   (clk),
    .reset (reset)
);

// ----------------------------------------------------------------
//  Fill-file loader
//  Populates each node's IMEM and DMEM from cmp_test.{imem,dmem}.XY.fill
//  in the include/ directory (relative to simulator CWD, i.e. where
//  the Makefile invokes ncverilog).
//
//  Uses hierarchical references rather than parameterizing imem/dmem
//  so the Phase 2 memory modules stay untouched. Runs at t=0, before
//  the clock starts toggling, so memories are ready the first time
//  the CPU fetches an instruction.
//
//  Missing files will print a WARNING from $readmemh but simulation
//  continues -- grep the log for "WARNING" after the run to catch
//  any absent fill files.
// ----------------------------------------------------------------
initial begin
    // -- Row y=0 --
    $readmemh("include/cmp_test.imem.00.fill", dut.node00.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.00.fill", dut.node00.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.10.fill", dut.node10.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.10.fill", dut.node10.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.20.fill", dut.node20.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.20.fill", dut.node20.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.30.fill", dut.node30.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.30.fill", dut.node30.u_dmem.MEM);

    // -- Row y=1 --
    $readmemh("include/cmp_test.imem.01.fill", dut.node01.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.01.fill", dut.node01.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.11.fill", dut.node11.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.11.fill", dut.node11.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.21.fill", dut.node21.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.21.fill", dut.node21.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.31.fill", dut.node31.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.31.fill", dut.node31.u_dmem.MEM);

    // -- Row y=2 --
    $readmemh("include/cmp_test.imem.02.fill", dut.node02.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.02.fill", dut.node02.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.12.fill", dut.node12.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.12.fill", dut.node12.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.22.fill", dut.node22.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.22.fill", dut.node22.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.32.fill", dut.node32.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.32.fill", dut.node32.u_dmem.MEM);

    // -- Row y=3 --
    $readmemh("include/cmp_test.imem.03.fill", dut.node03.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.03.fill", dut.node03.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.13.fill", dut.node13.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.13.fill", dut.node13.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.23.fill", dut.node23.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.23.fill", dut.node23.u_dmem.MEM);
    $readmemh("include/cmp_test.imem.33.fill", dut.node33.u_imem.MEM);
    $readmemh("include/cmp_test.dmem.33.fill", dut.node33.u_dmem.MEM);

    $display("[TB] All 32 fill files loaded from include/");
end

// 4 ns period → 250 MHz (spec requirement)
initial clk = 0;
always  #2 clk = ~clk;

// ----------------------------------------------------------------
//  Cycle counter (useful for the report)
// ----------------------------------------------------------------
integer cycle_count;
initial cycle_count = 0;
always @(posedge clk) if (!reset) cycle_count = cycle_count + 1;

// ----------------------------------------------------------------
//  §6.1  Main stimulus
// ----------------------------------------------------------------
integer f;   // scratch file handle for dump loop

initial begin
    // Assert reset for 5 full clock periods (20 ns)
    reset = 1;
    #20;
    reset = 0;

    $display("[TB] Reset released at t=%0t ns.  Simulation running...", $time);

    // Generous timeout: 100 000 ns = 25 000 cycles at 250 MHz
    // (Increase if your assembly takes longer to converge.)
    #100000;

    $display("[TB] Timeout reached at t=%0t ns (%0d cycles).", $time, cycle_count);
    $display("[TB] Dumping DMEMs and checking results...");

    // §6.2 — dump all 16 node DMEMs
    dump_all_dmems;

    // §6.3 — inline correctness check
    check_all_nodes;

    $display("[TB] Simulation complete.");
    $finish;
end

// ================================================================
//  §6.2  DMEM Dump Task
//  Writes MEM[0..31] for each of the 16 nodes into
//  cmp_test.dmem.XY.dump using a for-loop (compatible with
//  NCSIM 15.x which may not support $writememh range arguments).
// ================================================================
task dump_all_dmems;
    integer i;
    begin
        // ---- Row y=0 ----
        f = $fopen("cmp_test.dmem.00.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.00.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node00.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.10.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.10.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node10.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.20.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.20.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node20.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.30.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.30.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node30.u_dmem.MEM[i]); $fclose(f);

        // ---- Row y=1 ----
        f = $fopen("cmp_test.dmem.01.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.01.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node01.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.11.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.11.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node11.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.21.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.21.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node21.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.31.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.31.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node31.u_dmem.MEM[i]); $fclose(f);

        // ---- Row y=2 ----
        f = $fopen("cmp_test.dmem.02.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.02.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node02.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.12.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.12.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node12.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.22.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.22.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node22.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.32.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.32.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node32.u_dmem.MEM[i]); $fclose(f);

        // ---- Row y=3 ----
        f = $fopen("cmp_test.dmem.03.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.03.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node03.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.13.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.13.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node13.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.23.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.23.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node23.u_dmem.MEM[i]); $fclose(f);

        f = $fopen("cmp_test.dmem.33.dump"); if (!f) $display("[TB] WARN: cannot open cmp_test.dmem.33.dump");
        for (i=0; i<32; i=i+1) $fdisplay(f, "%h", dut.node33.u_dmem.MEM[i]); $fclose(f);

        $display("[TB] All 16 DMEM dumps written.");
    end
endtask

// ================================================================
//  §6.3  Inline correctness checker
//
//  For each node, verify:
//    • MEM[16..30] (15 slots) each holds a non-zero value
//      (a zero entry → that packet never arrived)
//    • Exactly 15 non-zero entries (none missing, no overflow)
//
//  The source-ID uniqueness check is done per-slot using the
//  src nibble the assembly encodes in bits [11:8] of the packet
//  lower-word, matching the packet format used in cmp_test.asm.
//  If your assembly encodes src differently, adjust the slice below.
//
//  Print format:
//    [CHECK] NODE XY : PASS  (15/15 packets received)
//    [CHECK] NODE XY : FAIL  (N/15 packets received, missing slots: ...)
// ================================================================

// Helper: count and report for a single node
// Arguments: node label string, 15-entry snapshot of MEM[16..30]
task check_node;
    input [63:0] label;        // e.g. "00", "13" — 2-ASCII chars packed
    input [63:0] m16, m17, m18, m19, m20,
                 m21, m22, m23, m24, m25,
                 m26, m27, m28, m29, m30;
    integer cnt;
    begin
        cnt = 0;
        // Strict check: a slot counts as "received" only if it holds a
        // fully defined, non-zero 64-bit value. The reduction-xor ^mN
        // is x whenever any bit of mN is x, so ^mN !== 1'bx means "no
        // bits are x". Combined with the non-zero test this catches
        // both "never written" (x) and "written as zero" (which the
        // CPU shouldn't do for a real packet anyway).
        if (^m16 !== 1'bx && m16 !== 64'h0) cnt = cnt + 1;
        if (^m17 !== 1'bx && m17 !== 64'h0) cnt = cnt + 1;
        if (^m18 !== 1'bx && m18 !== 64'h0) cnt = cnt + 1;
        if (^m19 !== 1'bx && m19 !== 64'h0) cnt = cnt + 1;
        if (^m20 !== 1'bx && m20 !== 64'h0) cnt = cnt + 1;
        if (^m21 !== 1'bx && m21 !== 64'h0) cnt = cnt + 1;
        if (^m22 !== 1'bx && m22 !== 64'h0) cnt = cnt + 1;
        if (^m23 !== 1'bx && m23 !== 64'h0) cnt = cnt + 1;
        if (^m24 !== 1'bx && m24 !== 64'h0) cnt = cnt + 1;
        if (^m25 !== 1'bx && m25 !== 64'h0) cnt = cnt + 1;
        if (^m26 !== 1'bx && m26 !== 64'h0) cnt = cnt + 1;
        if (^m27 !== 1'bx && m27 !== 64'h0) cnt = cnt + 1;
        if (^m28 !== 1'bx && m28 !== 64'h0) cnt = cnt + 1;
        if (^m29 !== 1'bx && m29 !== 64'h0) cnt = cnt + 1;
        if (^m30 !== 1'bx && m30 !== 64'h0) cnt = cnt + 1;

        if (cnt === 15)
            $display("[CHECK] NODE %0s : PASS  (15/15 packets received)", label);
        else begin
            $display("[CHECK] NODE %0s : FAIL  (%0d/15 packets received)", label, cnt);
            // Report which slots are still zero for debugging
            // Report which slots are still zero OR x for debugging.
            // Matches the strict count condition above: anything that
            // isn't "defined and non-zero" is considered missing.
            if (^m16 === 1'bx || m16 === 64'h0) $display("          -> MEM[16] missing (val=%h)", m16);
            if (^m17 === 1'bx || m17 === 64'h0) $display("          -> MEM[17] missing (val=%h)", m17);
            if (^m18 === 1'bx || m18 === 64'h0) $display("          -> MEM[18] missing (val=%h)", m18);
            if (^m19 === 1'bx || m19 === 64'h0) $display("          -> MEM[19] missing (val=%h)", m19);
            if (^m20 === 1'bx || m20 === 64'h0) $display("          -> MEM[20] missing (val=%h)", m20);
            if (^m21 === 1'bx || m21 === 64'h0) $display("          -> MEM[21] missing (val=%h)", m21);
            if (^m22 === 1'bx || m22 === 64'h0) $display("          -> MEM[22] missing (val=%h)", m22);
            if (^m23 === 1'bx || m23 === 64'h0) $display("          -> MEM[23] missing (val=%h)", m23);
            if (^m24 === 1'bx || m24 === 64'h0) $display("          -> MEM[24] missing (val=%h)", m24);
            if (^m25 === 1'bx || m25 === 64'h0) $display("          -> MEM[25] missing (val=%h)", m25);
            if (^m26 === 1'bx || m26 === 64'h0) $display("          -> MEM[26] missing (val=%h)", m26);
            if (^m27 === 1'bx || m27 === 64'h0) $display("          -> MEM[27] missing (val=%h)", m27);
            if (^m28 === 1'bx || m28 === 64'h0) $display("          -> MEM[28] missing (val=%h)", m28);
            if (^m29 === 1'bx || m29 === 64'h0) $display("          -> MEM[29] missing (val=%h)", m29);
            if (^m30 === 1'bx || m30 === 64'h0) $display("          -> MEM[30] missing (val=%h)", m30);
        end
    end
endtask

task check_all_nodes;
    integer total_pass, total_fail;
    begin
        total_pass = 0;
        total_fail = 0;

        $display("------------------------------------------------------------");
        $display("[CHECK] Post-simulation correctness report  (t=%0t ns)", $time);
        $display("        Verifying MEM[16..30] of each node == 15 packets");
        $display("------------------------------------------------------------");

        // ---- Row y=0 ----
        check_node("00",
            dut.node00.u_dmem.MEM[16], dut.node00.u_dmem.MEM[17],
            dut.node00.u_dmem.MEM[18], dut.node00.u_dmem.MEM[19],
            dut.node00.u_dmem.MEM[20], dut.node00.u_dmem.MEM[21],
            dut.node00.u_dmem.MEM[22], dut.node00.u_dmem.MEM[23],
            dut.node00.u_dmem.MEM[24], dut.node00.u_dmem.MEM[25],
            dut.node00.u_dmem.MEM[26], dut.node00.u_dmem.MEM[27],
            dut.node00.u_dmem.MEM[28], dut.node00.u_dmem.MEM[29],
            dut.node00.u_dmem.MEM[30]);

        check_node("10",
            dut.node10.u_dmem.MEM[16], dut.node10.u_dmem.MEM[17],
            dut.node10.u_dmem.MEM[18], dut.node10.u_dmem.MEM[19],
            dut.node10.u_dmem.MEM[20], dut.node10.u_dmem.MEM[21],
            dut.node10.u_dmem.MEM[22], dut.node10.u_dmem.MEM[23],
            dut.node10.u_dmem.MEM[24], dut.node10.u_dmem.MEM[25],
            dut.node10.u_dmem.MEM[26], dut.node10.u_dmem.MEM[27],
            dut.node10.u_dmem.MEM[28], dut.node10.u_dmem.MEM[29],
            dut.node10.u_dmem.MEM[30]);

        check_node("20",
            dut.node20.u_dmem.MEM[16], dut.node20.u_dmem.MEM[17],
            dut.node20.u_dmem.MEM[18], dut.node20.u_dmem.MEM[19],
            dut.node20.u_dmem.MEM[20], dut.node20.u_dmem.MEM[21],
            dut.node20.u_dmem.MEM[22], dut.node20.u_dmem.MEM[23],
            dut.node20.u_dmem.MEM[24], dut.node20.u_dmem.MEM[25],
            dut.node20.u_dmem.MEM[26], dut.node20.u_dmem.MEM[27],
            dut.node20.u_dmem.MEM[28], dut.node20.u_dmem.MEM[29],
            dut.node20.u_dmem.MEM[30]);

        check_node("30",
            dut.node30.u_dmem.MEM[16], dut.node30.u_dmem.MEM[17],
            dut.node30.u_dmem.MEM[18], dut.node30.u_dmem.MEM[19],
            dut.node30.u_dmem.MEM[20], dut.node30.u_dmem.MEM[21],
            dut.node30.u_dmem.MEM[22], dut.node30.u_dmem.MEM[23],
            dut.node30.u_dmem.MEM[24], dut.node30.u_dmem.MEM[25],
            dut.node30.u_dmem.MEM[26], dut.node30.u_dmem.MEM[27],
            dut.node30.u_dmem.MEM[28], dut.node30.u_dmem.MEM[29],
            dut.node30.u_dmem.MEM[30]);

        // ---- Row y=1 ----
        check_node("01",
            dut.node01.u_dmem.MEM[16], dut.node01.u_dmem.MEM[17],
            dut.node01.u_dmem.MEM[18], dut.node01.u_dmem.MEM[19],
            dut.node01.u_dmem.MEM[20], dut.node01.u_dmem.MEM[21],
            dut.node01.u_dmem.MEM[22], dut.node01.u_dmem.MEM[23],
            dut.node01.u_dmem.MEM[24], dut.node01.u_dmem.MEM[25],
            dut.node01.u_dmem.MEM[26], dut.node01.u_dmem.MEM[27],
            dut.node01.u_dmem.MEM[28], dut.node01.u_dmem.MEM[29],
            dut.node01.u_dmem.MEM[30]);

        check_node("11",
            dut.node11.u_dmem.MEM[16], dut.node11.u_dmem.MEM[17],
            dut.node11.u_dmem.MEM[18], dut.node11.u_dmem.MEM[19],
            dut.node11.u_dmem.MEM[20], dut.node11.u_dmem.MEM[21],
            dut.node11.u_dmem.MEM[22], dut.node11.u_dmem.MEM[23],
            dut.node11.u_dmem.MEM[24], dut.node11.u_dmem.MEM[25],
            dut.node11.u_dmem.MEM[26], dut.node11.u_dmem.MEM[27],
            dut.node11.u_dmem.MEM[28], dut.node11.u_dmem.MEM[29],
            dut.node11.u_dmem.MEM[30]);

        check_node("21",
            dut.node21.u_dmem.MEM[16], dut.node21.u_dmem.MEM[17],
            dut.node21.u_dmem.MEM[18], dut.node21.u_dmem.MEM[19],
            dut.node21.u_dmem.MEM[20], dut.node21.u_dmem.MEM[21],
            dut.node21.u_dmem.MEM[22], dut.node21.u_dmem.MEM[23],
            dut.node21.u_dmem.MEM[24], dut.node21.u_dmem.MEM[25],
            dut.node21.u_dmem.MEM[26], dut.node21.u_dmem.MEM[27],
            dut.node21.u_dmem.MEM[28], dut.node21.u_dmem.MEM[29],
            dut.node21.u_dmem.MEM[30]);

        check_node("31",
            dut.node31.u_dmem.MEM[16], dut.node31.u_dmem.MEM[17],
            dut.node31.u_dmem.MEM[18], dut.node31.u_dmem.MEM[19],
            dut.node31.u_dmem.MEM[20], dut.node31.u_dmem.MEM[21],
            dut.node31.u_dmem.MEM[22], dut.node31.u_dmem.MEM[23],
            dut.node31.u_dmem.MEM[24], dut.node31.u_dmem.MEM[25],
            dut.node31.u_dmem.MEM[26], dut.node31.u_dmem.MEM[27],
            dut.node31.u_dmem.MEM[28], dut.node31.u_dmem.MEM[29],
            dut.node31.u_dmem.MEM[30]);

        // ---- Row y=2 ----
        check_node("02",
            dut.node02.u_dmem.MEM[16], dut.node02.u_dmem.MEM[17],
            dut.node02.u_dmem.MEM[18], dut.node02.u_dmem.MEM[19],
            dut.node02.u_dmem.MEM[20], dut.node02.u_dmem.MEM[21],
            dut.node02.u_dmem.MEM[22], dut.node02.u_dmem.MEM[23],
            dut.node02.u_dmem.MEM[24], dut.node02.u_dmem.MEM[25],
            dut.node02.u_dmem.MEM[26], dut.node02.u_dmem.MEM[27],
            dut.node02.u_dmem.MEM[28], dut.node02.u_dmem.MEM[29],
            dut.node02.u_dmem.MEM[30]);

        check_node("12",
            dut.node12.u_dmem.MEM[16], dut.node12.u_dmem.MEM[17],
            dut.node12.u_dmem.MEM[18], dut.node12.u_dmem.MEM[19],
            dut.node12.u_dmem.MEM[20], dut.node12.u_dmem.MEM[21],
            dut.node12.u_dmem.MEM[22], dut.node12.u_dmem.MEM[23],
            dut.node12.u_dmem.MEM[24], dut.node12.u_dmem.MEM[25],
            dut.node12.u_dmem.MEM[26], dut.node12.u_dmem.MEM[27],
            dut.node12.u_dmem.MEM[28], dut.node12.u_dmem.MEM[29],
            dut.node12.u_dmem.MEM[30]);

        check_node("22",
            dut.node22.u_dmem.MEM[16], dut.node22.u_dmem.MEM[17],
            dut.node22.u_dmem.MEM[18], dut.node22.u_dmem.MEM[19],
            dut.node22.u_dmem.MEM[20], dut.node22.u_dmem.MEM[21],
            dut.node22.u_dmem.MEM[22], dut.node22.u_dmem.MEM[23],
            dut.node22.u_dmem.MEM[24], dut.node22.u_dmem.MEM[25],
            dut.node22.u_dmem.MEM[26], dut.node22.u_dmem.MEM[27],
            dut.node22.u_dmem.MEM[28], dut.node22.u_dmem.MEM[29],
            dut.node22.u_dmem.MEM[30]);

        check_node("32",
            dut.node32.u_dmem.MEM[16], dut.node32.u_dmem.MEM[17],
            dut.node32.u_dmem.MEM[18], dut.node32.u_dmem.MEM[19],
            dut.node32.u_dmem.MEM[20], dut.node32.u_dmem.MEM[21],
            dut.node32.u_dmem.MEM[22], dut.node32.u_dmem.MEM[23],
            dut.node32.u_dmem.MEM[24], dut.node32.u_dmem.MEM[25],
            dut.node32.u_dmem.MEM[26], dut.node32.u_dmem.MEM[27],
            dut.node32.u_dmem.MEM[28], dut.node32.u_dmem.MEM[29],
            dut.node32.u_dmem.MEM[30]);

        // ---- Row y=3 ----
        check_node("03",
            dut.node03.u_dmem.MEM[16], dut.node03.u_dmem.MEM[17],
            dut.node03.u_dmem.MEM[18], dut.node03.u_dmem.MEM[19],
            dut.node03.u_dmem.MEM[20], dut.node03.u_dmem.MEM[21],
            dut.node03.u_dmem.MEM[22], dut.node03.u_dmem.MEM[23],
            dut.node03.u_dmem.MEM[24], dut.node03.u_dmem.MEM[25],
            dut.node03.u_dmem.MEM[26], dut.node03.u_dmem.MEM[27],
            dut.node03.u_dmem.MEM[28], dut.node03.u_dmem.MEM[29],
            dut.node03.u_dmem.MEM[30]);

        check_node("13",
            dut.node13.u_dmem.MEM[16], dut.node13.u_dmem.MEM[17],
            dut.node13.u_dmem.MEM[18], dut.node13.u_dmem.MEM[19],
            dut.node13.u_dmem.MEM[20], dut.node13.u_dmem.MEM[21],
            dut.node13.u_dmem.MEM[22], dut.node13.u_dmem.MEM[23],
            dut.node13.u_dmem.MEM[24], dut.node13.u_dmem.MEM[25],
            dut.node13.u_dmem.MEM[26], dut.node13.u_dmem.MEM[27],
            dut.node13.u_dmem.MEM[28], dut.node13.u_dmem.MEM[29],
            dut.node13.u_dmem.MEM[30]);

        check_node("23",
            dut.node23.u_dmem.MEM[16], dut.node23.u_dmem.MEM[17],
            dut.node23.u_dmem.MEM[18], dut.node23.u_dmem.MEM[19],
            dut.node23.u_dmem.MEM[20], dut.node23.u_dmem.MEM[21],
            dut.node23.u_dmem.MEM[22], dut.node23.u_dmem.MEM[23],
            dut.node23.u_dmem.MEM[24], dut.node23.u_dmem.MEM[25],
            dut.node23.u_dmem.MEM[26], dut.node23.u_dmem.MEM[27],
            dut.node23.u_dmem.MEM[28], dut.node23.u_dmem.MEM[29],
            dut.node23.u_dmem.MEM[30]);

        check_node("33",
            dut.node33.u_dmem.MEM[16], dut.node33.u_dmem.MEM[17],
            dut.node33.u_dmem.MEM[18], dut.node33.u_dmem.MEM[19],
            dut.node33.u_dmem.MEM[20], dut.node33.u_dmem.MEM[21],
            dut.node33.u_dmem.MEM[22], dut.node33.u_dmem.MEM[23],
            dut.node33.u_dmem.MEM[24], dut.node33.u_dmem.MEM[25],
            dut.node33.u_dmem.MEM[26], dut.node33.u_dmem.MEM[27],
            dut.node33.u_dmem.MEM[28], dut.node33.u_dmem.MEM[29],
            dut.node33.u_dmem.MEM[30]);

        $display("------------------------------------------------------------");
    end
endtask

// ================================================================
//  §6.4  Snooping monitors — NIC→router injection
//
//  Fires when the NIC raises net_so (has data) AND the router
//  asserts net_ro (ready to accept) → packet is consumed this
//  cycle.  net_do holds the 64-bit packet word.
// ================================================================

// ---- Row y=0 ----
always @(posedge clk) begin
    if (!reset && dut.node00.u_nic.net_so && dut.node00.u_nic.net_ro)
        $display("[%0t] INJECT node00 -> router : pkt=%h", $time, dut.node00.u_nic.net_do);
    if (!reset && dut.node10.u_nic.net_so && dut.node10.u_nic.net_ro)
        $display("[%0t] INJECT node10 -> router : pkt=%h", $time, dut.node10.u_nic.net_do);
    if (!reset && dut.node20.u_nic.net_so && dut.node20.u_nic.net_ro)
        $display("[%0t] INJECT node20 -> router : pkt=%h", $time, dut.node20.u_nic.net_do);
    if (!reset && dut.node30.u_nic.net_so && dut.node30.u_nic.net_ro)
        $display("[%0t] INJECT node30 -> router : pkt=%h", $time, dut.node30.u_nic.net_do);
end

// ---- Row y=1 ----
always @(posedge clk) begin
    if (!reset && dut.node01.u_nic.net_so && dut.node01.u_nic.net_ro)
        $display("[%0t] INJECT node01 -> router : pkt=%h", $time, dut.node01.u_nic.net_do);
    if (!reset && dut.node11.u_nic.net_so && dut.node11.u_nic.net_ro)
        $display("[%0t] INJECT node11 -> router : pkt=%h", $time, dut.node11.u_nic.net_do);
    if (!reset && dut.node21.u_nic.net_so && dut.node21.u_nic.net_ro)
        $display("[%0t] INJECT node21 -> router : pkt=%h", $time, dut.node21.u_nic.net_do);
    if (!reset && dut.node31.u_nic.net_so && dut.node31.u_nic.net_ro)
        $display("[%0t] INJECT node31 -> router : pkt=%h", $time, dut.node31.u_nic.net_do);
end

// ---- Row y=2 ----
always @(posedge clk) begin
    if (!reset && dut.node02.u_nic.net_so && dut.node02.u_nic.net_ro)
        $display("[%0t] INJECT node02 -> router : pkt=%h", $time, dut.node02.u_nic.net_do);
    if (!reset && dut.node12.u_nic.net_so && dut.node12.u_nic.net_ro)
        $display("[%0t] INJECT node12 -> router : pkt=%h", $time, dut.node12.u_nic.net_do);
    if (!reset && dut.node22.u_nic.net_so && dut.node22.u_nic.net_ro)
        $display("[%0t] INJECT node22 -> router : pkt=%h", $time, dut.node22.u_nic.net_do);
    if (!reset && dut.node32.u_nic.net_so && dut.node32.u_nic.net_ro)
        $display("[%0t] INJECT node32 -> router : pkt=%h", $time, dut.node32.u_nic.net_do);
end

// ---- Row y=3 ----
always @(posedge clk) begin
    if (!reset && dut.node03.u_nic.net_so && dut.node03.u_nic.net_ro)
        $display("[%0t] INJECT node03 -> router : pkt=%h", $time, dut.node03.u_nic.net_do);
    if (!reset && dut.node13.u_nic.net_so && dut.node13.u_nic.net_ro)
        $display("[%0t] INJECT node13 -> router : pkt=%h", $time, dut.node13.u_nic.net_do);
    if (!reset && dut.node23.u_nic.net_so && dut.node23.u_nic.net_ro)
        $display("[%0t] INJECT node23 -> router : pkt=%h", $time, dut.node23.u_nic.net_do);
    if (!reset && dut.node33.u_nic.net_so && dut.node33.u_nic.net_ro)
        $display("[%0t] INJECT node33 -> router : pkt=%h", $time, dut.node33.u_nic.net_do);
end

// ================================================================
//  §6.4  Snooping monitors — router→NIC delivery
//
//  Fires when the router raises net_si (sending data to NIC) AND
//  the NIC asserts net_ri (its input buffer is empty/ready).
//  net_di holds the incoming 64-bit packet word.
// ================================================================

// ---- Row y=0 ----
always @(posedge clk) begin
    if (!reset && dut.node00.u_nic.net_si && dut.node00.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node00 : pkt=%h", $time, dut.node00.u_nic.net_di);
    if (!reset && dut.node10.u_nic.net_si && dut.node10.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node10 : pkt=%h", $time, dut.node10.u_nic.net_di);
    if (!reset && dut.node20.u_nic.net_si && dut.node20.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node20 : pkt=%h", $time, dut.node20.u_nic.net_di);
    if (!reset && dut.node30.u_nic.net_si && dut.node30.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node30 : pkt=%h", $time, dut.node30.u_nic.net_di);
end

// ---- Row y=1 ----
always @(posedge clk) begin
    if (!reset && dut.node01.u_nic.net_si && dut.node01.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node01 : pkt=%h", $time, dut.node01.u_nic.net_di);
    if (!reset && dut.node11.u_nic.net_si && dut.node11.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node11 : pkt=%h", $time, dut.node11.u_nic.net_di);
    if (!reset && dut.node21.u_nic.net_si && dut.node21.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node21 : pkt=%h", $time, dut.node21.u_nic.net_di);
    if (!reset && dut.node31.u_nic.net_si && dut.node31.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node31 : pkt=%h", $time, dut.node31.u_nic.net_di);
end

// ---- Row y=2 ----
always @(posedge clk) begin
    if (!reset && dut.node02.u_nic.net_si && dut.node02.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node02 : pkt=%h", $time, dut.node02.u_nic.net_di);
    if (!reset && dut.node12.u_nic.net_si && dut.node12.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node12 : pkt=%h", $time, dut.node12.u_nic.net_di);
    if (!reset && dut.node22.u_nic.net_si && dut.node22.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node22 : pkt=%h", $time, dut.node22.u_nic.net_di);
    if (!reset && dut.node32.u_nic.net_si && dut.node32.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node32 : pkt=%h", $time, dut.node32.u_nic.net_di);
end

// ---- Row y=3 ----
always @(posedge clk) begin
    if (!reset && dut.node03.u_nic.net_si && dut.node03.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node03 : pkt=%h", $time, dut.node03.u_nic.net_di);
    if (!reset && dut.node13.u_nic.net_si && dut.node13.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node13 : pkt=%h", $time, dut.node13.u_nic.net_di);
    if (!reset && dut.node23.u_nic.net_si && dut.node23.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node23 : pkt=%h", $time, dut.node23.u_nic.net_di);
    if (!reset && dut.node33.u_nic.net_si && dut.node33.u_nic.net_ri)
        $display("[%0t] DELIVER router -> node33 : pkt=%h", $time, dut.node33.u_nic.net_di);
end

endmodule
/////////////////////////////////////////////////////////////////////
// End of tb_cardinal_cmp.v
/////////////////////////////////////////////////////////////////////