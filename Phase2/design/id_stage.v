/////////////////////////////////////////////////////////////////////
// Project      : EE577B Spring2026 Cardinal Processor - Phase 2
// Filename     : id_stage.v
// Description  : Instruction Decode Stage (purely combinational)
//
// Boundary contract:
//   - Regfile lives in top level. Top drives fwd_rA_data / fwd_rB_data
//     from the forwarding mux output (regfile read + EX/MEM + WB bypass).
//   - All branch condition evaluation is done here using fwd_rA_data.
//   - branch_taken output is NOT gated by stall here; top level does:
//       branch_taken_gated = id_branch_taken && !stall
//   - No registers inside this module — purely combinational.
//
// Instruction field layout (Cardinal ISA, big-endian bit numbering):
//   [0:5]   opcode
//   [6:10]  rD
//   [11:15] rA
//   [16:20] rB
//   [21:23] reserved
//   [24:25] ww   (word-width)
//   [26:31] func (R-type ALU function)
//   [16:31] imm  (load / store / branch immediate — overlaps rB/ww/func)
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module id_stage (
    // ---- From IF/ID pipeline register ----
    input  [0:31]  inst,

    // ---- IF/ID valid bit ----
    input          valid,

    // ---- Forwarded register data (top-level forwarding mux output) ----
    // Port A: forwarded value of rf_rdA_addr (rA normally, rD for store/branch)
    input  [0:63]  fwd_rA_data,
    // Port B: forwarded value of rB
    input  [0:63]  fwd_rB_data,

    // ---- Decoded instruction fields ----
    output [0:5]   opcode,
    output [0:4]   rD,
    output [0:4]   rA,
    output [0:4]   rB,
    output [0:1]   ww,
    output [0:5]   func,
    output [0:15]  imm,

    // ---- Instruction type flags ----
    output         is_rtype,
    output         is_load,
    output         is_store,
    output         is_beq,
    output         is_bneq,
    output         is_nop,
    output         is_branch,

    // ---- Control signals for ID/EX register ----
    output         reg_write,
    output         mem_en,
    output         mem_wr,

    // ---- Regfile read-port addresses (drive top-level regfile ports) ----
    output [0:4]   rf_rdA_addr,
    output [0:4]   rf_rdB_addr,

    // ---- Branch resolution ----
    // Condition met — top level gates with !stall before using
    output         branch_taken,
    // {16'b0, imm}
    output [0:31]  branch_target
);

// ============================================================
//  Opcode constants
// ============================================================
localparam OP_RTYPE  = 6'b101010;
localparam OP_VLD    = 6'b100000;
localparam OP_VSD    = 6'b100001;
localparam OP_VBEQ   = 6'b100010;
localparam OP_VBNEQ  = 6'b100011;
localparam OP_VNOP   = 6'b111100;

// ============================================================
//  Field extraction
// ============================================================
assign opcode = inst[0:5];
assign rD     = inst[6:10];
assign rA     = inst[11:15];
assign rB     = inst[16:20];
assign ww     = inst[24:25];   // bits 24:25 — NOT 21:22
assign func   = inst[26:31];
assign imm    = inst[16:31];

// ============================================================
//  Instruction type decode
// ============================================================
assign is_rtype  = (opcode == OP_RTYPE) && valid;
assign is_load   = (opcode == OP_VLD)   && valid;
assign is_store  = (opcode == OP_VSD)   && valid;
assign is_beq    = (opcode == OP_VBEQ)  && valid;
assign is_bneq   = (opcode == OP_VBNEQ) && valid;
assign is_nop    = (opcode == OP_VNOP)  || !valid;
assign is_branch = is_beq || is_bneq;

// ============================================================
//  Control signals
// ============================================================
assign reg_write = is_rtype || is_load;
assign mem_en    = is_load  || is_store;
assign mem_wr    = is_store;

// ============================================================
//  Regfile read address selection
// ============================================================
// Port A: store/branch read rD (it is their source); all others read rA
assign rf_rdA_addr = (is_store || is_branch) ? rD : rA;
assign rf_rdB_addr = rB;

// ============================================================
//  Branch evaluation
// ============================================================
assign branch_taken  = (is_beq  && (fwd_rA_data == 64'd0)) ||
                       (is_bneq && (fwd_rA_data != 64'd0));
assign branch_target = {16'b0, imm};

endmodule