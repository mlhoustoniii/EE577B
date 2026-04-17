`timescale 1ns/1ps
// ============================================================
// tb_cardinal_nic.v -- Cardinal NIC Comprehensive Testbench
// EE 577B VLSI Design Projects
//
// Covers all spec-required verification cases plus full
// behavioral coverage of every NIC rule.
//
// Test Cases:
//   TC1  : Reset -- net_so=0, net_ri=1, d_out=0, both status=0
//   TC2  : NIC disabled (nicEn=0) -- d_out always 0
//   TC3  : [Spec Case 3] Proc STORE, output buffer AVAILABLE
//            -> packet written, output_status->1, net_do=packet
//   TC4  : [Spec Case 4] Proc STORE, output buffer UNAVAILABLE
//            -> write silently ignored, original data preserved
//   TC5  : [Spec Case 1] Proc LOAD, input buffer AVAILABLE
//            -> d_out=packet, input_status->0 (net_ri->1)
//   TC6  : [Spec Case 2] Proc LOAD, input buffer UNAVAILABLE
//            -> d_out=0 (empty buffer contents)
//   TC7  : Input status register (addr=2'b01) read
//            -> d_out[0]=0 when empty, d_out[0]=1 when full
//   TC8  : Output status register (addr=2'b11) read
//            -> d_out[0]=0 when empty, d_out[0]=1 when full
//   TC9  : net_ri Moore behavior -- instant with input_status
//   TC10 : net_so Mealy -- all 3 conditions must be true simultaneously
//            Verify: net_so=0 when net_ro=0 (blocked)
//            Verify: net_so=0 when polarity mismatches vc bit
//            Verify: net_so=1 when all 3 conditions met
//   TC11 : Polarity-based injection (vc=0 vs vc=1 packets)
//   TC12 : NIC->Router handshake WITHOUT blocking (net_ro=1 always)
//            Full cycle: proc write -> net_so asserted -> clear
//   TC13 : NIC->Router handshake WITH blocking (net_ro=0 then 1)
//            Packet stalls while net_ro=0; flushes when net_ro=1
//   TC14 : Router->NIC handshake WITHOUT blocking (net_ri=1 initially)
//            Router sends -> input buffer fills -> net_ri deasserts
//   TC15 : Router->NIC handshake WITH blocking (buffer full)
//            net_ri=0 -> router cannot send -> no overwrite
//   TC16 : Back-to-back input packets (read-then-receive cycle)
//   TC17 : Re-reset mid-simulation -- all state clears
//   TC18 : Full NIC pipeline: proc write -> router sends -> proc reads
//            Verifies complete bidirectional operation
//
// NIC Interface Summary:
//   Processor side:
//     addr[1:0]  : 2'b00=in_buf, 2'b01=in_stat, 2'b10=out_buf, 2'b11=out_stat
//     d_in[63:0] : data processor writes (load/store)
//     d_out[63:0]: data processor reads (registered -- valid NEXT posedge)
//     nicEn      : enable (0 -> d_out=0)
//     nicWrEn    : write enable (1=store, 0=load)
//   Network side:
//     net_si, net_ri, net_di : input channel (router -> NIC)
//     net_so, net_ro, net_do : output channel (NIC -> router)
//     net_polarity           : current VC polarity from router
//
// Timing:
//   Clock: 250 MHz -> 4 ns period (2 ns half-period)
//   Reset: synchronous active-high; released at negedge clk
//   d_out: registered -> stimulus at negedge, read d_out after posedge
// ============================================================

module tb_cardinal_nic;

    // ----------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------
    parameter CLK_HALF  = 2;     // 2 ns -> 4 ns period
    parameter RST_CYCS  = 5;     // Reset held cycles
    parameter MAX_WAIT  = 100;   // Timeout cycles per operation

    // ----------------------------------------------------------
    // Clock
    // ----------------------------------------------------------
    reg clk;
    initial  clk = 1'b0;
    always #(CLK_HALF) clk = ~clk;

    // ----------------------------------------------------------
    // DUT Ports
    // ----------------------------------------------------------
    reg        reset;

    // Processor interface
    reg  [1:0]  addr;
    reg  [63:0] d_in;
    wire [63:0] d_out;
    reg         nicEn;
    reg         nicWrEn;

    // Network input channel (router -> NIC)
    reg         net_si;
    wire        net_ri;
    reg  [63:0] net_di;

    // Network output channel (NIC -> router)
    wire        net_so;
    reg         net_ro;
    wire [63:0] net_do;

    // Polarity (driven by TB to simulate router polarity signal)
    reg         net_polarity;

    // ----------------------------------------------------------
    // DUT Instantiation
    // ----------------------------------------------------------
    cardinal_nic dut (
        .clk         (clk),
        .reset       (reset),
        .addr        (addr),
        .d_in        (d_in),
        .d_out       (d_out),
        .nicEn       (nicEn),
        .nicWrEn     (nicWrEn),
        .net_si      (net_si),
        .net_ri      (net_ri),
        .net_di      (net_di),
        .net_so      (net_so),
        .net_ro      (net_ro),
        .net_do      (net_do),
        .net_polarity(net_polarity)
    );

    // ----------------------------------------------------------
    // Verification counters
    // ----------------------------------------------------------
    integer pass_count;
    integer fail_count;

    // ----------------------------------------------------------
    // Helper: assert one check and print result
    // ----------------------------------------------------------
    task check;
        input         actual;
        input         expected;
        input [127:0] label;
        input integer tc;
        begin
            if (actual === expected) begin
                $display("  PASS [TC%0d] %s = %0b", tc, label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [TC%0d] %s : got %0b expected %0b",
                         tc, label, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------
    // Helper: assert 64-bit value check
    // ----------------------------------------------------------
    task check64;
        input [63:0]  actual;
        input [63:0]  expected;
        input [127:0] label;
        input integer tc;
        begin
            if (actual === expected) begin
                $display("  PASS [TC%0d] %s = %h", tc, label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [TC%0d] %s : got %h expected %h",
                         tc, label, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------
    // Task: release all processor interface signals to idle
    // Idle = NIC disabled, no write, addr=0, data=0
    // ----------------------------------------------------------
    task proc_idle;
        begin
            nicEn   = 1'b0;
            nicWrEn = 1'b0;
            addr    = 2'b00;
            d_in    = 64'h0;
        end
    endtask

    // ----------------------------------------------------------
    // Task: processor STORE to output buffer (addr=2'b10)
    //   Drive signals at negedge, hold for one full cycle
    //   NIC latches at the following posedge
    // ----------------------------------------------------------
    task proc_store;
        input [63:0] data;
        begin
            @(negedge clk);
            nicEn   = 1'b1;
            nicWrEn = 1'b1;
            addr    = 2'b10;
            d_in    = data;
            @(negedge clk);         // Hold through posedge
            proc_idle;
        end
    endtask

    // ----------------------------------------------------------
    // Task: processor LOAD from any address
    //   Drive at negedge; d_out valid AFTER next posedge
    //   Returns d_out sampled after the following posedge
    // ----------------------------------------------------------
    task proc_load;
        input  [1:0]  a;
        output [63:0] result;
        begin
            @(negedge clk);
            nicEn   = 1'b1;
            nicWrEn = 1'b0;
            addr    = a;
            d_in    = 64'h0;
            @(posedge clk);         // NIC registers d_out here
            #0.5;                   // Small delta after posedge settle
            result = d_out;
            @(negedge clk);
            proc_idle;
        end
    endtask

    // ----------------------------------------------------------
    // Task: drive reset
    //   Assert at posedge boundary, release at negedge per spec
    // ----------------------------------------------------------
    task do_reset;
        begin
            @(negedge clk);
            reset = 1'b1;
            $display("  Reset asserted at %0t", $time);
            repeat(RST_CYCS) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
            $display("  Reset released at %0t", $time);
        end
    endtask

    // ----------------------------------------------------------
    // Task: router sends one packet to NIC
    //   Asserts net_si for one cycle (checks net_ri first)
    //   Returns 1 if handshake succeeded, 0 if NIC was full
    // ----------------------------------------------------------
    task router_send;
        input [63:0] data;
        output       accepted;
        begin
            @(negedge clk);
            if (net_ri === 1'b1) begin
                net_si = 1'b1;
                net_di = data;
                @(negedge clk);
                net_si = 1'b0;
                net_di = 64'h0;
                accepted = 1'b1;
            end else begin
                net_si   = 1'b0;
                accepted = 1'b0;
                $display("  Note: Router send attempted but net_ri=0 (NIC full)");
            end
        end
    endtask

    // ----------------------------------------------------------
    // Task: wait for net_so to assert, then accept
    //   Simulates router accepting NIC's outgoing packet
    //   Drives net_ro=1 if not already, waits for net_so=1
    // ----------------------------------------------------------
    task router_accept;
        input integer tc;
        integer wcnt;
        begin
            wcnt = 0;
            @(posedge clk);
            while (net_so !== 1'b1) begin
                @(posedge clk);
                wcnt = wcnt + 1;
                if (wcnt > MAX_WAIT) begin
                    $display("  TIMEOUT [TC%0d] Waiting for net_so", tc);
                    fail_count = fail_count + 1;
                    disable router_accept;
                end
            end
            $display("  [TC%0d] Router saw net_so=1, net_do=%h at %0t",
                     tc, net_do, $time);
        end
    endtask

    // ----------------------------------------------------------
    // Main test program
    // ----------------------------------------------------------
    reg [63:0] result;
    reg        accepted;
    reg [63:0] pkt_a, pkt_b, pkt_vc0, pkt_vc1;
    integer    wcnt;

    initial begin
        // ------ Waveform dump ------
        $dumpfile("tb_cardinal_nic.vcd");
        $dumpvars(0, tb_cardinal_nic);

        // ------ Initialize counters ------
        pass_count   = 0;
        fail_count   = 0;

        // ------ Define test packets ------
        // pkt_vc0: vc=0 -> packet[63]=0 -> net_so fires when polarity=0
        // pkt_vc1: vc=1 -> packet[63]=1 -> net_so fires when polarity=1
        pkt_vc0 = 64'h0000_0000_DEAD_BEEF; // bit[63]=0
        pkt_vc1 = 64'h8000_0000_CAFE_F00D; // bit[63]=1
        pkt_a   = 64'h1234_5678_ABCD_EF01;
        pkt_b   = 64'hFEDC_BA98_7654_3210;

        // ------ Initialize all inputs ------
        reset       = 1'b0;
        nicEn       = 1'b0;
        nicWrEn     = 1'b0;
        addr        = 2'b00;
        d_in        = 64'h0;
        net_si      = 1'b0;
        net_di      = 64'h0;
        net_ro      = 1'b1;     // Router always ready by default
        net_polarity= 1'b0;

        $display("\n+======================================================+");
        $display("|   EE577B -- Cardinal NIC Comprehensive Testbench     |");
        $display("|   DUT: cardinal_nic   Clock: 250MHz (4ns)           |");
        $display("+======================================================+\n");

        // ==========================================================
        // TC1 -- RESET BEHAVIOR
        //
        // Per spec:
        //   net_so  = 0  (output_status=0 -> Mealy expression false)
        //   net_ri  = 1  (input_status=0  -> ~input_status = 1)
        //   d_out   = 0  (registered, cleared on reset)
        //   Both internal status registers = 0
        //
        // Check DURING reset (synchronous, so after at least one posedge)
        // Check polarity of net_ri/net_so (combinational -- immediate)
        // ==========================================================
        $display("=== TC1: Reset Behavior ===");

        @(negedge clk);
        reset = 1'b1;
        repeat(RST_CYCS) @(posedge clk);
        #0.5; // Small settle after last posedge

        // net_ri must be 1 (Moore: ~input_status, input_status=0 after reset)
        check(net_ri, 1'b1, "net_ri during reset", 1);

        // net_so must be 0 (Mealy: output_status=0 after reset)
        check(net_so, 1'b0, "net_so during reset", 1);

        // d_out must be 0 (registered, reset clears it)
        check64(d_out, 64'h0, "d_out during reset", 1);

        // net_do must reflect net_output_buf = 0 after reset
        check64(net_do, 64'h0, "net_do during reset", 1);

        // Check that polarity of net_ri is combinatorial -- still 1
        // even when we momentarily try driving net_si (buffer empty)
        net_si = 1'b1;
        net_di = pkt_a;
        #0.1;
        check(net_ri, 1'b1,
              "net_ri=1 during reset even with net_si=1", 1);
        net_si = 1'b0;
        net_di = 64'h0;

        // Release reset at negedge per spec requirement
        @(negedge clk);
        reset = 1'b0;
        $display("  Reset released at %0t", $time);

        // Immediately after reset release: both signals same (no posedge yet)
        @(posedge clk); #0.5;
        check(net_ri, 1'b1, "net_ri=1 post-reset (buffers empty)", 1);
        check(net_so, 1'b0, "net_so=0 post-reset (output buf empty)", 1);
        check64(d_out, 64'h0, "d_out=0 post-reset", 1);

        // Read status registers -- both should report 0 (empty)
        proc_load(2'b01, result); // Input status
        check64(result, 64'h0, "input_status=0 after reset", 1);

        proc_load(2'b11, result); // Output status
        check64(result, 64'h0, "output_status=0 after reset", 1);

        $display("  [TC1] DONE\n");

        // ==========================================================
        // TC2 -- NIC DISABLED (nicEn=0)
        //
        // Per spec: when nicEn=0, d_out = 0 regardless of addr,
        //           nicWrEn, or register contents
        // Test with all four addresses while a packet is present
        // ==========================================================
        $display("=== TC2: NIC Disabled (nicEn=0) ===");

        // First put a packet in the input buffer via network
        @(negedge clk);
        net_si = 1'b1;
        net_di = pkt_a;
        @(negedge clk);
        net_si = 1'b0;
        net_di = 64'h0;
        @(posedge clk); #0.5; // Let input buffer fill

        // NIC disabled -- d_out must be 0 for all addresses
        @(negedge clk);
        nicEn   = 1'b0;
        nicWrEn = 1'b0;

        addr = 2'b00; @(posedge clk); #0.5;
        check64(d_out, 64'h0, "d_out=0 nicEn=0 addr=00", 2);

        addr = 2'b01; @(posedge clk); #0.5;
        check64(d_out, 64'h0, "d_out=0 nicEn=0 addr=01", 2);

        addr = 2'b10; @(posedge clk); #0.5;
        check64(d_out, 64'h0, "d_out=0 nicEn=0 addr=10", 2);

        addr = 2'b11; @(posedge clk); #0.5;
        check64(d_out, 64'h0, "d_out=0 nicEn=0 addr=11", 2);

        @(negedge clk);
        proc_idle;

        // Clean up: read out the packet so buffer empties for next TC
        proc_load(2'b00, result); // This also clears input_status

        $display("  [TC2] DONE\n");

        // ==========================================================
        // TC3 -- [SPEC CASE 3] PROC STORE, BUFFER AVAILABLE
        //
        // Precondition: output buffer empty (output_status=0)
        // Action:       nicEn=1, nicWrEn=1, addr=2'b10, d_in=pkt_a
        // Expected:
        //   - output_status -> 1 (at next posedge)
        //   - net_do = pkt_a (combinational, immediate)
        //   - net_so fires when net_ro=1 AND polarity matches vc bit
        //   - After successful send: output_status -> 0
        // ==========================================================
        $display("=== TC3: Proc STORE -- Buffer AVAILABLE ===");

        // Verify output buffer is empty before test
        proc_load(2'b11, result);
        check64(result, 64'h0, "pre-TC3: output_status=0", 3);

        // Write pkt_vc0 (vc=0) to output buffer
        proc_store(pkt_vc0);

        // Check status at next posedge (drive was at negedge, latch at posedge)
        @(posedge clk); #0.5;
        // net_do must reflect buffer contents immediately (combinational)
        check64(net_do, pkt_vc0, "net_do = pkt_vc0 after store", 3);

        // Read output_status register -- should be 1 (full)
        proc_load(2'b11, result);
        check64(result, 64'h1, "output_status=1 after store", 3);

        // net_so should be 0 if polarity doesn't match vc bit yet
        // pkt_vc0[63]=0, so need net_polarity=0 for net_so to fire
        // Currently net_polarity=0 and net_ro=1, so net_so SHOULD be 1
        @(posedge clk); #0.5;
        check(net_so, 1'b1,
              "net_so=1 when polarity=0 matches vc=0", 3);

        // Let the send clear: output_status -> 0 at next posedge
        @(posedge clk); #0.5;
        proc_load(2'b11, result);
        check64(result, 64'h0, "output_status=0 after successful send", 3);

        $display("  [TC3] DONE\n");

        // ==========================================================
        // TC4 -- [SPEC CASE 4] PROC STORE, BUFFER UNAVAILABLE (IGNORE)
        //
        // Precondition: output buffer full (output_status=1)
        // Action:       nicEn=1, nicWrEn=1, addr=2'b10, d_in=pkt_b
        // Expected:
        //   - Write is SILENTLY IGNORED
        //   - Original packet still in buffer (no corruption)
        //   - output_status remains 1
        //
        // To set up: write a packet then block the network so it stays
        // in the buffer (net_ro=0 prevents automatic drain)
        // ==========================================================
        $display("=== TC4: Proc STORE -- Buffer UNAVAILABLE (Ignored) ===");

        // Block the router so the output buffer won't drain
        @(negedge clk);
        net_ro = 1'b0;
        $display("  net_ro=0 (blocking NIC output)");

        // Write first packet -- buffer was empty, this should succeed
        proc_store(pkt_vc0);
        @(posedge clk); #0.5;

        // Confirm buffer is now full
        proc_load(2'b11, result);
        check64(result, 64'h1, "output_status=1 after first store", 4);

        // Confirm original data in net_do
        check64(net_do, pkt_vc0, "net_do=pkt_vc0 (original)", 4);

        // Now attempt to write a DIFFERENT packet while buffer is full
        $display("  Attempting second store while buffer full (should be ignored)...");
        proc_store(pkt_b); // This should be IGNORED

        @(posedge clk); #0.5;

        // net_do must STILL be pkt_vc0 -- pkt_b must NOT have overwritten it
        check64(net_do, pkt_vc0,
                "net_do still=pkt_vc0 (pkt_b ignored)", 4);

        // output_status still 1
        proc_load(2'b11, result);
        check64(result, 64'h1,
                "output_status still=1 (no double-free)", 4);

        // Verify net_so is 0 because net_ro=0 (blocked)
        check(net_so, 1'b0, "net_so=0 while net_ro=0", 4);

        // Unblock and let it drain
        @(negedge clk);
        net_ro = 1'b1;
        @(posedge clk); #0.5;
        // net_polarity=0 matches pkt_vc0[63]=0, so it should send now
        // Wait one more posedge for status to clear
        @(posedge clk); #0.5;
        proc_load(2'b11, result);
        check64(result, 64'h0, "output_status=0 after unblock drain", 4);

        $display("  [TC4] DONE\n");

        // ==========================================================
        // TC5 -- [SPEC CASE 1] PROC LOAD, INPUT BUFFER AVAILABLE
        //
        // Precondition: input buffer has a packet (input_status=1)
        // Action:       nicEn=1, nicWrEn=0, addr=2'b00
        // Expected:
        //   - d_out = buffered packet (at next posedge)
        //   - input_status -> 0 SIMULTANEOUSLY (same posedge)
        //   - net_ri -> 1 (combinational from input_status=0)
        // ==========================================================
        $display("=== TC5: Proc LOAD -- Input Buffer AVAILABLE ===");

        // Confirm input buffer is empty before test
        check(net_ri, 1'b1, "pre-TC5: net_ri=1 (buffer empty)", 5);

        // Send packet from router -> NIC
        @(negedge clk);
        net_si = 1'b1;
        net_di = pkt_a;
        @(negedge clk);
        net_si = 1'b0;
        net_di = 64'h0;

        // After posedge: input buffer should be full
        @(posedge clk); #0.5;
        check(net_ri, 1'b0, "net_ri=0 (input buffer full)", 5);

        // Verify input status register = 1
        proc_load(2'b01, result);
        check64(result, 64'h1, "input_status=1 (buffer full)", 5);

        // Now read the input buffer -- this is the actual load
        @(negedge clk);
        nicEn   = 1'b1;
        nicWrEn = 1'b0;
        addr    = 2'b00;
        @(posedge clk); #0.5; // d_out registers here; input_status also clears
        result = d_out;
        check64(result, pkt_a, "d_out = pkt_a (correct packet)", 5);

        // input_status clears at the SAME posedge as the read
        check(net_ri, 1'b1,
              "net_ri->1 immediately (status cleared on read)", 5);

        @(negedge clk);
        proc_idle;

        // Confirm status register now 0
        proc_load(2'b01, result);
        check64(result, 64'h0, "input_status=0 after proc read", 5);

        $display("  [TC5] DONE\n");

        // ==========================================================
        // TC6 -- [SPEC CASE 2] PROC LOAD, INPUT BUFFER UNAVAILABLE
        //
        // Precondition: input buffer empty (input_status=0)
        // Action:       nicEn=1, nicWrEn=0, addr=2'b00
        // Expected:
        //   - d_out reflects empty buffer contents (= 0)
        //   - input_status stays 0
        //   - net_ri stays 1
        // ==========================================================
        $display("=== TC6: Proc LOAD -- Input Buffer UNAVAILABLE ===");

        // Precondition: verify buffer is empty
        check(net_ri, 1'b1, "pre-TC6: net_ri=1 (buffer empty)", 6);

        proc_load(2'b00, result);
        check64(result, 64'h0, "d_out=0 when buffer empty", 6);

        // Status must remain 0
        proc_load(2'b01, result);
        check64(result, 64'h0, "input_status stays 0 after empty read", 6);

        // net_ri must remain 1 (no spurious status set)
        check(net_ri, 1'b1, "net_ri still 1 after empty read", 6);

        $display("  [TC6] DONE\n");

        // ==========================================================
        // TC7 -- INPUT STATUS REGISTER (addr=2'b01)
        //
        // Verify d_out[0] is the status bit, d_out[63:1]=0
        //   Empty: d_out = 64'h0000_0000_0000_0000
        //   Full:  d_out = 64'h0000_0000_0000_0001
        // ==========================================================
        $display("=== TC7: Input Status Register Read ===");

        // Phase A: empty state
        proc_load(2'b01, result);
        check64(result, 64'h0, "in_status reg = 0x0 when empty", 7);
        check(result[0], 1'b0, "in_status[0]=0 when empty", 7);
        check64(result[63:1], 63'h0, "in_status[63:1]=0 always", 7);

        // Phase B: fill buffer
        @(negedge clk);
        net_si = 1'b1;
        net_di = pkt_b;
        @(negedge clk);
        net_si = 1'b0;
        @(posedge clk); #0.5;

        proc_load(2'b01, result);
        check64(result, 64'h1, "in_status reg = 0x1 when full", 7);
        check(result[0], 1'b1, "in_status[0]=1 when full", 7);
        check64(result[63:1], 63'h0, "in_status[63:1]=0 always (full)", 7);

        // Clean up
        proc_load(2'b00, result); // Read and clear

        $display("  [TC7] DONE\n");

        // ==========================================================
        // TC8 -- OUTPUT STATUS REGISTER (addr=2'b11)
        //
        // Verify d_out[0] reflects output_status, d_out[63:1]=0
        //   Empty: d_out = 64'h0
        //   Full:  d_out = 64'h1
        // ==========================================================
        $display("=== TC8: Output Status Register Read ===");

        // Phase A: empty
        proc_load(2'b11, result);
        check64(result, 64'h0, "out_status reg = 0x0 when empty", 8);
        check(result[0], 1'b0, "out_status[0]=0 when empty", 8);

        // Phase B: fill -- block router so packet stays
        @(negedge clk);
        net_ro = 1'b0;
        proc_store(pkt_vc0);
        @(posedge clk); #0.5;

        proc_load(2'b11, result);
        check64(result, 64'h1, "out_status reg = 0x1 when full", 8);
        check(result[0], 1'b1, "out_status[0]=1 when full", 8);
        check64(result[63:1], 63'h0, "out_status[63:1]=0 always", 8);

        // Phase C: unblock and let drain
        @(negedge clk);
        net_ro = 1'b1;
        @(posedge clk);
        @(posedge clk); #0.5;

        proc_load(2'b11, result);
        check64(result, 64'h0, "out_status reg = 0x0 after drain", 8);

        $display("  [TC8] DONE\n");

        // ==========================================================
        // TC9 -- net_ri MOORE BEHAVIOR
        //
        // net_ri is purely combinational: net_ri = ~input_status
        // Must change INSTANTANEOUSLY with input_status, not one
        // cycle later. No registered delay permitted.
        //
        // Test:
        //   1. Confirm net_ri=1 when buffer empty
        //   2. Send packet -> at posedge: input_status->1 -> net_ri->0
        //   3. Proc reads -> at same posedge: input_status->0 -> net_ri->1
        // ==========================================================
        $display("=== TC9: net_ri Moore Behavior ===");

        // Step 1: buffer empty
        check(net_ri, 1'b1, "net_ri=1 (initial, buffer empty)", 9);

        // Step 2: send packet, check net_ri goes low at posedge
        @(negedge clk);
        net_si = 1'b1;
        net_di = pkt_a;
        @(posedge clk); #0.5; // input_status latches to 1 here
        net_si = 1'b0;

        check(net_ri, 1'b0,
              "net_ri=0 immediately after input buffer fills", 9);

        // net_ri must not be some delayed version -- verify it's combinational
        // by toggling net_si without a clock edge and confirming no change
        // (net_ri reflects input_status which only changes at posedge)
        net_si = 1'b1; // no clock edge
        #0.2;
        check(net_ri, 1'b0,
              "net_ri stays 0 (combinational from state, not input)", 9);
        net_si = 1'b0;

        // Step 3: proc reads -> input_status->0 -> net_ri->1 same cycle
        @(negedge clk);
        nicEn   = 1'b1;
        nicWrEn = 1'b0;
        addr    = 2'b00;
        @(posedge clk); #0.5; // input_status clears here
        check(net_ri, 1'b1,
              "net_ri->1 immediately as input_status cleared", 9);
        @(negedge clk); proc_idle;

        $display("  [TC9] DONE\n");

        // ==========================================================
        // TC10 -- net_so MEALY BEHAVIOR
        //
        // net_so = output_status AND net_ro AND
        //          (net_polarity == net_output_buf[63])
        //
        // Three independent conditions -- each one failing must
        // prevent net_so. Test all failure combinations:
        //
        //   A: output_status=0 -> net_so=0 (no packet)
        //   B: output_status=1, net_ro=0  -> net_so=0 (blocked)
        //   C: output_status=1, net_ro=1, polarity mismatch -> net_so=0
        //   D: all three true -> net_so=1 [OK]
        // ==========================================================
        $display("=== TC10: net_so Mealy Behavior ===");

        // Condition A: empty buffer -> net_so must be 0
        proc_load(2'b11, result);
        if (result === 64'h0) begin // confirm empty
            check(net_so, 1'b0, "net_so=0 when output_status=0", 10);
        end

        // Set up: block router, write packet (vc=1 -> fires on polarity=1)
        @(negedge clk); net_ro = 1'b0;
        proc_store(pkt_vc1);       // pkt_vc1[63]=1
        @(posedge clk); #0.5;

        // Condition B: output_status=1, net_ro=0 -> net_so must be 0
        check(net_so, 1'b0, "net_so=0 when net_ro=0 (blocked)", 10);

        // Condition C: net_ro=1, but polarity=0 ? vc=1 -> net_so=0
        @(negedge clk);
        net_ro      = 1'b1;
        net_polarity= 1'b0;   // mismatch: packet is vc=1
        #0.1;
        check(net_so, 1'b0,
              "net_so=0 when polarity=0 != vc=1 (mismatch)", 10);

        // Condition D: net_ro=1, polarity=1 = vc=1 -> net_so must be 1
        @(negedge clk);
        net_polarity= 1'b1;   // now matches pkt_vc1[63]=1
        #0.1;
        check(net_so, 1'b1,
              "net_so=1 when all three conditions met", 10);

        // Let it clear
        @(posedge clk); #0.5;
        check(net_so, 1'b0,
              "net_so=0 after output_status cleared", 10);

        net_polarity = 1'b0; // restore default

        $display("  [TC10] DONE\n");

        // ==========================================================
        // TC11 -- POLARITY-BASED INJECTION
        //
        // vc=0 (packet[63]=0): net_so fires only when net_polarity=0
        // vc=1 (packet[63]=1): net_so fires only when net_polarity=1
        //
        // This is the critical deadlock-prevention mechanism.
        // Test both vc types with both polarity values.
        // ==========================================================
        $display("=== TC11: Polarity-Based VC Injection ===");

        // ---- vc=0 packet ----
        $display("  Testing vc=0 packet (pkt[63]=0)...");

        // Block so packet stays in buffer
        @(negedge clk); net_ro = 1'b0;
        proc_store(pkt_vc0);        // pkt_vc0[63]=0
        @(posedge clk); #0.5;

        // polarity=1: should NOT fire (mismatch)
        net_polarity = 1'b1;
        #0.1;
        check(net_so, 1'b0,
              "vc=0 pkt: net_so=0 when polarity=1 (mismatch)", 11);

        // polarity=0: should fire (match), but net_ro=0 so still blocked
        net_polarity = 1'b0;
        #0.1;
        check(net_so, 1'b0,
              "vc=0 pkt: net_so=0 when polarity=0 but net_ro=0", 11);

        // polarity=0 AND net_ro=1 -> fires
        net_ro = 1'b1;
        #0.1;
        check(net_so, 1'b1,
              "vc=0 pkt: net_so=1 when polarity=0 and net_ro=1", 11);

        @(posedge clk); #0.5; // Let it clear
        check(net_so, 1'b0, "vc=0 pkt: net_so cleared after send", 11);

        // ---- vc=1 packet ----
        $display("  Testing vc=1 packet (pkt[63]=1)...");

        @(negedge clk); net_ro = 1'b0;
        proc_store(pkt_vc1);        // pkt_vc1[63]=1
        @(posedge clk); #0.5;

        // polarity=0: should NOT fire (mismatch)
        net_polarity = 1'b0;
        #0.1;
        check(net_so, 1'b0,
              "vc=1 pkt: net_so=0 when polarity=0 (mismatch)", 11);

        // polarity=1 AND net_ro=1 -> fires
        net_ro      = 1'b1;
        net_polarity= 1'b1;
        #0.1;
        check(net_so, 1'b1,
              "vc=1 pkt: net_so=1 when polarity=1 and net_ro=1", 11);

        @(posedge clk); #0.5;
        net_polarity = 1'b0;

        $display("  [TC11] DONE\n");

        // ==========================================================
        // TC12 -- NIC->ROUTER HANDSHAKE, NO BLOCKING
        //
        // Full cycle with net_ro=1 always:
        //   1. Proc writes packet to output buffer
        //   2. net_do immediately reflects packet
        //   3. net_so asserts once polarity matches
        //   4. At next posedge: output_status clears
        //   5. net_so deasserts (output_status=0)
        //   6. output status register reads 0
        //
        // Verifies complete one-way datapath without stalls
        // ==========================================================
        $display("=== TC12: NIC->Router Handshake No Blocking ===");

        net_ro      = 1'b1;
        net_polarity= 1'b0;   // pkt_vc0[63]=0 will fire on polarity=0

        // Step 1: verify output buffer empty
        check(net_so, 1'b0, "pre-TC12: net_so=0 (buffer empty)", 12);

        // Step 2: proc writes packet
        $display("  Proc stores pkt_vc0 to output buffer...");
        @(negedge clk);
        nicEn   = 1'b1;
        nicWrEn = 1'b1;
        addr    = 2'b10;
        d_in    = pkt_vc0;

        // Step 3: at posedge -- output_status=1, net_so should fire
        @(posedge clk); #0.5;
        check64(net_do, pkt_vc0, "net_do=pkt_vc0 (immediate)", 12);
        check(net_so, 1'b1, "net_so=1 after store (polarity match)", 12);
        $display("  Router sees net_so=1, net_do=%h", net_do);

        @(negedge clk); proc_idle;

        // Step 4: at next posedge -- output_status clears, net_so drops
        @(posedge clk); #0.5;
        check(net_so, 1'b0,
              "net_so=0 after send (output_status cleared)", 12);

        // Step 5: verify status register
        proc_load(2'b11, result);
        check64(result, 64'h0, "output_status reg=0 after send", 12);

        $display("  [TC12] DONE\n");

        // ==========================================================
        // TC13 -- NIC->ROUTER HANDSHAKE, WITH BLOCKING
        //
        // net_ro toggles to simulate a busy router:
        //   1. Proc writes packet
        //   2. Set net_ro=0 -- packet stalls in output buffer
        //   3. Confirm net_so=0 while blocked (Mealy condition fails)
        //   4. Confirm output_status stays 1 for several cycles
        //   5. Set net_ro=1 -- net_so fires immediately (combinational)
        //   6. At next posedge: output_status clears
        //
        // Demonstrates correct Mealy blocking behavior
        // ==========================================================
        $display("=== TC13: NIC->Router Handshake WITH Blocking ===");

        // Step 1: block router before writing
        @(negedge clk);
        net_ro      = 1'b0;
        net_polarity= 1'b0;   // pkt_vc0 fires on polarity=0

        proc_store(pkt_vc0);
        @(posedge clk); #0.5;

        // Step 2: confirm stalled
        check(net_so, 1'b0,
              "net_so=0 while net_ro=0 (blocked)", 13);
        check64(net_do, pkt_vc0,
                "net_do=pkt_vc0 (data held in buffer)", 13);
        $display("  Packet stalled -- output_status=1, net_ro=0");

        // Step 3: hold for several cycles and confirm stall persists
        repeat(5) begin
            @(posedge clk); #0.5;
            check(net_so, 1'b0,
                  "net_so=0 persists while net_ro=0", 13);
        end

        // Step 4: verify output_status still 1 (no spurious clear)
        proc_load(2'b11, result);
        check64(result, 64'h1,
                "output_status=1 after stall (no spurious clear)", 13);

        // Step 5: unblock at negedge -- net_so fires combinationally
        @(negedge clk);
        net_ro = 1'b1;
        #0.1;
        check(net_so, 1'b1,
              "net_so=1 immediately when net_ro->1 (Mealy)", 13);
        $display("  Router accepted: net_so=1, net_do=%h", net_do);

        // Step 6: at posedge -- output_status clears
        @(posedge clk); #0.5;
        check(net_so, 1'b0,
              "net_so=0 after send completes", 13);
        proc_load(2'b11, result);
        check64(result, 64'h0, "output_status=0 after unblock send", 13);

        $display("  [TC13] DONE\n");

        // ==========================================================
        // TC14 -- ROUTER->NIC HANDSHAKE, NO BLOCKING
        //
        // Full cycle with net_ri=1 initially:
        //   1. Confirm net_ri=1 (buffer empty)
        //   2. Router asserts net_si=1 with valid data
        //   3. At posedge: input buffer fills, net_ri->0
        //   4. Router deasserts net_si
        //   5. Proc reads input buffer
        //   6. d_out = received packet; input_status->0; net_ri->1
        //
        // Verifies complete incoming datapath
        // ==========================================================
        $display("=== TC14: Router->NIC Handshake No Blocking ===");

        // Step 1: confirm ready
        check(net_ri, 1'b1, "pre-TC14: net_ri=1 (buffer empty)", 14);

        // Step 2: router sends
        $display("  Router sending pkt_a=%h", pkt_a);
        @(negedge clk);
        net_si = 1'b1;
        net_di = pkt_a;

        // Step 3: at posedge -- input_status->1, net_ri->0
        @(posedge clk); #0.5;
        check(net_ri, 1'b0,
              "net_ri=0 immediately after data latched", 14);

        @(negedge clk);
        net_si = 1'b0;
        net_di = 64'h0;

        // Step 4: verify input status register
        proc_load(2'b01, result);
        check64(result, 64'h1, "input_status=1 after router send", 14);

        // Step 5: proc reads
        @(negedge clk);
        nicEn   = 1'b1;
        nicWrEn = 1'b0;
        addr    = 2'b00;

        @(posedge clk); #0.5;   // d_out registers; input_status clears
        result = d_out;
        check64(result, pkt_a, "d_out=pkt_a (correct received data)", 14);

        // Step 6: net_ri back to 1
        check(net_ri, 1'b1,
              "net_ri->1 immediately after proc reads", 14);
        @(negedge clk); proc_idle;

        $display("  [TC14] DONE\n");

        // ==========================================================
        // TC15 -- ROUTER->NIC HANDSHAKE, WITH BLOCKING (buffer full)
        //
        // When input buffer is full (net_ri=0), a router attempting
        // to send must NOT overwrite the buffered data.
        //
        //   1. Fill input buffer with pkt_a
        //   2. Confirm net_ri=0
        //   3. Router attempts to send pkt_b while net_ri=0
        //   4. pkt_b must NOT overwrite pkt_a
        //   5. Proc reads -> gets pkt_a
        //   6. net_ri->1 -- buffer now available again
        //   7. Router can now successfully send pkt_b
        // ==========================================================
        $display("=== TC15: Router->NIC Handshake WITH Blocking ===");

        // Step 1: fill input buffer
        @(negedge clk);
        net_si = 1'b1;
        net_di = pkt_a;
        @(negedge clk);
        net_si = 1'b0;
        net_di = 64'h0;
        @(posedge clk); #0.5;

        check(net_ri, 1'b0, "net_ri=0 (buffer full)", 15);

        // Step 2: router attempts to send pkt_b while full
        $display("  Router attempts second send while net_ri=0 (should ignore)...");
        @(negedge clk);
        net_si = 1'b1;  // Router ignores net_ri (drives anyway)
        net_di = pkt_b; // This must be ignored by NIC

        // NIC should NOT latch pkt_b because input_status=1
        @(posedge clk); #0.5;
        @(negedge clk);
        net_si = 1'b0;
        net_di = 64'h0;

        // Step 3: proc reads -- must get pkt_a, not pkt_b
        @(negedge clk);
        nicEn   = 1'b1;
        nicWrEn = 1'b0;
        addr    = 2'b00;
        @(posedge clk); #0.5;
        result = d_out;

        check64(result, pkt_a,
                "d_out=pkt_a (pkt_b was ignored, no overwrite)", 15);
        check(net_ri, 1'b1,
              "net_ri->1 after proc read (buffer freed)", 15);
        @(negedge clk); proc_idle;

        // Step 4: now router can successfully send pkt_b
        $display("  Router resending pkt_b (net_ri now 1)...");
        router_send(pkt_b, accepted);
        check(accepted, 1'b1,
              "Router send pkt_b accepted (net_ri=1)", 15);
        @(posedge clk); #0.5;
        proc_load(2'b01, result);
        check64(result, 64'h1,
                "input_status=1 after successful send", 15);
        proc_load(2'b00, result);
        check64(result, pkt_b,
                "d_out=pkt_b after successful recv", 15);

        $display("  [TC15] DONE\n");

        // ==========================================================
        // TC16 -- BACK-TO-BACK INPUT PACKETS
        //
        // Router sends pkt_a, proc reads it, router immediately
        // sends pkt_b -- verifies correct re-arm of input channel
        // after each read.
        //
        //   Cycle 1: router sends pkt_a -> NIC full
        //   Cycle 2: proc reads pkt_a  -> NIC empty -> net_ri=1
        //   Cycle 3: router sends pkt_b -> NIC full
        //   Cycle 4: proc reads pkt_b  -> verify correct data
        // ==========================================================
        $display("=== TC16: Back-to-Back Input Packets ===");

        // Round 1
        router_send(pkt_a, accepted);
        check(accepted, 1'b1, "Round1: pkt_a send accepted", 16);
        @(posedge clk); #0.5;
        check(net_ri, 1'b0,
              "Round1: net_ri=0 (buffer holds pkt_a)", 16);

        proc_load(2'b00, result);
        check64(result, pkt_a, "Round1: proc reads pkt_a", 16);
        check(net_ri, 1'b1,
              "Round1: net_ri->1 after proc read", 16);

        // Round 2 -- immediate
        router_send(pkt_b, accepted);
        check(accepted, 1'b1, "Round2: pkt_b send accepted", 16);
        @(posedge clk); #0.5;
        check(net_ri, 1'b0,
              "Round2: net_ri=0 (buffer holds pkt_b)", 16);

        proc_load(2'b00, result);
        check64(result, pkt_b, "Round2: proc reads pkt_b", 16);
        check(net_ri, 1'b1,
              "Round2: net_ri->1 after second proc read", 16);

        $display("  [TC16] DONE\n");

        // ==========================================================
        // TC17 -- RE-RESET MID-SIMULATION
        //
        // Fill BOTH buffers (input and output), then assert reset.
        // Verify all state clears:
        //   - Both buffers zeroed
        //   - Both status registers = 0
        //   - net_ri = 1 (input empty)
        //   - net_so = 0 (output empty)
        //   - d_out  = 0
        //   - net_do = 0
        // ==========================================================
        $display("=== TC17: Re-Reset Mid-Simulation ===");

        // Step 1: fill output buffer (block so it stays)
        @(negedge clk); net_ro = 1'b0;
        proc_store(pkt_vc0);
        @(posedge clk); #0.5;
        proc_load(2'b11, result);
        check64(result, 64'h1,
                "pre-TC17: output_status=1 (buffer full)", 17);

        // Step 2: fill input buffer
        router_send(pkt_a, accepted);
        @(posedge clk); #0.5;
        proc_load(2'b01, result);
        check64(result, 64'h1,
                "pre-TC17: input_status=1 (buffer full)", 17);

        // Both buffers full -- apply reset
        $display("  Applying reset with both buffers full...");
        @(negedge clk);
        reset       = 1'b1;
        net_ro      = 1'b1; // restore
        repeat(RST_CYCS) @(posedge clk); #0.5;

        // Check all reset conditions
        check(net_ri, 1'b1,
              "net_ri=1 after mid-sim reset", 17);
        check(net_so, 1'b0,
              "net_so=0 after mid-sim reset", 17);
        check64(d_out, 64'h0,
                "d_out=0 after mid-sim reset", 17);
        check64(net_do, 64'h0,
                "net_do=0 after mid-sim reset", 17);

        @(negedge clk);
        reset = 1'b0;
        @(posedge clk); #0.5;

        proc_load(2'b01, result);
        check64(result, 64'h0, "input_status=0 after reset", 17);
        proc_load(2'b11, result);
        check64(result, 64'h0, "output_status=0 after reset", 17);

        $display("  [TC17] DONE\n");

        // ==========================================================
        // TC18 -- FULL NIC PIPELINE (bidirectional)
        //
        // Demonstrates the complete NIC acting as a bridge:
        //
        //   OUTBOUND path (proc -> router):
        //     a. Proc checks output_status (should be 0)
        //     b. Proc stores packet to output buffer
        //     c. Proc checks output_status (should be 1)
        //     d. NIC waits for polarity match then asserts net_so
        //     e. Router accepts: net_so=1, net_do=packet
        //     f. Output_status clears back to 0
        //
        //   INBOUND path (router -> proc):
        //     g. Proc checks input_status (should be 0)
        //     h. Router sends packet: net_si=1, net_di=pkt
        //     i. net_ri goes 0 (buffer full)
        //     j. Proc checks input_status (should be 1)
        //     k. Proc reads packet: d_out = pkt
        //     l. input_status->0, net_ri->1
        //
        //   Both paths exercised in sequence with status polling
        // ==========================================================
        $display("=== TC18: Full NIC Pipeline (Bidirectional) ===");

        net_ro      = 1'b1;
        net_polarity= 1'b0;

        // ---- OUTBOUND ----
        $display("  --- Outbound Path ---");

        // a. Poll output status -- expect 0
        proc_load(2'b11, result);
        check64(result, 64'h0,
                "Outbound: output_status=0 before write", 18);

        // b. Proc stores pkt_vc0 (vc=0, fires on polarity=0)
        $display("  Proc writes pkt_vc0 to output buffer");
        proc_store(pkt_vc0);
        @(posedge clk); #0.5;

        // c. Poll output status -- expect 1
        proc_load(2'b11, result);
        check64(result, 64'h1,
                "Outbound: output_status=1 after write", 18);

        // d. Verify net_so fires on polarity match
        // polarity=0 already set; net_ro=1; pkt_vc0[63]=0 -> match
        check(net_so, 1'b1,
              "Outbound: net_so=1 (polarity matches vc=0)", 18);
        check64(net_do, pkt_vc0,
                "Outbound: net_do=pkt_vc0 on network", 18);
        $display("  Router receives: net_do=%h", net_do);

        // e. Let output_status clear
        @(posedge clk); #0.5;
        check(net_so, 1'b0,
              "Outbound: net_so=0 after send", 18);

        // f. Poll output status -- expect 0
        proc_load(2'b11, result);
        check64(result, 64'h0,
                "Outbound: output_status=0 after send", 18);

        // ---- INBOUND ----
        $display("  --- Inbound Path ---");

        // g. Poll input status -- expect 0
        proc_load(2'b01, result);
        check64(result, 64'h0,
                "Inbound: input_status=0 before receive", 18);
        check(net_ri, 1'b1,
              "Inbound: net_ri=1 (ready to receive)", 18);

        // h. Router sends pkt_b
        $display("  Router sends pkt_b=%h", pkt_b);
        @(negedge clk);
        net_si = 1'b1;
        net_di = pkt_b;
        @(posedge clk); #0.5; // input_status->1 here

        // i. net_ri drops
        check(net_ri, 1'b0,
              "Inbound: net_ri=0 (data received)", 18);
        @(negedge clk);
        net_si = 1'b0;

        // j. Poll input status -- expect 1
        proc_load(2'b01, result);
        check64(result, 64'h1,
                "Inbound: input_status=1 (packet waiting)", 18);

        // k. Proc reads
        $display("  Proc reads input buffer...");
        @(negedge clk);
        nicEn   = 1'b1;
        nicWrEn = 1'b0;
        addr    = 2'b00;
        @(posedge clk); #0.5;
        result = d_out;
        check64(result, pkt_b,
                "Inbound: proc reads pkt_b correctly", 18);
        @(negedge clk); proc_idle;

        // l. input_status->0, net_ri->1
        check(net_ri, 1'b1,
              "Inbound: net_ri->1 after proc read", 18);
        proc_load(2'b01, result);
        check64(result, 64'h0,
                "Inbound: input_status=0 after proc read", 18);

        $display("  [TC18] DONE\n");

        // ==========================================================
        // FINAL REPORT
        // ==========================================================
        $display("+======================================================+");
        $display("|        Cardinal NIC Verification Complete            |");
        $display("+======================================================+");
        $display("|  PASS: %-5d  FAIL: %-5d                          |",
                 pass_count, fail_count);
        if (fail_count === 0)
            $display("|           *** ALL TESTS PASSED ***                  |");
        else
            $display("|       *** %0d FAILURE(S) -- CHECK LOG ***             |",
                     fail_count);
        $display("+======================================================+");

        $finish;
    end

    // ----------------------------------------------------------
    // Watchdog -- kills any hung simulation
    // ----------------------------------------------------------
    initial begin
        #200_000; // 200 ?s absolute limit
        $display("FATAL: Watchdog timeout -- simulation hung!");
        $finish;
    end

endmodule
