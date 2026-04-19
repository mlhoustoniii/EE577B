/////////////////////////////////////////////////////////////////////
// Filename     : tb_ex_mem_stage.v
// Description  : Functional + structural testbench for ex_mem_stage.v
//                Adheres to Cardinal ISA Manual (EE577B)
//
// Coverage strategy:
//   This stage has real functional content (ALU computations), so
//   tests verify actual output values — not just wiring.
//
// Test groups:
//   A. Bitwise ops (VAND, VOR, VXOR, VNOT, VMOV) — ww-independent
//   B. VADD — all four ww encodings, carry isolation between lanes
//   C. VSUB — all four ww encodings
//   D. VMULEU / VMULOU — even/odd lane selection, double-width output
//   E. VSLL / VSRL / VSRA — shift amount from rB LSBs per lane
//   F. VRTTH — half-rotation (swap) for all ww
//   G. VDIV / VMOD — divide-by-zero saturation behavior
//   H. VSQEU / VSQOU — even/odd squaring, double-width output
//   I. VSQRT — all ww, perfect squares + floor values
//   J. is_rtype=0 gate — alu_result must be 0 for load/store/nop
//   K. Memory interface — memEn, memWrEn, addr_out, d_out pass-through
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module tb_ex_mem_stage;

// ---- DUT ports ----
reg  [0:63]  rA_data;
reg  [0:63]  rB_data;
reg  [0:5]   alu_func;
reg  [0:1]   ww;
reg          is_rtype;
reg          mem_en;
reg          mem_wr;
reg  [0:15]  imm_addr;

wire [0:63]  alu_result;
wire         memEn;
wire         memWrEn;
wire [0:31]  addr_out;
wire [0:63]  d_out;

ex_mem_stage DUT (
    .rA_data   (rA_data),
    .rB_data   (rB_data),
    .alu_func  (alu_func),
    .ww        (ww),
    .is_rtype  (is_rtype),
    .mem_en    (mem_en),
    .mem_wr    (mem_wr),
    .imm_addr  (imm_addr),
    .alu_result(alu_result),
    .memEn     (memEn),
    .memWrEn   (memWrEn),
    .addr_out  (addr_out),
    .d_out     (d_out)
);

// ---- Bookkeeping ----
integer pass_count, fail_count;

// Boolean check — for flags and control signals
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

// 64-bit value check — prints got/expected on failure
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

// 32-bit value check — for addr_out
task check32;
    input [255:0] label;
    input [0:31]  got;
    input [0:31]  expected;
    begin
        if (got === expected) begin
            $display("  PASS: %s  (0x%08h)", label, got);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: %s", label);
            $display("        got:      0x%08h", got);
            $display("        expected: 0x%08h", expected);
            fail_count = fail_count + 1;
        end
    end
endtask

// func code constants
localparam F_VAND   = 6'b000001;
localparam F_VOR    = 6'b000010;
localparam F_VXOR   = 6'b000011;
localparam F_VNOT   = 6'b000100;
localparam F_VMOV   = 6'b000101;
localparam F_VADD   = 6'b000110;
localparam F_VSUB   = 6'b000111;
localparam F_VMULEU = 6'b001000;
localparam F_VMULOU = 6'b001001;
localparam F_VSLL   = 6'b001010;
localparam F_VSRL   = 6'b001011;
localparam F_VSRA   = 6'b001100;
localparam F_VRTTH  = 6'b001101;
localparam F_VDIV   = 6'b001110;
localparam F_VMOD   = 6'b001111;
localparam F_VSQEU  = 6'b010000;
localparam F_VSQOU  = 6'b010001;
localparam F_VSQRT  = 6'b010010;

// helper: set inputs and settle
task drive;
    input [0:63] a, b;
    input [0:5]  f;
    input [0:1]  w;
    begin
        rA_data  = a;
        rB_data  = b;
        alu_func = f;
        ww       = w;
        is_rtype = 1;
        mem_en   = 0;
        mem_wr   = 0;
        imm_addr = 0;
        #1;
    end
endtask

// ============================================================
initial begin
    pass_count = 0;
    fail_count = 0;
    rA_data = 0; rB_data = 0; alu_func = 0;
    ww = 0; is_rtype = 0; mem_en = 0; mem_wr = 0; imm_addr = 0;
    #5;

    // ==========================================================
    // GROUP A: Bitwise — ww does not affect result (ISA note)
    // ==========================================================
    $display("\n=== GROUP A: Bitwise operations ===");

    $display("\n[A01] VAND");
    drive(64'hFF00_AA55_0F0F_1234, 64'h0FF0_55AA_F0F0_5678, F_VAND, 2'b00); #1;
    check64("VAND result", alu_result, (64'hFF00_AA55_0F0F_1234 & 64'h0FF0_55AA_F0F0_5678));

    $display("\n[A02] VOR");
    drive(64'hFF00_AA55_0F0F_1234, 64'h0FF0_55AA_F0F0_5678, F_VOR, 2'b01); #1;
    check64("VOR result", alu_result, (64'hFF00_AA55_0F0F_1234 | 64'h0FF0_55AA_F0F0_5678));

    $display("\n[A03] VXOR");
    drive(64'hFF00_AA55_0F0F_1234, 64'h0FF0_55AA_F0F0_5678, F_VXOR, 2'b10); #1;
    check64("VXOR result", alu_result, (64'hFF00_AA55_0F0F_1234 ^ 64'h0FF0_55AA_F0F0_5678));

    $display("\n[A04] VNOT");
    drive(64'hFF00_AA55_0F0F_1234, 64'd0, F_VNOT, 2'b11); #1;
    check64("VNOT result", alu_result, ~64'hFF00_AA55_0F0F_1234);

    $display("\n[A05] VMOV");
    drive(64'hDEAD_BEEF_CAFE_BABE, 64'd0, F_VMOV, 2'b00); #1;
    check64("VMOV result", alu_result, 64'hDEAD_BEEF_CAFE_BABE);

    $display("\n[A06] Bitwise: ww field has no effect (VAND ww=11 same as ww=00)");
    drive(64'hA5A5_A5A5_A5A5_A5A5, 64'h5A5A_5A5A_5A5A_5A5A, F_VAND, 2'b11); #1;
    check64("VAND ww=11", alu_result, 64'h0000_0000_0000_0000);

    // ==========================================================
    // GROUP B: VADD — all ww, carry isolation between lanes
    // ==========================================================
    $display("\n=== GROUP B: VADD ===");

    $display("\n[B01] VADD ww=00 (8-bit) — carry must not cross byte boundary");
    // Each byte: 0xFF + 0x01 = 0x00 (carry dropped per ISA)
    drive(64'hFF_FF_FF_FF_FF_FF_FF_FF, 64'h01_01_01_01_01_01_01_01, F_VADD, 2'b00); #1;
    check64("VADD 8b carry dropped", alu_result, 64'h0000_0000_0000_0000);

    $display("\n[B02] VADD ww=00 — normal values");
    drive(64'h01_02_03_04_05_06_07_08, 64'h08_07_06_05_04_03_02_01, F_VADD, 2'b00); #1;
    check64("VADD 8b sums", alu_result, 64'h09_09_09_09_09_09_09_09);

    $display("\n[B03] VADD ww=01 (16-bit) — carry must not cross halfword boundary");
    drive(64'hFFFF_FFFF_FFFF_FFFF, 64'h0001_0001_0001_0001, F_VADD, 2'b01); #1;
    check64("VADD 16b carry dropped", alu_result, 64'h0000_0000_0000_0000);

    $display("\n[B04] VADD ww=10 (32-bit)");
    drive(64'hFFFF_FFFF_0000_0001, 64'h0000_0001_FFFF_FFFF, F_VADD, 2'b10); #1;
    check("VADD 32b lane0", alu_result[0:31]  == 32'h0000_0000); // overflow
    check("VADD 32b lane1", alu_result[32:63] == 32'h0000_0000); // overflow

    $display("\n[B05] VADD ww=11 (64-bit)");
    drive(64'h0000_0000_0000_0005, 64'h0000_0000_0000_0003, F_VADD, 2'b11); #1;
    check64("VADD 64b", alu_result, 64'h0000_0000_0000_0008);

    // ==========================================================
    // GROUP C: VSUB
    // ==========================================================
    $display("\n=== GROUP C: VSUB ===");

    $display("\n[C01] VSUB ww=00 (8-bit)");
    drive(64'h0A_0B_0C_0D_0E_0F_10_11, 64'h01_02_03_04_05_06_07_08, F_VSUB, 2'b00); #1;
    check64("VSUB 8b", alu_result, 64'h09_09_09_09_09_09_09_09);

    $display("\n[C02] VSUB ww=00 — underflow wraps per lane");
    // 0x00 - 0x01 = 0xFF per byte lane
    drive(64'h00_00_00_00_00_00_00_00, 64'h01_01_01_01_01_01_01_01, F_VSUB, 2'b00); #1;
    check64("VSUB 8b underflow", alu_result, 64'hFF_FF_FF_FF_FF_FF_FF_FF);

    $display("\n[C03] VSUB ww=01 (16-bit)");
    drive(64'h0010_0020_0030_0040, 64'h0001_0002_0003_0004, F_VSUB, 2'b01); #1;
    check64("VSUB 16b", alu_result, 64'h000F_001E_002D_003C);

    $display("\n[C04] VSUB ww=11 (64-bit)");
    drive(64'h0000_0000_0000_0010, 64'h0000_0000_0000_0003, F_VSUB, 2'b11); #1;
    check64("VSUB 64b", alu_result, 64'h0000_0000_0000_000D);

    // ==========================================================
    // GROUP D: VMULEU / VMULOU
    // Key: even/odd lane selection, result width doubles
    // ==========================================================
    $display("\n=== GROUP D: VMULEU / VMULOU ===");

    $display("\n[D01] VMULEU ww=00 — even bytes (0,2,4,6) produce halfwords");
    // rA bytes: [0]=0x02 [1]=0xFF [2]=0x03 [3]=0xFF ...
    // rB bytes: [0]=0x04 [1]=0xFF [2]=0x05 [3]=0xFF ...
    // Even byte products: 2*4=8, 3*5=15, 6*7=42, 8*9=72
    drive(64'h02_FF_03_FF_06_FF_08_FF,
          64'h04_FF_05_FF_07_FF_09_FF, F_VMULEU, 2'b00); #1;
    check("VMULEU 8b lane0 (bytes 0)", alu_result[0:15]  == 16'd8);
    check("VMULEU 8b lane1 (bytes 2)", alu_result[16:31] == 16'd15);
    check("VMULEU 8b lane2 (bytes 4)", alu_result[32:47] == 16'd42);
    check("VMULEU 8b lane3 (bytes 6)", alu_result[48:63] == 16'd72);

    $display("\n[D02] VMULOU ww=00 — odd bytes (1,3,5,7) produce halfwords");
    // Odd byte products: 0xFF*0xFF=0xFE01, etc
    drive(64'h00_FF_00_FF_00_FF_00_FF,
          64'h00_FF_00_FF_00_FF_00_FF, F_VMULOU, 2'b00); #1;
    check("VMULOU 8b lane0 (bytes 1)", alu_result[0:15]  == 16'hFE01);
    check("VMULOU 8b lane1 (bytes 3)", alu_result[16:31] == 16'hFE01);
    check("VMULOU 8b lane2 (bytes 5)", alu_result[32:47] == 16'hFE01);
    check("VMULOU 8b lane3 (bytes 7)", alu_result[48:63] == 16'hFE01);

    $display("\n[D03] VMULEU ww=01 — even halfwords (0,2) produce words");
    drive(64'h0003_FFFF_0004_FFFF, 64'h0005_FFFF_0006_FFFF, F_VMULEU, 2'b01); #1;
    check("VMULEU 16b lane0", alu_result[0:31]  == 32'd15);
    check("VMULEU 16b lane1", alu_result[32:63] == 32'd24);

    $display("\n[D04] VMULEU ww=10 — even word (word 0) produces doubleword");
    drive(64'h0000_0006_0000_0000, 64'h0000_0007_0000_0000, F_VMULEU, 2'b10); #1;
    check64("VMULEU 32b", alu_result, 64'd42);

    $display("\n[D05] VMULOU ww=10 — odd word (word 1) produces doubleword");
    drive(64'h0000_0000_0000_0008, 64'h0000_0000_0000_0009, F_VMULOU, 2'b10); #1;
    check64("VMULOU 32b", alu_result, 64'd72);

    // ==========================================================
    // GROUP E: VSLL / VSRL / VSRA
    // Shift amount taken from rB LSBs of each lane
    // ==========================================================
    $display("\n=== GROUP E: VSLL / VSRL / VSRA ===");

    $display("\n[E01] VSLL ww=00 — 3-bit shift amount from rB[5:7] per byte lane");
    // Shift each byte of 0x01 left by 1 → 0x02
    // rB lane shift fields: lower 3 bits of each byte = 1
    drive(64'h01_01_01_01_01_01_01_01, 64'h01_01_01_01_01_01_01_01, F_VSLL, 2'b00); #1;
    check64("VSLL 8b shift-by-1", alu_result, 64'h02_02_02_02_02_02_02_02);

    $display("\n[E02] VSLL ww=00 — shift by 7 (max useful for 8-bit)");
    drive(64'h01_01_01_01_01_01_01_01, 64'h07_07_07_07_07_07_07_07, F_VSLL, 2'b00); #1;
    check64("VSLL 8b shift-by-7", alu_result, 64'h80_80_80_80_80_80_80_80);

    $display("\n[E03] VSLL ww=11 — 6-bit shift amount from rB[58:63]");
    drive(64'h0000_0000_0000_0001, 64'h0000_0000_0000_0003, F_VSLL, 2'b11); #1;
    check64("VSLL 64b shift-by-3", alu_result, 64'h0000_0000_0000_0008);

    $display("\n[E04] VSRL ww=00 — logical right, zeros fill MSB");
    drive(64'h80_80_80_80_80_80_80_80, 64'h01_01_01_01_01_01_01_01, F_VSRL, 2'b00); #1;
    check64("VSRL 8b shift-by-1", alu_result, 64'h40_40_40_40_40_40_40_40);

    $display("\n[E05] VSRA ww=00 — arithmetic right, sign bit fills MSB");
    // 0x80 = -128 signed; shift right 1 → 0xC0 = -64
    drive(64'h80_80_80_80_80_80_80_80, 64'h01_01_01_01_01_01_01_01, F_VSRA, 2'b00); #1;
    check64("VSRA 8b shift-by-1 (signed)", alu_result, 64'hC0_C0_C0_C0_C0_C0_C0_C0);

    $display("\n[E06] VSRA ww=11 — 64-bit arithmetic shift");
    // MSB=1 (negative), shift right 4: sign extends
    drive(64'h8000_0000_0000_0000, 64'h0000_0000_0000_0004, F_VSRA, 2'b11); #1;
    check64("VSRA 64b shift-by-4", alu_result, 64'hF800_0000_0000_0000);

    $display("\n[E07] VSRL vs VSRA distinction — same input, different fill");
    drive(64'h8000_0000_0000_0000, 64'h0000_0000_0000_0004, F_VSRL, 2'b11); #1;
    check64("VSRL 64b shift-by-4 (zero fill)", alu_result, 64'h0800_0000_0000_0000);

    // ==========================================================
    // GROUP F: VRTTH — rotate by half (swap)
    // ==========================================================
    $display("\n=== GROUP F: VRTTH ===");

    $display("\n[F01] VRTTH ww=00 — swap nibbles within each byte");
    drive(64'hAB_CD_EF_12_34_56_78_90, 64'd0, F_VRTTH, 2'b00); #1;
    check64("VRTTH 8b", alu_result, 64'hBA_DC_FE_21_43_65_87_09);

    $display("\n[F02] VRTTH ww=01 — swap bytes within each halfword");
    drive(64'hAABB_CCDD_EEFF_1122, 64'd0, F_VRTTH, 2'b01); #1;
    check64("VRTTH 16b", alu_result, 64'hBBAA_DDCC_FFEE_2211);

    $display("\n[F03] VRTTH ww=10 — swap halfwords within each word");
    drive(64'hAAAA_BBBB_CCCC_DDDD, 64'd0, F_VRTTH, 2'b10); #1;
    check64("VRTTH 32b", alu_result, 64'hBBBB_AAAA_DDDD_CCCC);

    $display("\n[F04] VRTTH ww=11 — swap words within doubleword");
    drive(64'hAAAA_AAAA_BBBB_BBBB, 64'd0, F_VRTTH, 2'b11); #1;
    check64("VRTTH 64b", alu_result, 64'hBBBB_BBBB_AAAA_AAAA);

    // ==========================================================
    // GROUP G: VDIV / VMOD — divide-by-zero saturation
    // ==========================================================
    $display("\n=== GROUP G: VDIV / VMOD ===");

    $display("\n[G01] VDIV ww=00 — normal division");
    drive(64'h10_0C_08_06_04_03_02_01, 64'h02_03_04_02_02_03_02_01, F_VDIV, 2'b00); #1;
    check("VDIV 8b lane0", alu_result[0:7]   == 8'd8);
    check("VDIV 8b lane1", alu_result[8:15]  == 8'd4);
    check("VDIV 8b lane2", alu_result[16:23] == 8'd2);

    $display("\n[G02] VDIV ww=00 — divide by zero saturates to 0xFF per lane");
    drive(64'hAA_BB_CC_DD_EE_FF_11_22, 64'h00_00_00_00_00_00_00_00, F_VDIV, 2'b00); #1;
    check64("VDIV 8b by-zero", alu_result, 64'hFF_FF_FF_FF_FF_FF_FF_FF);

    $display("\n[G03] VDIV ww=11 — 64-bit divide by zero → all 1s");
    drive(64'hDEAD_BEEF_CAFE_BABE, 64'h0000_0000_0000_0000, F_VDIV, 2'b11); #1;
    check64("VDIV 64b by-zero", alu_result, 64'hFFFF_FFFF_FFFF_FFFF);

    $display("\n[G04] VMOD ww=00 — normal modulo");
    drive(64'h0A_0B_0C_00_00_00_00_00, 64'h03_04_05_00_00_00_00_00, F_VMOD, 2'b00); #1;
    check("VMOD 8b lane0 (10%3=1)", alu_result[0:7]  == 8'd1);
    check("VMOD 8b lane1 (11%4=3)", alu_result[8:15] == 8'd3);
    check("VMOD 8b lane2 (12%5=2)", alu_result[16:23] == 8'd2);

    $display("\n[G05] VMOD ww=00 — mod by zero returns dividend");
    drive(64'hAA_BB_CC_DD_EE_FF_11_22, 64'h00_00_00_00_00_00_00_00, F_VMOD, 2'b00); #1;
    check64("VMOD 8b by-zero", alu_result, 64'hAA_BB_CC_DD_EE_FF_11_22);

    // ==========================================================
    // GROUP H: VSQEU / VSQOU — squaring even/odd subfields
    // ==========================================================
    $display("\n=== GROUP H: VSQEU / VSQOU ===");

    $display("\n[H01] VSQEU ww=00 — square even bytes (0,2,4,6)");
    // Even bytes: 2,3,4,5 → squares: 4,9,16,25 in halfword lanes
    drive(64'h02_FF_03_FF_04_FF_05_FF, 64'd0, F_VSQEU, 2'b00); #1;
    check("VSQEU 8b lane0 (2^2=4)",   alu_result[0:15]  == 16'd4);
    check("VSQEU 8b lane1 (3^2=9)",   alu_result[16:31] == 16'd9);
    check("VSQEU 8b lane2 (4^2=16)",  alu_result[32:47] == 16'd16);
    check("VSQEU 8b lane3 (5^2=25)",  alu_result[48:63] == 16'd25);

    $display("\n[H02] VSQOU ww=00 — square odd bytes (1,3,5,7)");
    drive(64'hFF_02_FF_03_FF_04_FF_05, 64'd0, F_VSQOU, 2'b00); #1;
    check("VSQOU 8b lane0 (2^2=4)",   alu_result[0:15]  == 16'd4);
    check("VSQOU 8b lane1 (3^2=9)",   alu_result[16:31] == 16'd9);
    check("VSQOU 8b lane2 (4^2=16)",  alu_result[32:47] == 16'd16);
    check("VSQOU 8b lane3 (5^2=25)",  alu_result[48:63] == 16'd25);

    $display("\n[H03] VSQEU ww=10 — square even word (word 0) → doubleword");
    drive(64'h0000_0006_0000_0000, 64'd0, F_VSQEU, 2'b10); #1;
    check64("VSQEU 32b (6^2=36)", alu_result, 64'd36);

    // ==========================================================
    // GROUP I: VSQRT — floor of integer square root
    // ==========================================================
    $display("\n=== GROUP I: VSQRT ===");

    $display("\n[I01] VSQRT ww=00 — 8-bit, perfect squares");
    // sqrt(0)=0, sqrt(1)=1, sqrt(4)=2, sqrt(9)=3,
    // sqrt(16)=4, sqrt(25)=5, sqrt(64)=8, sqrt(255)=15
    drive(64'h00_01_04_09_10_19_40_FF, 64'd0, F_VSQRT, 2'b00); #1;
    check("VSQRT 8b [0]=0",   alu_result[0:7]   == 8'd0);
    check("VSQRT 8b [1]=1",   alu_result[8:15]  == 8'd1);
    check("VSQRT 8b [2]=2",   alu_result[16:23] == 8'd2);
    check("VSQRT 8b [3]=3",   alu_result[24:31] == 8'd3);
    check("VSQRT 8b [4]=4",   alu_result[32:39] == 8'd4);
    check("VSQRT 8b [5]=5",   alu_result[40:47] == 8'd5);
    check("VSQRT 8b [6]=8",   alu_result[48:55] == 8'd8);
    check("VSQRT 8b [7]=15",  alu_result[56:63] == 8'd15);

    $display("\n[I02] VSQRT ww=01 — 16-bit floor");
    // sqrt(100)=10, sqrt(200)=14, sqrt(65535)=255
    drive(64'h0064_00C8_0000_FFFF, 64'd0, F_VSQRT, 2'b01); #1;
    check("VSQRT 16b [0]=10",  alu_result[0:15]  == 16'd10);
    check("VSQRT 16b [1]=14",  alu_result[16:31] == 16'd14);
    check("VSQRT 16b [3]=255", alu_result[48:63] == 16'd255);

    $display("\n[I03] VSQRT ww=11 — 64-bit");
    drive(64'd100, 64'd0, F_VSQRT, 2'b11); #1;
    check64("VSQRT 64b sqrt(100)=10", alu_result, 64'd10);

    // ==========================================================
    // GROUP J: is_rtype=0 gate — alu_result must be 0
    // ==========================================================
    $display("\n=== GROUP J: is_rtype=0 gate ===");

    $display("\n[J01] Load: is_rtype=0, alu_result=0");
    rA_data = 64'hDEAD_BEEF_CAFE_BABE;
    rB_data = 64'hDEAD_BEEF_CAFE_BABE;
    alu_func = F_VADD; ww = 2'b11;
    is_rtype = 0; mem_en = 1; mem_wr = 0; imm_addr = 16'h0010; #1;
    check64("load: alu_result=0", alu_result, 64'd0);

    $display("\n[J02] Store: is_rtype=0, alu_result=0");
    is_rtype = 0; mem_en = 1; mem_wr = 1; #1;
    check64("store: alu_result=0", alu_result, 64'd0);

    $display("\n[J03] NOP: is_rtype=0, alu_result=0");
    is_rtype = 0; mem_en = 0; mem_wr = 0; alu_func = 6'd0; #1;
    check64("nop: alu_result=0", alu_result, 64'd0);

    // ==========================================================
    // GROUP K: Memory interface pass-through
    // ==========================================================
    $display("\n=== GROUP K: Memory interface ===");

    $display("\n[K01] Load: memEn=1, memWrEn=0, addr={16'b0,imm}");
    rA_data = 64'hABCD_1234_5678_EF01;
    is_rtype = 0; mem_en = 1; mem_wr = 0; imm_addr = 16'h00A0; #1;
    check("load: memEn=1",    memEn    == 1);
    check("load: memWrEn=0",  memWrEn  == 0);
    check32("load: addr_out", addr_out, 32'h0000_00A0);
    check64("load: d_out=rA", d_out, 64'hABCD_1234_5678_EF01);

    $display("\n[K02] Store: memEn=1, memWrEn=1, d_out=rA_data");
    rA_data = 64'hDEAD_BEEF_CAFE_BABE;
    is_rtype = 0; mem_en = 1; mem_wr = 1; imm_addr = 16'h00FF; #1;
    check("store: memEn=1",   memEn    == 1);
    check("store: memWrEn=1", memWrEn  == 1);
    check32("store: addr_out", addr_out, 32'h0000_00FF);
    check64("store: d_out=rA", d_out, 64'hDEAD_BEEF_CAFE_BABE);

    $display("\n[K03] No mem op: memEn=0, memWrEn=0");
    is_rtype = 1; mem_en = 0; mem_wr = 0; alu_func = F_VMOV;
    rA_data = 64'h1234; #1;
    check("no-mem: memEn=0",   memEn   == 0);
    check("no-mem: memWrEn=0", memWrEn == 0);

    $display("\n[K04] addr_out zero-extends imm to 32 bits");
    imm_addr = 16'hFFFF; mem_en = 1; is_rtype = 0; #1;
    check32("addr_out=0x0000FFFF", addr_out, 32'h0000_FFFF);

    // ==========================================================
    $display("\n==============================");
    $display("Results: %0d passed, %0d failed", pass_count, fail_count);
    $display("==============================\n");
    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("FAILURES DETECTED");
    $finish;
end

endmodule