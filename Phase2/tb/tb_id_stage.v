/////////////////////////////////////////////////////////////////////
// Filename     : tb_id_stage.v
// Description  : Full-coverage testbench for id_stage.v
//                Adheres strictly to Cardinal ISA manual (EE577B)
//
// ISA encoding notes:
//   - VLD/VSD:   field[11:15]=00000 (no base reg). VSD source is rD.
//   - Single-op: VNOT,VMOV,VRTTH,VSQEU,VSQOU,VSQRT have rB=00000.
//   - Branch:    field[11:15]=00000. Condition reg is rD.
//   - ww:        inst[24:25] only; inst[21:23] always 000 (reserved).
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module tb_id_stage;

reg  [0:31]  inst;
reg          valid;
reg  [0:63]  fwd_rA_data;
reg  [0:63]  fwd_rB_data;

wire [0:5]   opcode;
wire [0:4]   rD, rA, rB;
wire [0:1]   ww;
wire [0:5]   func;
wire [0:15]  imm;
wire         is_rtype, is_load, is_store, is_beq, is_bneq, is_nop, is_branch;
wire         reg_write, mem_en, mem_wr;
wire [0:4]   rf_rdA_addr, rf_rdB_addr;
wire         branch_taken;
wire [0:31]  branch_target;

id_stage DUT (
    .inst(inst), .valid(valid),
    .fwd_rA_data(fwd_rA_data), .fwd_rB_data(fwd_rB_data),
    .opcode(opcode), .rD(rD), .rA(rA), .rB(rB),
    .ww(ww), .func(func), .imm(imm),
    .is_rtype(is_rtype), .is_load(is_load), .is_store(is_store),
    .is_beq(is_beq), .is_bneq(is_bneq), .is_nop(is_nop), .is_branch(is_branch),
    .reg_write(reg_write), .mem_en(mem_en), .mem_wr(mem_wr),
    .rf_rdA_addr(rf_rdA_addr), .rf_rdB_addr(rf_rdB_addr),
    .branch_taken(branch_taken), .branch_target(branch_target)
);

integer pass_count, fail_count;

task check;
    input [127:0] label;
    input expr;
    begin
        if (expr) begin $display("  PASS: %s", label); pass_count=pass_count+1; end
        else      begin $display("  FAIL: %s", label); fail_count=fail_count+1; end
    end
endtask

// Two-operand R-type
function [0:31] make_r2;
    input [4:0] rd, ra, rb; input [1:0] ww; input [5:0] fn;
    make_r2 = {6'b101010, rd, ra, rb, 3'b000, ww, fn};
endfunction

// Single-operand R-type (rB field=00000 per ISA)
function [0:31] make_r1;
    input [4:0] rd, ra; input [1:0] ww; input [5:0] fn;
    make_r1 = {6'b101010, rd, ra, 5'b00000, 3'b000, ww, fn};
endfunction

// VLD: field[11:15]=00000 per ISA
function [0:31] make_vld;
    input [4:0] rd; input [15:0] addr;
    make_vld = {6'b100000, rd, 5'b00000, addr};
endfunction

// VSD: field[11:15]=00000 per ISA, rD is data source
function [0:31] make_vsd;
    input [4:0] rd; input [15:0] addr;
    make_vsd = {6'b100001, rd, 5'b00000, addr};
endfunction

// VBEZ: field[11:15]=00000 per ISA
function [0:31] make_vbez;
    input [4:0] rd; input [15:0] tgt;
    make_vbez = {6'b100010, rd, 5'b00000, tgt};
endfunction

// VBNEZ: field[11:15]=00000 per ISA
function [0:31] make_vbnez;
    input [4:0] rd; input [15:0] tgt;
    make_vbnez = {6'b100011, rd, 5'b00000, tgt};
endfunction

localparam [0:31] NOP_INST = 32'hF000_0000;

task check_is_nop_state;
    begin
        check("is_nop=1",    is_nop==1'b1);
        check("is_rtype=0",  is_rtype==1'b0);
        check("is_load=0",   is_load==1'b0);
        check("is_store=0",  is_store==1'b0);
        check("is_branch=0", is_branch==1'b0);
        check("reg_write=0", reg_write==1'b0);
        check("mem_en=0",    mem_en==1'b0);
        check("mem_wr=0",    mem_wr==1'b0);
    end
endtask

task check_rtype_2op;
    input [4:0] eD, eA, eB; input [1:0] eWW; input [5:0] eFN;
    begin
        check("is_rtype=1",  is_rtype==1'b1);
        check("is_load=0",   is_load==1'b0);
        check("is_store=0",  is_store==1'b0);
        check("is_branch=0", is_branch==1'b0);
        check("is_nop=0",    is_nop==1'b0);
        check("reg_write=1", reg_write==1'b1);
        check("mem_en=0",    mem_en==1'b0);
        check("mem_wr=0",    mem_wr==1'b0);
        check("rD correct",  rD==eD);
        check("rA correct",  rA==eA);
        check("rB correct",  rB==eB);
        check("ww correct",  ww==eWW);
        check("func correct",func==eFN);
        check("rdA_addr=rA", rf_rdA_addr==eA);
        check("rdB_addr=rB", rf_rdB_addr==eB);
    end
endtask

task check_rtype_1op;
    input [4:0] eD, eA; input [1:0] eWW; input [5:0] eFN;
    begin
        check("is_rtype=1",       is_rtype==1'b1);
        check("is_load=0",        is_load==1'b0);
        check("is_store=0",       is_store==1'b0);
        check("is_branch=0",      is_branch==1'b0);
        check("is_nop=0",         is_nop==1'b0);
        check("reg_write=1",      reg_write==1'b1);
        check("mem_en=0",         mem_en==1'b0);
        check("mem_wr=0",         mem_wr==1'b0);
        check("rD correct",       rD==eD);
        check("rA correct",       rA==eA);
        check("rB=00000 per ISA", rB==5'd0);
        check("ww correct",       ww==eWW);
        check("func correct",     func==eFN);
        check("rdA_addr=rA",      rf_rdA_addr==eA);
        check("rdB_addr=0",       rf_rdB_addr==5'd0);
    end
endtask

initial begin
    pass_count=0; fail_count=0;
    fwd_rA_data=64'd0; fwd_rB_data=64'd0;
    valid=1'b1; inst=32'd0; #5;

    $display("\n[ISA #1] VAND rD=1 rA=2 rB=3 ww=00");
    inst=make_r2(5'd1,5'd2,5'd3,2'b00,6'b000001); valid=1'b1; #1;
    check_rtype_2op(5'd1,5'd2,5'd3,2'b00,6'b000001);

    $display("\n[ISA #2] VOR rD=4 rA=5 rB=6 ww=01");
    inst=make_r2(5'd4,5'd5,5'd6,2'b01,6'b000010); valid=1'b1; #1;
    check_rtype_2op(5'd4,5'd5,5'd6,2'b01,6'b000010);

    $display("\n[ISA #3] VXOR rD=7 rA=8 rB=9 ww=10");
    inst=make_r2(5'd7,5'd8,5'd9,2'b10,6'b000011); valid=1'b1; #1;
    check_rtype_2op(5'd7,5'd8,5'd9,2'b10,6'b000011);

    $display("\n[ISA #4] VNOT rD=10 rA=11 ww=11 (single-op)");
    inst=make_r1(5'd10,5'd11,2'b11,6'b000100); valid=1'b1; #1;
    check_rtype_1op(5'd10,5'd11,2'b11,6'b000100);

    $display("\n[ISA #5] VMOV rD=12 rA=13 ww=00 (single-op)");
    inst=make_r1(5'd12,5'd13,2'b00,6'b000101); valid=1'b1; #1;
    check_rtype_1op(5'd12,5'd13,2'b00,6'b000101);

    $display("\n[ISA #6] VADD rD=5 rA=3 rB=7 ww=10");
    inst=make_r2(5'd5,5'd3,5'd7,2'b10,6'b000110); valid=1'b1; #1;
    check_rtype_2op(5'd5,5'd3,5'd7,2'b10,6'b000110);

    $display("\n[ISA #7] VSUB rD=2 rA=4 rB=6 ww=01");
    inst=make_r2(5'd2,5'd4,5'd6,2'b01,6'b000111); valid=1'b1; #1;
    check_rtype_2op(5'd2,5'd4,5'd6,2'b01,6'b000111);

    $display("\n[ISA #8] VMULEU rD=1 rA=2 rB=3 ww=00");
    inst=make_r2(5'd1,5'd2,5'd3,2'b00,6'b001000); valid=1'b1; #1;
    check_rtype_2op(5'd1,5'd2,5'd3,2'b00,6'b001000);

    $display("\n[ISA #9] VMULOU rD=4 rA=5 rB=6 ww=01");
    inst=make_r2(5'd4,5'd5,5'd6,2'b01,6'b001001); valid=1'b1; #1;
    check_rtype_2op(5'd4,5'd5,5'd6,2'b01,6'b001001);

    $display("\n[ISA #10] VSLL rD=7 rA=8 rB=9 ww=00");
    inst=make_r2(5'd7,5'd8,5'd9,2'b00,6'b001010); valid=1'b1; #1;
    check_rtype_2op(5'd7,5'd8,5'd9,2'b00,6'b001010);

    $display("\n[ISA #11] VSRL rD=10 rA=11 rB=12 ww=01");
    inst=make_r2(5'd10,5'd11,5'd12,2'b01,6'b001011); valid=1'b1; #1;
    check_rtype_2op(5'd10,5'd11,5'd12,2'b01,6'b001011);

    $display("\n[ISA #12] VSRA rD=13 rA=14 rB=15 ww=10");
    inst=make_r2(5'd13,5'd14,5'd15,2'b10,6'b001100); valid=1'b1; #1;
    check_rtype_2op(5'd13,5'd14,5'd15,2'b10,6'b001100);

    $display("\n[ISA #13] VRTTH rD=16 rA=17 ww=11 (single-op)");
    inst=make_r1(5'd16,5'd17,2'b11,6'b001101); valid=1'b1; #1;
    check_rtype_1op(5'd16,5'd17,2'b11,6'b001101);

    $display("\n[ISA #14] VDIV rD=18 rA=19 rB=20 ww=11");
    inst=make_r2(5'd18,5'd19,5'd20,2'b11,6'b001110); valid=1'b1; #1;
    check_rtype_2op(5'd18,5'd19,5'd20,2'b11,6'b001110);

    $display("\n[ISA #15] VMOD rD=21 rA=22 rB=23 ww=00");
    inst=make_r2(5'd21,5'd22,5'd23,2'b00,6'b001111); valid=1'b1; #1;
    check_rtype_2op(5'd21,5'd22,5'd23,2'b00,6'b001111);

    $display("\n[ISA #16] VSQEU rD=24 rA=25 ww=00 (single-op)");
    inst=make_r1(5'd24,5'd25,2'b00,6'b010000); valid=1'b1; #1;
    check_rtype_1op(5'd24,5'd25,2'b00,6'b010000);

    $display("\n[ISA #17] VSQOU rD=26 rA=27 ww=01 (single-op)");
    inst=make_r1(5'd26,5'd27,2'b01,6'b010001); valid=1'b1; #1;
    check_rtype_1op(5'd26,5'd27,2'b01,6'b010001);

    $display("\n[ISA #18] VSQRT rD=28 rA=29 ww=10 (single-op)");
    inst=make_r1(5'd28,5'd29,2'b10,6'b010010); valid=1'b1; #1;
    check_rtype_1op(5'd28,5'd29,2'b10,6'b010010);

    // VLD — no base register per ISA p.22
    $display("\n[ISA #19] VLD rD=8 imm=0xABCD");
    inst=make_vld(5'd8,16'hABCD); valid=1'b1; #1;
    check("is_load=1",        is_load==1'b1);
    check("is_rtype=0",       is_rtype==1'b0);
    check("is_store=0",       is_store==1'b0);
    check("is_branch=0",      is_branch==1'b0);
    check("is_nop=0",         is_nop==1'b0);
    check("reg_write=1",      reg_write==1'b1);
    check("mem_en=1",         mem_en==1'b1);
    check("mem_wr=0",         mem_wr==1'b0);
    check("rD=8",             rD==5'd8);
    check("rA=0 ISA fixed",   rA==5'd0);
    check("imm=0xABCD",       imm==16'hABCD);

    // VSD — rD is data source, rf_rdA_addr must be rD per ISA p.23
    $display("\n[ISA #20] VSD rD=6 imm=0x0010");
    inst=make_vsd(5'd6,16'h0010); valid=1'b1; #1;
    check("is_store=1",       is_store==1'b1);
    check("is_load=0",        is_load==1'b0);
    check("is_rtype=0",       is_rtype==1'b0);
    check("is_branch=0",      is_branch==1'b0);
    check("is_nop=0",         is_nop==1'b0);
    check("reg_write=0",      reg_write==1'b0);
    check("mem_en=1",         mem_en==1'b1);
    check("mem_wr=1",         mem_wr==1'b1);
    check("rD=6",             rD==5'd6);
    check("rA=0 ISA fixed",   rA==5'd0);
    check("imm=0x0010",       imm==16'h0010);
    check("rdA_addr=rD=6",    rf_rdA_addr==5'd6);

    // VBEZ taken
    $display("\n[ISA #21a] VBEZ taken (fwd_rA_data==0)");
    inst=make_vbez(5'd9,16'h0040); fwd_rA_data=64'd0; valid=1'b1; #1;
    check("is_beq=1",         is_beq==1'b1);
    check("is_branch=1",      is_branch==1'b1);
    check("is_rtype=0",       is_rtype==1'b0);
    check("reg_write=0",      reg_write==1'b0);
    check("mem_en=0",         mem_en==1'b0);
    check("rD=9",             rD==5'd9);
    check("rA=0 ISA fixed",   rA==5'd0);
    check("imm=0x0040",       imm==16'h0040);
    check("rdA_addr=rD=9",    rf_rdA_addr==5'd9);
    check("branch_taken=1",   branch_taken==1'b1);
    check("branch_target",    branch_target==32'h0000_0040);

    $display("\n[ISA #21b] VBEZ not taken (fwd_rA_data!=0)");
    fwd_rA_data=64'hDEAD_BEEF_0000_0001; #1;
    check("branch_taken=0",   branch_taken==1'b0);

    // VBNEZ taken
    $display("\n[ISA #22a] VBNEZ taken (fwd_rA_data!=0)");
    inst=make_vbnez(5'd11,16'h00F0); fwd_rA_data=64'h1; valid=1'b1; #1;
    check("is_bneq=1",        is_bneq==1'b1);
    check("is_branch=1",      is_branch==1'b1);
    check("is_rtype=0",       is_rtype==1'b0);
    check("reg_write=0",      reg_write==1'b0);
    check("mem_en=0",         mem_en==1'b0);
    check("rD=11",            rD==5'd11);
    check("rA=0 ISA fixed",   rA==5'd0);
    check("imm=0x00F0",       imm==16'h00F0);
    check("rdA_addr=rD=11",   rf_rdA_addr==5'd11);
    check("branch_taken=1",   branch_taken==1'b1);
    check("branch_target",    branch_target==32'h0000_00F0);

    $display("\n[ISA #22b] VBNEZ not taken (fwd_rA_data==0)");
    fwd_rA_data=64'd0; #1;
    check("branch_taken=0",   branch_taken==1'b0);

    // VNOP
    $display("\n[ISA #23] VNOP");
    inst=NOP_INST; fwd_rA_data=64'd0; valid=1'b1; #1;
    check_is_nop_state;
    check("branch_taken=0",   branch_taken==1'b0);

    // Structural A: valid=0
    $display("\n[Struct A] valid=0 forces is_nop");
    inst=make_r2(5'd1,5'd2,5'd3,2'b00,6'b000110); valid=1'b0; #1;
    check("is_nop=1",    is_nop==1'b1);
    check("is_rtype=0",  is_rtype==1'b0);
    check("reg_write=0", reg_write==1'b0);
    check("mem_en=0",    mem_en==1'b0);

    // Structural B: ww bit isolation
    $display("\n[Struct B] ww at inst[24:25], inst[21:23]=111 must not bleed");
    inst={6'b101010,5'd1,5'd2,5'd3,3'b111,2'b01,6'b000110}; valid=1'b1; #1;
    check("ww=01 no bleed",  ww==2'b01);
    check("func intact",     func==6'b000110);

    // Structural C: ww sweep
    $display("\n[Struct C] ww encoding sweep");
    inst=make_r2(5'd1,5'd2,5'd3,2'b00,6'b000110); valid=1'b1; #1; check("ww=00",ww==2'b00);
    inst=make_r2(5'd1,5'd2,5'd3,2'b01,6'b000110);               #1; check("ww=01",ww==2'b01);
    inst=make_r2(5'd1,5'd2,5'd3,2'b10,6'b000110);               #1; check("ww=10",ww==2'b10);
    inst=make_r2(5'd1,5'd2,5'd3,2'b11,6'b000110);               #1; check("ww=11",ww==2'b11);

    $display("\n==============================");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    $display("==============================\n");
    if (fail_count==0) $display("ALL TESTS PASSED");
    else               $display("FAILURES DETECTED");
    $finish;
end

endmodule