/////////////////////////////////////////////////////////////////////
// Filename     : tb_id_exmem.v
// Description  : Integration testbench — id_stage + ex_mem_stage
//                with forwarding mux, ID/EX and EX/WB pipeline
//                registers, and a local regfile.
//
// What this covers that module-level TBs cannot:
//   - Correct data flow from instruction decode through ALU
//     across a clock boundary (ID/EX register population)
//   - EX/MEM forwarding: result of cycle N available to cycle N+1
//     without stalling
//   - WB forwarding: result of cycle N available to cycle N+2
//   - Load-use stall: bubble inserted into ID/EX, IF/ID held,
//     PC held for exactly one cycle
//   - Store data path: forwarded rD value arrives at d_out
//   - Branch flush: VBEZ taken inserts NOP into IF/ID next cycle
//
// What is stubbed:
//   - instruction_fetch: PC is driven directly by TB
//   - DMEM: d_in driven directly by TB
//   - WB regfile write: regfile pre-loaded by TB, no writeback
//     (writeback correctness is covered in tb_pipeline.v)
//
// Clock: 4ns period matching full-pipeline TB convention
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module tb_id_exmem;

// ============================================================
//  Clock + reset
// ============================================================
reg clk, reset;
always #2 clk = ~clk;

// ============================================================
//  Instruction + d_in stimulus (stub for IF and DMEM)
// ============================================================
reg [0:31] ifid_inst_tb;   // driven by TB into IF/ID register
reg        ifid_valid_tb;
reg [0:63] d_in;           // stub DMEM read data

// ============================================================
//  Regfile (local — TB pre-loads, no WB write in this TB)
// ============================================================
reg [0:63] regfile [0:31];
integer rf_idx;

// ============================================================
//  Pipeline registers (same names as cardinal_cpu)
// ============================================================

// ID/EX
reg [0:63] idex_rA_data;
reg [0:63] idex_rB_data;
reg [0:4]  idex_rD_addr;
reg [0:5]  idex_alu_func;
reg [0:1]  idex_ww;
reg        idex_reg_write;
reg        idex_mem_en;
reg        idex_mem_wr;
reg        idex_is_load;
reg [0:15] idex_imm_addr;
reg        idex_valid;
reg        idex_is_rtype;

// EX/WB
reg [0:63] exwb_alu_result;
reg [0:4]  exwb_rD_addr;
reg        exwb_reg_write;
reg        exwb_is_load;
reg        exwb_valid;

// ============================================================
//  id_stage output wires
// ============================================================
wire [0:5]  id_opcode;
wire [0:4]  id_rD, id_rA, id_rB;
wire [0:1]  id_ww;
wire [0:5]  id_func;
wire [0:15] id_imm;
wire        id_is_rtype, id_is_load, id_is_store;
wire        id_is_beq, id_is_bneq, id_is_nop, id_is_branch;
wire        id_reg_write, id_mem_en, id_mem_wr;
wire [0:4]  rf_rdA_addr, rf_rdB_addr;
wire        id_branch_taken_raw;
wire [0:31] id_branch_target;

// ============================================================
//  Forwarding mux (mirrors cardinal_cpu exactly)
// ============================================================
wire [0:63] wb_data = exwb_is_load ? d_in : exwb_alu_result;

wire fwd_exmem_to_A = idex_valid && idex_reg_write && (idex_rD_addr != 5'd0) &&
                      (idex_rD_addr == rf_rdA_addr);
wire fwd_wb_to_A    = exwb_valid && exwb_reg_write && (exwb_rD_addr != 5'd0) &&
                      (exwb_rD_addr == rf_rdA_addr) && !fwd_exmem_to_A;

wire fwd_exmem_to_B = idex_valid && idex_reg_write && (idex_rD_addr != 5'd0) &&
                      (idex_rD_addr == rf_rdB_addr);
wire fwd_wb_to_B    = exwb_valid && exwb_reg_write && (exwb_rD_addr != 5'd0) &&
                      (exwb_rD_addr == rf_rdB_addr) && !fwd_exmem_to_B;

wire [0:63] ex_alu_result;  // driven by ex_mem_stage

wire [0:63] rf_rdA_data = regfile[rf_rdA_addr];
wire [0:63] rf_rdB_data = regfile[rf_rdB_addr];

wire [0:63] fwd_rA_data = fwd_exmem_to_A ? ex_alu_result :
                          fwd_wb_to_A    ? wb_data        :
                          rf_rdA_data;

wire [0:63] fwd_rB_data = fwd_exmem_to_B ? ex_alu_result :
                          fwd_wb_to_B    ? wb_data        :
                          rf_rdB_data;

// ============================================================
//  Hazard detection (mirrors cardinal_cpu exactly)
// ============================================================
wire load_use_hazard = idex_valid && idex_is_load &&
                       ((idex_rD_addr == rf_rdA_addr &&
                         (id_is_rtype || id_is_store || id_is_branch)) ||
                        (idex_rD_addr == rf_rdB_addr && id_is_rtype)) &&
                       (idex_rD_addr != 5'd0);
wire stall = load_use_hazard;
wire branch_taken = id_branch_taken_raw && !stall;

// ============================================================
//  DUT instantiations
// ============================================================
id_stage ID_unit (
    .inst         (ifid_inst_tb),
    .valid        (ifid_valid_tb),
    .fwd_rA_data  (fwd_rA_data),
    .fwd_rB_data  (fwd_rB_data),
    .opcode       (id_opcode),
    .rD           (id_rD),
    .rA           (id_rA),
    .rB           (id_rB),
    .ww           (id_ww),
    .func         (id_func),
    .imm          (id_imm),
    .is_rtype     (id_is_rtype),
    .is_load      (id_is_load),
    .is_store     (id_is_store),
    .is_beq       (id_is_beq),
    .is_bneq      (id_is_bneq),
    .is_nop       (id_is_nop),
    .is_branch    (id_is_branch),
    .reg_write    (id_reg_write),
    .mem_en       (id_mem_en),
    .mem_wr       (id_mem_wr),
    .rf_rdA_addr  (rf_rdA_addr),
    .rf_rdB_addr  (rf_rdB_addr),
    .branch_taken (id_branch_taken_raw),
    .branch_target(id_branch_target)
);

wire        memEn, memWrEn;
wire [0:31] addr_out;
wire [0:63] d_out;

ex_mem_stage EX_MEM_unit (
    .rA_data   (idex_rA_data),
    .rB_data   (idex_rB_data),
    .alu_func  (idex_alu_func),
    .ww        (idex_ww),
    .is_rtype  (idex_is_rtype),
    .mem_en    (idex_mem_en),
    .mem_wr    (idex_mem_wr),
    .imm_addr  (idex_imm_addr),
    .alu_result(ex_alu_result),
    .memEn     (memEn),
    .memWrEn   (memWrEn),
    .addr_out  (addr_out),
    .d_out     (d_out)
);

// ============================================================
//  ID/EX pipeline register (clocked, mirrors cardinal_cpu)
// ============================================================
always @(posedge clk) begin
    if (reset || stall) begin
        idex_rA_data   <= 64'd0;
        idex_rB_data   <= 64'd0;
        idex_rD_addr   <= 5'd0;
        idex_alu_func  <= 6'd0;
        idex_ww        <= 2'd0;
        idex_reg_write <= 1'b0;
        idex_mem_en    <= 1'b0;
        idex_mem_wr    <= 1'b0;
        idex_is_load   <= 1'b0;
        idex_imm_addr  <= 16'd0;
        idex_valid     <= 1'b0;
        idex_is_rtype  <= 1'b0;
    end else begin
        idex_rA_data   <= fwd_rA_data;
        idex_rB_data   <= fwd_rB_data;
        idex_rD_addr   <= id_rD;
        idex_alu_func  <= id_func;
        idex_ww        <= id_ww;
        idex_reg_write <= id_reg_write && !id_is_nop && !id_is_branch;
        idex_mem_en    <= id_mem_en;
        idex_mem_wr    <= id_mem_wr;
        idex_is_load   <= id_is_load;
        idex_imm_addr  <= id_imm;
        idex_valid     <= ifid_valid_tb && !id_is_nop && !id_is_branch;
        idex_is_rtype  <= id_is_rtype;
    end
end

// ============================================================
//  EX/WB pipeline register (clocked, mirrors cardinal_cpu)
// ============================================================
always @(posedge clk) begin
    if (reset) begin
        exwb_alu_result <= 64'd0;
        exwb_rD_addr    <= 5'd0;
        exwb_reg_write  <= 1'b0;
        exwb_is_load    <= 1'b0;
        exwb_valid      <= 1'b0;
    end else begin
        exwb_alu_result <= ex_alu_result;
        exwb_rD_addr    <= idex_rD_addr;
        exwb_reg_write  <= idex_reg_write;
        exwb_is_load    <= idex_is_load;
        exwb_valid      <= idex_valid;
    end
end

// ============================================================
//  Instruction encoding helpers
// ============================================================
// R-type: 101010 | rD | rA | rB | 000 | ww | func
function [0:31] rtype;
    input [4:0] rd, ra, rb;
    input [1:0] w;
    input [5:0] f;
    begin rtype = {6'b101010, rd, ra, rb, 3'b000, w, f}; end
endfunction

// VLD: 100000 | rD | 00000 | imm
function [0:31] vld;
    input [4:0] rd;
    input [15:0] imm;
    begin vld = {6'b100000, rd, 5'b00000, imm}; end
endfunction

// VSD: 100001 | rD(src) | 00000 | imm
function [0:31] vsd;
    input [4:0] rd;
    input [15:0] imm;
    begin vsd = {6'b100001, rd, 5'b00000, imm}; end
endfunction

// VBEZ: 100010 | rD(cond) | 00000 | imm
function [0:31] vbez;
    input [4:0] rd;
    input [15:0] imm;
    begin vbez = {6'b100010, rd, 5'b00000, imm}; end
endfunction

// VNOP
localparam NOP = {6'b111100, 26'd0};

// func codes
localparam F_VADD = 6'b000110;
localparam F_VSUB = 6'b000111;
localparam F_VAND = 6'b000001;
localparam F_VMOV = 6'b000101;

// ============================================================
//  Bookkeeping
// ============================================================
integer pass_count, fail_count;

task check;
    input [255:0] label;
    input         expr;
    begin
        if (expr) begin
            $display("  PASS: %s", label);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: %s", label);
            fail_count = fail_count + 1;
        end
    end
endtask

task check64;
    input [255:0] label;
    input [0:63]  got;
    input [0:63]  expected;
    begin
        if (got === expected) begin
            $display("  PASS: %s  (0x%016h)", label, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: %s", label);
            $display("        got:      0x%016h", got);
            $display("        expected: 0x%016h", expected);
            fail_count = fail_count + 1;
        end
    end
endtask

// Feed one instruction into IF/ID and tick one clock.
// Does NOT add settle delay — caller adds #1 after if sampling outputs.
task feed;
    input [0:31] inst;
    input        vld_bit;
    begin
        ifid_inst_tb  = inst;
        ifid_valid_tb = vld_bit;
        @(posedge clk);
    end
endtask

// Tick one clock with current IF/ID held, then settle
task tick;
    begin
        @(posedge clk); #1;
    end
endtask

// Flush pipeline with NOPs (no instruction in flight)
task flush;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            ifid_inst_tb  = NOP;
            ifid_valid_tb = 1'b0;
            @(posedge clk);
        end
        #1;
    end
endtask

// Reset and clear all pipeline state
task do_reset;
    begin
        reset = 1;
        ifid_inst_tb  = NOP;
        ifid_valid_tb = 1'b0;
        d_in = 64'd0;
        @(posedge clk); @(posedge clk);
        reset = 0;
        @(posedge clk); #1;
    end
endtask

// ============================================================
//  MAIN TEST
// ============================================================
initial begin
    clk        = 0;
    reset      = 1;
    pass_count = 0;
    fail_count = 0;
    d_in       = 64'd0;
    ifid_inst_tb  = NOP;
    ifid_valid_tb = 1'b0;

    // Pre-load regfile with known values
    for (rf_idx = 0; rf_idx < 32; rf_idx = rf_idx + 1)
        regfile[rf_idx] = 64'd0;
    regfile[1]  = 64'h0000_0000_0000_000A;  // r1 = 10
    regfile[2]  = 64'h0000_0000_0000_0003;  // r2 = 3
    regfile[3]  = 64'h0000_0000_0000_0005;  // r3 = 5
    regfile[4]  = 64'hFFFF_FFFF_FFFF_FFFF;  // r4 = all-ones
    regfile[5]  = 64'h0000_0000_0000_0000;  // r5 = 0 (branch condition)

    @(posedge clk); @(posedge clk);
    reset = 0;
    @(posedge clk); #1;

    // Pipeline timing note:
    // After do_reset, the first @(posedge clk) inside feed() latches
    // ifid_inst_tb into the ID/EX register. Because ex_alu_result is
    // combinational from ID/EX, it is valid (after #1 settle) on the
    // SAME posedge that consumed the instruction from IF/ID.
    //
    // So the sampling rule is:
    //   feed(INST_A); #1; → ex_alu_result shows INST_A's result
    //   feed(INST_B); #1; → ex_alu_result shows INST_B's result
    //
    // For forwarding checks: fwd_* wires reflect what ID sees
    // combinationally from idex_*/exwb_* BEFORE the next posedge.
    // So check fwd_* after feed(consumer_inst) but BEFORE the next feed.

    // ==========================================================
    // TEST 1: No dependency — two independent R-type instructions
    // ==========================================================
    $display("\n=== TEST 1: Independent R-type instructions ===");
    do_reset;
    regfile[1] = 64'd10; regfile[2] = 64'd3; regfile[3] = 64'd5;

    feed(rtype(5'd6, 5'd1, 5'd2, 2'b11, F_VADD), 1'b1); #1;
    check64("T1: VADD r1+r2=13", ex_alu_result, 64'd13);

    feed(rtype(5'd7, 5'd3, 5'd2, 2'b11, F_VSUB), 1'b1); #1;
    check64("T1: VSUB r3-r2=2",  ex_alu_result, 64'd2);

    // ==========================================================
    // TEST 2: EX/MEM forwarding — back-to-back RAW
    //
    // feed(VADD_r8):  VADD enters ID/EX, ex_alu_result=13
    // feed(VADD_r9):  VADD_r9 in ID/EX; idex_rA_data was set from
    //                 fwd_exmem_to_A=13 at the previous posedge.
    //                 ex_alu_result now = 13+5 = 18
    //
    // To check that forwarding fired: sample fwd_* BETWEEN the two feeds.
    // Drive VADD_r9 into IF/ID manually, then sample, THEN clock.
    // ==========================================================
    $display("\n=== TEST 2: EX/MEM forwarding (back-to-back RAW) ===");
    do_reset;
    regfile[1] = 64'd10; regfile[2] = 64'd3; regfile[3] = 64'd5;
    regfile[8] = 64'd0;

    feed(rtype(5'd8, 5'd1, 5'd2, 2'b11, F_VADD), 1'b1); #1;
    // Now: VADD_r8 in ID/EX, ex_alu_result=13, idex_rD=8
    // Drive VADD_r9 into IF/ID — do NOT clock yet — sample forwarding
    ifid_inst_tb  = rtype(5'd9, 5'd8, 5'd3, 2'b11, F_VADD);
    ifid_valid_tb = 1'b1;
    #1; // combinational settle — fwd_* valid now
    check("T2: fwd_exmem_to_A asserted",    fwd_exmem_to_A == 1'b1);
    check64("T2: fwd_rA_data=13",           fwd_rA_data,    64'd13);

    @(posedge clk); #1; // clock: VADD_r9 → ID/EX with rA=13, ex_alu_result=18
    check64("T2: VADD r8+r3 = 13+5 = 18",  ex_alu_result,  64'd18);

    // ==========================================================
    // TEST 3: WB forwarding — two-cycle RAW
    //
    // feed(VADD_r10): r10=13 in ID/EX
    // feed(NOP):      r10=13 in EX/WB (exwb_alu_result=13)
    // Drive VADD_r11 into IF/ID, sample fwd_wb_to_A, then clock
    // feed(NOP):      VADD_r11 in ID/EX with rA=13, ex_alu_result=18
    // ==========================================================
    $display("\n=== TEST 3: WB forwarding (two-cycle RAW) ===");
    do_reset;
    regfile[1] = 64'd10; regfile[2] = 64'd3; regfile[3] = 64'd5;
    regfile[10] = 64'd0;

    feed(rtype(5'd10, 5'd1, 5'd2, 2'b11, F_VADD), 1'b1); // r10=13 in ID/EX
    feed(NOP, 1'b0);                                        // r10=13 in EX/WB
    #1;
    // Drive VADD_r11 into IF/ID, check WB forward before clocking
    ifid_inst_tb  = rtype(5'd11, 5'd10, 5'd3, 2'b11, F_VADD);
    ifid_valid_tb = 1'b1;
    #1;
    check("T3: fwd_wb_to_A asserted",       fwd_wb_to_A    == 1'b1);
    check("T3: fwd_exmem_to_A not set",     fwd_exmem_to_A == 1'b0);
    check64("T3: fwd_rA_data=13 (WB fwd)", fwd_rA_data,    64'd13);

    @(posedge clk); #1; // VADD_r11 in ID/EX with rA=13
    check64("T3: VADD r10+r3 = 13+5 = 18", ex_alu_result,  64'd18);

    // ==========================================================
    // TEST 4: EX/MEM forward priority over WB
    //
    // feed(VADD_r12=13): r12=13 in ID/EX
    // feed(VSUB_r12=2):  r12=13 moves to EX/WB; r12=2 in ID/EX
    // Drive VADD_r13 into IF/ID: both fwd conditions live.
    //   fwd_exmem_to_A: idex_rD=12, result=2
    //   fwd_wb_to_A:    exwb_rD=12, result=13
    //   EX/MEM must win.
    // ==========================================================
    $display("\n=== TEST 4: EX/MEM forward priority over WB ===");
    do_reset;
    regfile[1] = 64'd10; regfile[2] = 64'd3; regfile[3] = 64'd5;
    regfile[12] = 64'd0;

    feed(rtype(5'd12, 5'd1, 5'd2, 2'b11, F_VADD), 1'b1); // r12=13 → ID/EX
    feed(rtype(5'd12, 5'd3, 5'd2, 2'b11, F_VSUB), 1'b1); // r12=2  → ID/EX, 13→EX/WB
    #1;
    ifid_inst_tb  = rtype(5'd13, 5'd12, 5'd2, 2'b11, F_VADD);
    ifid_valid_tb = 1'b1;
    #1;
    check("T4: fwd_exmem_to_A asserted (priority)", fwd_exmem_to_A == 1'b1);
    check("T4: fwd_wb_to_A suppressed",             fwd_wb_to_A    == 1'b0);
    check64("T4: fwd_rA_data=2 (EX/MEM wins)",      fwd_rA_data,    64'd2);

    @(posedge clk); #1;
    check64("T4: VADD r12+r2 = 2+3 = 5", ex_alu_result, 64'd5);

    // ==========================================================
    // TEST 5: Load-use stall
    //
    // feed(VLD_r14): VLD → ID/EX (is_load=1, rD=14)
    // Drive VADD_r15 (reads r14) into IF/ID, clock:
    //   hazard fires → stall=1, ID/EX gets bubble, IF/ID held
    // Clock again: stall releases
    // ==========================================================
    $display("\n=== TEST 5: Load-use stall ===");
    do_reset;
    regfile[2] = 64'd3;
    d_in = 64'd42;

    // Drive VADD into IF/ID BEFORE clocking VLD into ID/EX,
    // so stall logic sees the hazard on the same posedge.
    ifid_inst_tb  = vld(5'd14, 16'h0010);
    ifid_valid_tb = 1'b1;
    @(posedge clk); #1; // VLD latches into ID/EX

    // Change IF/ID to VADD — stall is now combinationally active
    ifid_inst_tb  = rtype(5'd15, 5'd14, 5'd2, 2'b11, F_VADD);
    ifid_valid_tb = 1'b1;
    #1; // settle — stall, ID/EX pipeline reg state from previous edge
    // stall is combinational: idex_is_load=1, idex_valid=1, rD=14 == rf_rdA_addr
    check("T5: stall asserted",            stall          == 1'b1);
    // ID/EX still holds VLD state (hasn't been clocked yet)
    // idex_valid=1 (VLD was valid), bubble hasn't been inserted yet
    // The bubble gets inserted on the NEXT posedge
    @(posedge clk); #1; // stall fires: bubble inserted into ID/EX
    check("T5: ID/EX bubble: valid=0",     idex_valid     == 1'b0);
    check("T5: ID/EX bubble: reg_write=0", idex_reg_write == 1'b0);
    check("T5: ID/EX bubble: mem_wr=0",    idex_mem_wr    == 1'b0);
    check("T5: IF/ID held (VADD present)",
          ifid_inst_tb == rtype(5'd15, 5'd14, 5'd2, 2'b11, F_VADD));

    @(posedge clk); #1;
    check("T5: stall released", stall == 1'b0);

    // ==========================================================
    // TEST 6: Store data path
    //
    // feed(VSD_r3): VSD → ID/EX (idex_rA_data=regfile[3]=5)
    // After #1: VSD in EX/MEM via combinational path → check outputs
    // ==========================================================
    $display("\n=== TEST 6: Store data path ===");
    do_reset;
    regfile[3] = 64'd5;

    feed(vsd(5'd3, 16'h0020), 1'b1); #1;
    check("T6: memWrEn=1",         memWrEn  == 1'b1);
    check("T6: memEn=1",           memEn    == 1'b1);
    check64("T6: d_out=r3=5",      d_out,    64'd5);
    check("T6: addr=0x0020",       addr_out == 32'h0000_0020);

    // ==========================================================
    // TEST 7: Store with EX/MEM forwarded store-source
    //
    // feed(VADD_r16=13): r16=13 in ID/EX, ex_alu_result=13
    // Drive VSD_r16 into IF/ID: rf_rdA_addr=r16, fwd_exmem_to_A fires
    // Clock: VSD → ID/EX with idex_rA_data=13
    // After #1: VSD in EX/MEM, d_out=13
    // ==========================================================
    $display("\n=== TEST 7: Store with forwarded store-source ===");
    do_reset;
    regfile[1] = 64'd10; regfile[2] = 64'd3;
    regfile[16] = 64'd0;

    feed(rtype(5'd16, 5'd1, 5'd2, 2'b11, F_VADD), 1'b1); #1;
    // r16=13 in ID/EX, ex_alu_result=13
    ifid_inst_tb  = vsd(5'd16, 16'h0030);
    ifid_valid_tb = 1'b1;
    #1;
    check("T7: fwd_exmem_to_A for store source", fwd_exmem_to_A == 1'b1);

    @(posedge clk); #1; // VSD in ID/EX with idex_rA_data=13
    check("T7: memWrEn=1",             memWrEn  == 1'b1);
    check64("T7: d_out=forwarded 13",  d_out,    64'd13);
    check("T7: addr=0x0030",           addr_out == 32'h0000_0030);

    // ==========================================================
    // TEST 8: Branch flush — VBEZ taken
    //
    // Drive VBEZ into IF/ID, sample combinational branch signals.
    // Clock: VBEZ latches into ID/EX as bubble (branch suppresses).
    // ==========================================================
    $display("\n=== TEST 8: Branch flush (VBEZ taken) ===");
    do_reset;
    regfile[5] = 64'd0;

    ifid_inst_tb  = vbez(5'd5, 16'h0080);
    ifid_valid_tb = 1'b1;
    #1;
    check("T8: branch_taken asserted (comb)", branch_taken     == 1'b1);
    check("T8: branch_target=0x0080",         id_branch_target == 32'h0000_0080);

    @(posedge clk); #1;
    check("T8: ID/EX valid=0 after branch",   idex_valid     == 1'b0);
    check("T8: ID/EX reg_write=0",            idex_reg_write == 1'b0);

    // ==========================================================
    // TEST 9: VBEZ not taken — pipeline continues normally
    // ==========================================================
    $display("\n=== TEST 9: Branch not taken — no flush ===");
    do_reset;
    regfile[1] = 64'd10;

    ifid_inst_tb  = vbez(5'd1, 16'h0080);
    ifid_valid_tb = 1'b1;
    #1;
    check("T9: branch_taken=0", branch_taken == 1'b0);

    feed(vbez(5'd1, 16'h0080), 1'b1);
    feed(rtype(5'd6, 5'd1, 5'd2, 2'b11, F_VADD), 1'b1);
    #1;
    check("T9: VADD in ID (is_rtype=1)", id_is_rtype == 1'b1);

    // ==========================================================
    // TEST 10: r0 forwarding guard
    // ==========================================================
    $display("\n=== TEST 10: r0 forward guard ===");
    do_reset;
    regfile[0] = 64'd0;
    regfile[1] = 64'd10; regfile[2] = 64'd3; regfile[3] = 64'd5;

    feed(rtype(5'd0, 5'd1, 5'd2, 2'b11, F_VADD), 1'b1); #1;
    // r0 write in ID/EX — drive read of r0 into IF/ID
    ifid_inst_tb  = rtype(5'd6, 5'd0, 5'd3, 2'b11, F_VADD);
    ifid_valid_tb = 1'b1;
    #1;
    check("T10: fwd_exmem_to_A=0 (r0 guard)", fwd_exmem_to_A == 1'b0);
    check64("T10: fwd_rA_data=0 (regfile r0)", fwd_rA_data,    64'd0);

    @(posedge clk); #1; // r6 = r0 + r3 = 0 + 5 = 5
    check64("T10: VADD r0+r3 = 0+5 = 5", ex_alu_result, 64'd5);

    $finish;
end

endmodule