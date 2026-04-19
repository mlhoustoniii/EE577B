; =============================================================================
; cmp_test.asm  --  Cardinal 4x4 CMP All-to-All Communication Test
; EE 577B  Phase 3
;
; PURPOSE:
;   Each node sends 15 packets (one to every other node) and receives 15
;   packets (one from every other node).  Send and receive loops are
;   INTERLEAVED to prevent network deadlock -- the NIC must never block
;   because the CPU is stuck in a pure send or pure receive spin.
;
; PACKET HEADER (64-bit, Phase 1 convention):
;   [63]     = VC        0 = even VC (always 0 in this test)
;   [62]     = dirX      0 = East,  1 = West
;   [61]     = dirY      0 = South, 1 = North
;   [60:56]  = reserved  5'b0
;   [55:52]  = hopX      unary: 0->4'h0, 1->4'h1, 2->4'h3, 3->4'h7
;   [51:48]  = hopY      unary: same encoding
;   [47:40]  = src_x     sender column (0-3)
;   [39:32]  = src_y     sender row    (0-3)
;   [31:0]   = payload   NODE_ID (8-bit) in bits [7:0], rest 0
;
; NIC MEMORY MAP (two-bit decode per NIC spec):
;   addr_out[16] && addr_out[17] = 1  ->  NIC region
;   NIC addresses therefore live in the 0xCxxx range (top two bits of the
;   16-bit immediate are both 1), and the bottom two bits select the reg.
;   NIC_IN         = 0xC000   addr[1:0]=2'b00   read incoming packet
;   NIC_IN_STATUS  = 0xC001   addr[1:0]=2'b01   1=packet waiting, 0=empty
;   NIC_OUT        = 0xC002   addr[1:0]=2'b10   write outgoing packet
;   NIC_OUT_STATUS = 0xC003   addr[1:0]=2'b11   0=ready to accept, 1=full
;
; DMEM LAYOUT (pre-loaded by generator script):
;   MEM[0]  .. MEM[14]  : 15 outgoing packets (one per destination node,
;                          ordered by dest NODE_ID skipping self)
;   MEM[15]             : scratch / send index (initialised to 0 by CPU)
;   MEM[16] .. MEM[30]  : incoming packet slots (pre-loaded to 0)
;   MEM[31]             : receive index (initialised to 0 by CPU)
;
; REGISTER ALLOCATION:
;   r0   = 0 (hard-wired zero)
;   r1   = NIC_IN         base addr  (0xC000)
;   r2   = NIC_IN_STATUS  addr       (0xC001)
;   r3   = NIC_OUT        addr       (0xC002)
;   r4   = NIC_OUT_STATUS addr       (0xC003)
;   r5   = constant 15  (packet count)
;   r6   = send_index   (0..14, next outgoing packet slot)
;   r7   = recv_index   (0..14, next incoming DMEM slot = index+16)
;   r8   = tmp status read
;   r9   = tmp packet data
;   r10  = DMEM base offset for outgoing (0)
;   r11  = DMEM base offset for incoming (16)
;   r12  = constant 1  (increment)
;   r13  = tmp compare result
;   r14  = tmp DMEM address for store
;   r15  = (free / NOP target)
;   r16..r30 = used transiently inside send/recv macros
;
; NOTE: This is a TEMPLATE.  The Python generator script instantiates it for
; each node by pre-loading DMEM[0..14] with correct pre-computed packet
; words; the assembly itself is IDENTICAL for all 16 nodes.
; =============================================================================

; ---------------------------------------------------------------------------
; INIT: set up constants in registers
; ---------------------------------------------------------------------------
init:
    VMOVI  r1,  0xC000          ; NIC_IN base address
    VMOVI  r2,  0xC001          ; NIC_IN_STATUS address
    VMOVI  r3,  0xC002          ; NIC_OUT address
    VMOVI  r4,  0xC003          ; NIC_OUT_STATUS address
    VMOVI  r5,  15              ; total packets to send / receive
    VMOVI  r6,  0               ; send_index = 0
    VMOVI  r7,  0               ; recv_index = 0
    VMOVI  r10, 0               ; outgoing DMEM base offset
    VMOVI  r11, 16              ; incoming DMEM base offset  (MEM[16])
    VMOVI  r12, 1               ; loop increment

; ---------------------------------------------------------------------------
; MAIN LOOP: interleaved send + receive
;
; Each iteration:
;   (A) If send_index < 15 AND NIC_OUT is not full  -> send next packet
;   (B) If recv_index < 15 AND NIC_IN  has a packet -> receive next packet
;   (C) If both send_index==15 AND recv_index==15   -> goto done
; ---------------------------------------------------------------------------
main_loop:

    ; -----------------------------------------------------------------------
    ; CHECK DONE: if sent==15 && received==15 -> exit
    ; -----------------------------------------------------------------------
    VCEQ   r13, r6, r5          ; r13 = (send_index == 15)
    VBEQ   r13, r0, check_send  ; if NOT done sending, skip done-check
    VCEQ   r13, r7, r5          ; r13 = (recv_index == 15)
    VBNEQ  r13, r0, done        ; if both done -> halt

check_send:
    ; -----------------------------------------------------------------------
    ; (A) TRY TO SEND  -- only if send_index < 15
    ; -----------------------------------------------------------------------
    VCEQ   r13, r6, r5          ; r13 = (send_index == 15)
    VBNEQ  r13, r0, check_recv  ; skip send if already sent all 15

    ; poll NIC_OUT_STATUS -- 0 = ready, 1 = full
    VLD    r8, 0(r3)            ; read NIC_OUT_STATUS (addr r3 = 0xC003)
                                ; NOTE: addr is passed as-is; the CPU
                                ; decodes addr[16]&addr[17]=1 -> NIC,
                                ; addr[1:0] selects register.
                                ; We use r4 for status, r3 for data write.
    ; Re-issue properly via the right register:
    VLD    r8, 0(r4)            ; NIC_OUT_STATUS: 0=ready, nonzero=full
    VBNEQ  r8, r0, check_recv   ; if full, skip send this iteration

    ; NIC output buffer is ready -- load packet from DMEM[send_index]
    ; DMEM address = send_index + 0  (base offset r10 = 0)
    VADD   r14, r6, r10         ; r14 = send_index (DMEM word address)
    VLD    r9, 0(r14)           ; r9 = outgoing packet from DMEM[send_index]

    ; write packet to NIC_OUT
    VSD    r9, 0(r3)            ; store to NIC_OUT (addr 0xC002)

    ; advance send_index
    VADD   r6, r6, r12          ; send_index++

check_recv:
    ; -----------------------------------------------------------------------
    ; (B) TRY TO RECEIVE -- only if recv_index < 15
    ; -----------------------------------------------------------------------
    VCEQ   r13, r7, r5          ; r13 = (recv_index == 15)
    VBNEQ  r13, r0, main_loop   ; skip receive if already got all 15

    ; poll NIC_IN_STATUS -- 1 = packet available, 0 = empty
    VLD    r8, 0(r2)            ; NIC_IN_STATUS (addr 0xC001)
    VBEQ   r8, r0, main_loop    ; if empty, loop again

    ; packet is waiting -- read it
    VLD    r9, 0(r1)            ; NIC_IN (addr 0xC000) -> r9

    ; store into DMEM[16 + recv_index]
    VADD   r14, r7, r11         ; r14 = recv_index + 16
    VSD    r9, 0(r14)           ; DMEM[16+recv_index] = received packet

    ; advance recv_index
    VADD   r7, r7, r12          ; recv_index++

    ; loop
    VJMP   main_loop

; ---------------------------------------------------------------------------
; DONE: all 15 packets sent and all 15 received
;       Spin on a NOP so the testbench can detect completion by watching
;       recv_index reach 15  (monitor r7 == 15 in tb_cardinal_cmp.v)
; ---------------------------------------------------------------------------
done:
    VNOP
    VNOP
    VJMP   done                 ; infinite halt loop -- TB detects completion
                                ; by polling DMEM[31] or snooping recv_index

; =============================================================================
; END OF cmp_test.asm
;
; COMPILATION NOTE:
;   The Python generator script (gen_cmp_fill.py) does NOT invoke an
;   assembler directly.  Instead it:
;     1. Encodes the above instructions manually into 32-bit hex words
;        using the Cardinal ISA encoding table from Phase 2.
;     2. Writes cmp_test.imem.XY.fill (identical for all 16 nodes).
;     3. Computes all 15 pre-built 64-bit packet words for each node and
;        writes cmp_test.dmem.XY.fill (unique per node).
;
; REGISTER ENCODING REMINDER (Cardinal ISA):
;   VMOVI  rd, imm16    -- move 16-bit immediate into rd
;   VLD    rd, imm(rs)  -- load DMEM[rs+imm] into rd  (or NIC if rs in NIC range)
;   VSD    rs, imm(rb)  -- store rs to DMEM[rb+imm]
;   VADD   rd, rs, rt   -- rd = rs + rt
;   VCEQ   rd, rs, rt   -- rd = (rs == rt) ? 1 : 0
;   VBEQ   rs, rt, lbl  -- branch if rs == rt
;   VBNEQ  rs, rt, lbl  -- branch if rs != rt
;   VJMP   lbl          -- unconditional jump
;   VNOP               -- no operation
; =============================================================================