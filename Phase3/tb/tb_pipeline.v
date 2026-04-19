/////////////////////////////////////////////////////////////////////
// Filename     : tb_pipeline.v
// Description  : Full pipeline integration testbench for cardinal_cpu
//
// Structure mirrors the provided tb_cardinal_cpu.v exactly:
//   - Same imem/dmem instantiation
//   - Same $readmemh loading from fill files
//   - Same wait(inst_in==0) termination
//   - Same 5-cycle pipeline flush before reading DMEM
//   - Same cycle counter
//
// Adds after each flush:
//   - Explicit DMEM value checks with pass/fail reporting
//   - $display of actual vs expected on failure
//
// Test programs:
//   imem_1: Basic ops (VAND/VOR/VXOR/VNOT/VMOV/VADD/VSUB/shifts/
//           VRTTH/VDIV/VMOD/VMULEU/VMULOU/VSQEU/VSQOU/VSQRT) WW=11
//   imem_2: All 18 ALU operations across all valid WW variants
//   imem_3: Branches (taken/not-taken), EX/MEM forwarding chain,
//           load-use hazard, r0 write guard
//
// Expected values pre-computed from ISA specification.
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

`include "./include/dmem.v"
`include "./include/imem.v"


module tb_pipeline;

// ============================================================
//  DUT wiring (identical to provided tb_cardinal_cpu.v)
// ============================================================
reg         clk, reset;
wire [0:31] inst_in;
wire [0:31] pc_out;
wire [0:63] d_in;
wire [0:31] addr_out;
wire        memEn;
wire        memWrEn;
wire [0:63] d_out;

parameter clock_period = 4;

integer cycle_number;
integer i;
integer pass_count, fail_count;

cardinal_cpu dut (clk, reset, inst_in, d_in, pc_out, addr_out, memEn, memWrEn, d_out);

imem Ins_Cache (
    .memAddr (pc_out[22:29]),
    .dataOut (inst_in)
);

dmem DM_Cache (
    .clk     (clk),
    .memEn   (memEn),
    .memWrEn (memWrEn),
    .memAddr (addr_out[24:31]),
    .dataIn  (d_out),
    .dataOut (d_in)
);

always #2 clk = ~clk;

// ============================================================
//  Cycle counter (identical to provided TB)
// ============================================================
always @(posedge clk) begin
    if (reset) cycle_number <= 0;
    else       cycle_number <= cycle_number + 1;
end

// ============================================================
//  Check tasks
// ============================================================
task check_dmem;
    input integer   addr;
    input [0:63]    expected;
    input [255:0]   label;
    begin
        if (DM_Cache.MEM[addr] === expected) begin
            $display("  PASS: dmem[%0d] %s = 0x%016h", addr, label, DM_Cache.MEM[addr]);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: dmem[%0d] %s", addr, label);
            $display("        got:      0x%016h", DM_Cache.MEM[addr]);
            $display("        expected: 0x%016h", expected);
            fail_count = fail_count + 1;
        end
    end
endtask

// ============================================================
//  MAIN
// ============================================================
initial begin
    pass_count = 0;
    fail_count = 0;
    clk        = 0;
    reset      = 1;

    // ==========================================================
    // PROGRAM 1: Basic operations (WW=11 / 64-bit)
    // Loads r1=dmem[0], r2=dmem[1], r3=dmem[2] (shift amts)
    // Computes VAND/VOR/VXOR/VNOT/VMOV/VADD/VSUB/VSLL/VSRL/VSRA/
    //          VRTTH, then VDIV/VMOD(r15=100,r16=7), then
    //          VMULEU/VMULOU/VSQEU/VSQOU(WW=10), VSQRT(WW=11,25)
    // Stores results to dmem[16..33]
    // ==========================================================
    $readmemh("./include/imem_1.fill", Ins_Cache.MEM);
    $readmemh("./include/dmem.fill",   DM_Cache.MEM);
    reset = 1;
    #(4*clock_period); reset = 0;
    wait (inst_in == 32'h00000000);
    $display("\nProgram 1 completed in %0d cycles", cycle_number);
    repeat(5) @(negedge clk);

    $display("\n=== PROGRAM 1: Basic operations (WW=11) ===");
    // r1=0x0102030405060708, r2=0x0807060504030201
    check_dmem(16, 64'h0002020404020200, "VAND  r1&r2");
    check_dmem(17, 64'h0907070505070709, "VOR   r1|r2");
    check_dmem(18, 64'h0905050101050509, "VXOR  r1^r2");
    check_dmem(19, 64'hfefdfcfbfaf9f8f7, "VNOT  ~r1");
    check_dmem(20, 64'h0102030405060708, "VMOV  r1");
    check_dmem(21, 64'h0909090909090909, "VADD  r1+r2");
    check_dmem(22, 64'hf8fafcff01030507, "VSUB  r1-r2");
    check_dmem(23, 64'h0810182028303840, "VSLL  r1<<3");
    check_dmem(24, 64'h0020406080a0c0e1, "VSRL  r1>>3 (logical)");
    check_dmem(25, 64'h0020406080a0c0e1, "VSRA  r1>>>3 (arith, MSB=0)");
    check_dmem(26, 64'h0506070801020304, "VRTTH swap words");
    check_dmem(27, 64'h000000000000000e, "VDIV  100/7=14");
    check_dmem(28, 64'h0000000000000002, "VMOD  100%7=2");
    check_dmem(29, 64'h0008172c46382714, "VMULEU WW=10 word0*word0");
    check_dmem(30, 64'h00142738462c1708, "VMULOU WW=10 word1*word1");
    check_dmem(31, 64'h0001040a14191810, "VSQEU  WW=10 word0^2");
    check_dmem(32, 64'h00193c6aa4917040, "VSQOU  WW=10 word1^2");
    check_dmem(33, 64'h0000000000000005, "VSQRT  sqrt(25)=5");

    #(5*clock_period);

    // ==========================================================
    // PROGRAM 2: All ALU operations across all WW variants
    // r1=dmem[0], r2=dmem[1], r3=dmem[2](shift amts),
    // r4=dmem[8](neg values for VSRA sign-extension test)
    // ==========================================================
    $readmemh("./include/imem_2.fill", Ins_Cache.MEM);
    $readmemh("./include/dmem.fill",   DM_Cache.MEM);
    reset = 1;
    #(4*clock_period); reset = 0;
    wait (inst_in == 32'h00000000);
    $display("\nProgram 2 completed in %0d cycles", cycle_number);
    repeat(5) @(negedge clk);

    $display("\n=== PROGRAM 2: All WW variants ===");

    $display("  -- VADD --");
    check_dmem(16, 64'h0909090909090909, "VADD WW=00 (byte)");
    check_dmem(17, 64'h0909090909090909, "VADD WW=01 (half)");
    check_dmem(18, 64'h0909090909090909, "VADD WW=10 (word)");
    check_dmem(19, 64'h0909090909090909, "VADD WW=11 (dword)");

    $display("  -- VSUB --");
    check_dmem(20, 64'hf9fbfdff01030507, "VSUB WW=00 (byte)");
    check_dmem(21, 64'hf8fbfcff01030507, "VSUB WW=01 (half)");
    check_dmem(22, 64'hf8fafcff01030507, "VSUB WW=10 (word)");
    check_dmem(23, 64'hf8fafcff01030507, "VSUB WW=11 (dword)");

    $display("  -- VAND (ww-independent) --");
    check_dmem(24, 64'h0002020404020200, "VAND WW=00");
    check_dmem(25, 64'h0002020404020200, "VAND WW=01");
    check_dmem(26, 64'h0002020404020200, "VAND WW=10");
    check_dmem(27, 64'h0002020404020200, "VAND WW=11");

    $display("  -- VOR (ww-independent) --");
    check_dmem(28, 64'h0907070505070709, "VOR WW=00");
    check_dmem(29, 64'h0907070505070709, "VOR WW=01");
    check_dmem(30, 64'h0907070505070709, "VOR WW=10");
    check_dmem(31, 64'h0907070505070709, "VOR WW=11");

    $display("  -- VXOR (ww-independent) --");
    check_dmem(32, 64'h0905050101050509, "VXOR WW=00");
    check_dmem(33, 64'h0905050101050509, "VXOR WW=01");
    check_dmem(34, 64'h0905050101050509, "VXOR WW=10");
    check_dmem(35, 64'h0905050101050509, "VXOR WW=11");

    $display("  -- VNOT (ww-independent) --");
    check_dmem(36, 64'hfefdfcfbfaf9f8f7, "VNOT WW=00");
    check_dmem(37, 64'hfefdfcfbfaf9f8f7, "VNOT WW=01");
    check_dmem(38, 64'hfefdfcfbfaf9f8f7, "VNOT WW=10");
    check_dmem(39, 64'hfefdfcfbfaf9f8f7, "VNOT WW=11");

    $display("  -- VMOV (ww-independent) --");
    check_dmem(40, 64'h0102030405060708, "VMOV WW=00");
    check_dmem(41, 64'h0102030405060708, "VMOV WW=01");
    check_dmem(42, 64'h0102030405060708, "VMOV WW=10");
    check_dmem(43, 64'h0102030405060708, "VMOV WW=11");

    $display("  -- VSLL --");
    check_dmem(44, 64'h0810182028303840, "VSLL WW=00 (byte, shift=3)");
    check_dmem(45, 64'h0810182028303840, "VSLL WW=01 (half, shift=3)");
    check_dmem(46, 64'h0810182028303840, "VSLL WW=10 (word, shift=3)");
    check_dmem(47, 64'h0810182028303840, "VSLL WW=11 (dword, shift=3)");

    $display("  -- VSRL --");
    check_dmem(48, 64'h0000000000000001, "VSRL WW=00 (byte, shift=3)");
    check_dmem(49, 64'h0020006000a000e1, "VSRL WW=01 (half, shift=3)");
    check_dmem(50, 64'h0020406000a0c0e1, "VSRL WW=10 (word, shift=3)");
    check_dmem(51, 64'h0020406080a0c0e1, "VSRL WW=11 (dword, shift=3)");

    $display("  -- VSRA (negative input r4=0xFF80FE00FD00FC00) --");
    check_dmem(52, 64'hfff0ff00ff00ff00, "VSRA WW=00 (byte, shift=3, sign-ext)");
    check_dmem(53, 64'hfff0ffc0ffa0ff80, "VSRA WW=01 (half, shift=3, sign-ext)");
    check_dmem(54, 64'hfff01fc0ffa01f80, "VSRA WW=10 (word, shift=3, sign-ext)");
    check_dmem(55, 64'hfff01fc01fa01f80, "VSRA WW=11 (dword, shift=3, sign-ext)");

    $display("  -- VRTTH --");
    check_dmem(56, 64'h1020304050607080, "VRTTH WW=00 (swap nibbles)");
    check_dmem(57, 64'h0201040306050807, "VRTTH WW=01 (swap bytes)");
    check_dmem(58, 64'h0304010207080506, "VRTTH WW=10 (swap halfs)");
    check_dmem(59, 64'h0506070801020304, "VRTTH WW=11 (swap words)");

    $display("  -- VDIV --");
    check_dmem(60, 64'h0000000001020308, "VDIV WW=00 (byte)");
    check_dmem(61, 64'h0000000000010003, "VDIV WW=01 (half)");
    check_dmem(62, 64'h0000000000000001, "VDIV WW=10 (word)");
    check_dmem(63, 64'h0000000000000000, "VDIV WW=11 (dword)");

    $display("  -- VMOD --");
    check_dmem(64, 64'h0102030401000100, "VMOD WW=00 (byte)");
    check_dmem(65, 64'h0102030401030105, "VMOD WW=01 (half)");
    check_dmem(66, 64'h0102030401030507, "VMOD WW=10 (word)");
    check_dmem(67, 64'h0102030405060708, "VMOD WW=11 (dword)");

    $display("  -- VMULEU --");
    check_dmem(68, 64'h000800120014000e, "VMULEU WW=00 (even bytes)");
    check_dmem(69, 64'h0008170e00142712, "VMULEU WW=01 (even halfs)");
    check_dmem(70, 64'h0008172c46382714, "VMULEU WW=10 (even words)");

    $display("  -- VMULOU --");
    check_dmem(71, 64'h000e001400120008, "VMULOU WW=00 (odd bytes)");
    check_dmem(72, 64'h00122714000e1708, "VMULOU WW=01 (odd halfs)");
    check_dmem(73, 64'h00142738462c1708, "VMULOU WW=10 (odd words)");

    $display("  -- VSQEU --");
    check_dmem(74, 64'h0001000900190031, "VSQEU WW=00 (even bytes sq)");
    check_dmem(75, 64'h0001040400193c24, "VSQEU WW=01 (even halfs sq)");
    check_dmem(76, 64'h0001040a14191810, "VSQEU WW=10 (even words sq)");

    $display("  -- VSQOU --");
    check_dmem(77, 64'h0004001000240040, "VSQOU WW=00 (odd bytes sq)");
    check_dmem(78, 64'h0009181000317040, "VSQOU WW=01 (odd halfs sq)");
    check_dmem(79, 64'h00193c6aa4917040, "VSQOU WW=10 (odd words sq)");

    $display("  -- VSQRT --");
    check_dmem(80, 64'h0101010202020202, "VSQRT WW=00 (byte sqrt)");
    check_dmem(81, 64'h0010001b0023002a, "VSQRT WW=01 (half sqrt)");
    check_dmem(82, 64'h00001010000023dc, "VSQRT WW=10 (word sqrt)");
    check_dmem(83, 64'h0000000010101010, "VSQRT WW=11 (dword sqrt)");

    #(5*clock_period);

    // ==========================================================
    // PROGRAM 3: Branches + EX/MEM forwarding + load-use + r0 guard
    // r1=dmem[0]=nonzero, r2=dmem[7]=zero, r3=dmem[1]
    //
    // Branch tests:
    //   VBNEQ r1,0x20: r1!=0 → TAKEN, flushes 1 instr
    //   VBEQ  r2,0x3C: r2==0 → TAKEN, flushes 1 instr
    //   VBEQ  r1,0x68: r1!=0 → NOT TAKEN, next instr executes
    //   VBNEQ r2,0x78: r2==0 → NOT TAKEN, next instr executes
    //
    // EX/MEM forwarding chain:
    //   r25=r1+r3, r26=r25+r1 (forward r25), r27=r26-r3 (forward r26)
    //
    // Load-use: r28=dmem[0], r29=r28+r3 (stall 1 cycle)
    //
    // r0 guard: vaddd r0,r1,r3 → r0 must remain 0
    // ==========================================================
    $readmemh("./include/imem_3.fill", Ins_Cache.MEM);
    $readmemh("./include/dmem.fill",   DM_Cache.MEM);
    reset = 1;
    #(4*clock_period); reset = 0;
    wait (inst_in == 32'h00000000);
    $display("\nProgram 3 completed in %0d cycles", cycle_number);
    repeat(5) @(negedge clk);

    $display("\n=== PROGRAM 3: Branches + forwarding + hazards ===");

    $display("  -- Branch taken tests --");
    // VBNEQ taken: flushed VMOV r10,r1 and VSD r10,16 must NOT execute
    // Instead: vaddd r5,r1,r3 at target 0x20 executes → dmem[16]=r1+r3
    check_dmem(16, 64'h0909090909090909, "VBNEQ taken: dmem[16]=r1+r3 (not flushed vmov)");
    // VBEQ taken: vmovd r6,r3 at target 0x3C → dmem[17]=r3
    check_dmem(17, 64'h0807060504030201, "VBEQ  taken: dmem[17]=r3");

    $display("  -- Branch not taken tests --");
    // VBEQ not taken (r1!=0): vsubd r7,r1,r3 executes → dmem[18]=r1-r3
    check_dmem(18, 64'hf8fafcff01030507, "VBEQ  not taken: dmem[18]=r1-r3");
    // VBNEQ not taken (r2==0): vxord r8,r1,r3 executes → dmem[19]=r1^r3
    check_dmem(19, 64'h0905050101050509, "VBNEQ not taken: dmem[19]=r1^r3");

    $display("  -- EX/MEM forwarding chain --");
    // r25=r1+r3=0x0909..., r26=r25+r1=0x0a0b..., r27=r26-r3=0x0204...
    check_dmem(20, 64'h0909090909090909, "Forward chain: r25=r1+r3");
    check_dmem(21, 64'h0a0b0c0d0e0f1011, "Forward chain: r26=r25+r1 (EX fwd)");
    check_dmem(22, 64'h020406080a0c0e10, "Forward chain: r27=r26-r3 (EX fwd)");

    $display("  -- Load-use hazard --");
    // r28=dmem[0]=r1, r29=r28+r3 (pipeline must stall 1 cycle)
    check_dmem(23, 64'h0909090909090909, "Load-use: r29=dmem[0]+r3");

    $display("  -- r0 write guard --");
    // vaddd r0,r1,r3 must NOT update r0; r0 stays 0; vsdw r0,24 stores 0
    check_dmem(24, 64'h0000000000000000, "r0 guard: dmem[24]=0 (r0 unchanged)");

    // ============================================================
    //  SUMMARY
    // ============================================================
    $display("\n==============================");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    $display("==============================");
    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("FAILURES DETECTED");

    #(5*clock_period);
    $stop;
end

endmodule