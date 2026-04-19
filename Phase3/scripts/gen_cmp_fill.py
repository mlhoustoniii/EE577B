#!/usr/bin/env python3
"""
gen_cmp_fill.py  --  Cardinal Phase 3: generate cmp_test fill files
EE 577B

ARCHITECTURE NOTES (verified against Phase 2 source + test vectors):

1. OPCODES (id_stage.v):
     OP_RTYPE=0x2A  OP_VLD=0x20  OP_VSD=0x21
     OP_VBEQ=0x22   OP_VBNEQ=0x23  OP_VNOP=0x3C (=0xF0000000)

2. R-TYPE (ex_mem_stage.v, ww=11 for 64-bit):
     FUNC_VADD=0x06  FUNC_VSUB=0x07
     encoding: (op<<26)|(rd<<21)|(rs<<16)|(rt<<11)|(ww<<6)|func

3. MEMORY ADDRESSING: addr_out = {16'b0, imm_addr}  -- register NOT added.
     NIC reads/writes use NIC address directly as immediate.
     Variable DMEM indexing impossible; send/recv loops are unrolled.

4. BRANCH TARGETS: PC <= {16'b0, imm}  -- ABSOLUTE byte address, not relative.

5. BRANCH CONDITION: compares rD (inst[6:10]) against zero only.
     VBEQ  -> branch if rD==0
     VBNEQ -> branch if rD!=0

6. PIPELINE: 2 instructions flushed after a taken branch (resolved in ID).
     The 2 instructions following VBNEQ/VBEQ are the payload ops.
     If branch TAKEN  -> they are flushed (correct: don't send/recv yet).
     If branch TAKEN  -> they execute (correct: NIC ready or pkt waiting).

PACKET FORMAT (64-bit):
    [63]=VC [62]=dirX [61]=dirY [60:56]=rsvd
    [55:52]=hopX(unary) [51:48]=hopY(unary)
    [47:40]=src_x [39:32]=src_y [31:0]=payload=(src_id<<8)|dst_id

NIC ADDRESSES:  NIC_IN=0x8000  NIC_IN_STATUS=0x8001
                NIC_OUT=0x8002  NIC_OUT_STATUS=0x8003

DMEM LAYOUT:  MEM[0..14]=outgoing pkts  MEM[15]=0(unused)
              MEM[16..30]=incoming slots(zeroed)  MEM[31..]=0

PROGRAM (122 instr, identical all nodes):
  for i in 0..14:
    poll_out_i: VLD r8,NIC_OUT_STATUS; VBNEQ r8,poll_out_i; VLD r9,i; VSD r9,NIC_OUT
    poll_in_i:  VLD r8,NIC_IN_STATUS;  VBEQ  r8,poll_in_i;  VLD r9,NIC_IN; VSD r9,16+i
  done: VBEQ r0, done   (r0=0 always -> infinite halt)
"""

import os, sys

# Opcodes
OP_RTYPE  = 0x2A
OP_VLD    = 0x20
OP_VSD    = 0x21
OP_VBEQ   = 0x22
OP_VBNEQ  = 0x23
OP_VNOP   = 0x3C

FUNC_VADD = 0x06
FUNC_VSUB = 0x07
WW_64     = 0b11

NIC_IN         = 0xC000
NIC_IN_STATUS  = 0xC001
NIC_OUT        = 0xC002
NIC_OUT_STATUS = 0xC003

IMEM_DEPTH = 256
DMEM_DEPTH = 256

def vld(rd, rs, imm16):
    return (OP_VLD   << 26) | (rd << 21) | (rs << 16) | (imm16 & 0xFFFF)

def vsd(rs, rb, imm16):
    return (OP_VSD   << 26) | (rs << 21) | (rb << 16) | (imm16 & 0xFFFF)

def vadd(rd, rs, rt):
    return (OP_RTYPE << 26) | (rd << 21) | (rs << 16) | (rt << 11) | (WW_64 << 6) | FUNC_VADD

def vsub(rd, rs, rt):
    return (OP_RTYPE << 26) | (rd << 21) | (rs << 16) | (rt << 11) | (WW_64 << 6) | FUNC_VSUB

def vbeq(rd, target_byte_addr):
    return (OP_VBEQ  << 26) | (rd << 21) | (target_byte_addr & 0xFFFF)

def vbneq(rd, target_byte_addr):
    return (OP_VBNEQ << 26) | (rd << 21) | (target_byte_addr & 0xFFFF)

def vnop():
    return (OP_VNOP  << 26)

HOP_UNARY = {0: 0x0, 1: 0x1, 2: 0x3, 3: 0x7}

def make_packet(src_x, src_y, dst_x, dst_y):
    dx = dst_x - src_x
    dy = dst_y - src_y
    dirX = 1 if dx < 0 else 0
    dirY = 1 if dy > 0 else 0
    hopX = HOP_UNARY[abs(dx)]
    hopY = HOP_UNARY[abs(dy)]
    src_id = src_y * 4 + src_x
    dst_id = dst_y * 4 + dst_x
    pkt  = 0  # VC=0
    pkt |= (dirX & 0x1)   << 62
    pkt |= (dirY & 0x1)   << 61
    pkt |= (hopX & 0xF)   << 52
    pkt |= (hopY & 0xF)   << 48
    pkt |= (src_x & 0xFF) << 40
    pkt |= (src_y & 0xFF) << 32
    pkt |= ((src_id << 8) | dst_id) & 0xFFFFFFFF
    return pkt

def build_imem():
    prog = []
    for i in range(15):
        poll_out_addr = len(prog) * 4
        prog.append(vld(8, 0, NIC_OUT_STATUS))
        prog.append(vbneq(8, poll_out_addr))
        prog.append(vld(9, 0, i))
        prog.append(vsd(9, 0, NIC_OUT))

        poll_in_addr = len(prog) * 4
        prog.append(vld(8, 0, NIC_IN_STATUS))
        prog.append(vbeq(8, poll_in_addr))
        prog.append(vld(9, 0, NIC_IN))
        prog.append(vsd(9, 0, 16 + i))

    done_addr = len(prog) * 4
    prog.append(vbeq(0, done_addr))
    return prog

def write_imem_fill(filename, instructions):
    with open(filename, 'w') as f:
        for i in range(IMEM_DEPTH):
            word = instructions[i] if i < len(instructions) else vnop()
            f.write(f"{word:08x}\n")

def write_dmem_fill(filename, outgoing_pkts):
    assert len(outgoing_pkts) == 15
    with open(filename, 'w') as f:
        for i in range(DMEM_DEPTH):
            word = outgoing_pkts[i] if i < 15 else 0
            f.write(f"{word:016x}\n")

def main():
    out_dir = "." if len(sys.argv) < 2 else sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)

    print("=" * 60)
    print("Cardinal Phase 3 -- cmp_test fill file generator")
    print(f"Output directory: {os.path.abspath(out_dir)}")
    print("=" * 60)

    instructions = build_imem()
    print(f"\nIMEM: {len(instructions)} instructions")
    for idx, w in enumerate(instructions):
        print(f"  [{idx:3d}] byte=0x{idx*4:04x}  {w:08x}")

    print("\nSanity check node00->node33:")
    p = make_packet(0, 0, 3, 3)
    print(f"  0x{p:016x}  VC={(p>>63)&1} dirX={(p>>62)&1} dirY={(p>>61)&1} "
          f"hopX={hex((p>>52)&0xF)} hopY={hex((p>>48)&0xF)}")
    print()

    for src_y in range(4):
        for src_x in range(4):
            xy = f"{src_x}{src_y}"
            outgoing = [make_packet(src_x, src_y, dx, dy)
                        for dy in range(4) for dx in range(4)
                        if not (dx == src_x and dy == src_y)]
            assert len(outgoing) == 15

            imem_path = os.path.join(out_dir, f"cmp_test.imem.{xy}.fill")
            dmem_path = os.path.join(out_dir, f"cmp_test.dmem.{xy}.fill")
            write_imem_fill(imem_path, instructions)
            write_dmem_fill(dmem_path, outgoing)
            print(f"  node{xy} -> {imem_path}, {dmem_path}")

    print()
    print(f"Done. 32 fill files generated.")
    print(f"IMEM identical for all nodes. DMEM[0..14] unique per node.")
    print("=" * 60)

if __name__ == "__main__":
    main()
