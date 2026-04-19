/////////////////////////////////////////////////////////////////////
// Project      : EE577B Spring2026 Cardinal Processor - Phase 2
// Filename     : ex_mem_stage.v
// Description  : EX/MEM Stage -- ALU + memory/NIC interface (combinational)
//
// Boundary contract:
//   - All inputs come directly from the ID/EX pipeline register.
//   - alu_result is combinational: it feeds both the EX/WB pipeline
//     register (clocked in top level) and the forwarding mux (same cycle).
//   - Memory interface outputs (memEn, memWrEn, addr_out, d_out) are
//     combinational pass-throughs gated on mem_en / mem_wr and on the
//     NIC-vs-DMEM address decode.
//   - No registers inside this module -- purely combinational.
//   - is_rtype gates all ALU operations: load/store leave alu_result=0.
//
// ============================================================
//  NIC ADDRESS DECODE (EE577B Part 3 -- NIC integration)
// ============================================================
//   Per Cardinal NIC spec "Interfacing with Processor":
//     If memAddr[16] && memAddr[17]:
//        access is to a NIC register (memAddr[30:31] selects which)
//     Otherwise:
//        access is to data memory (lower 8 bits used as index)
//
//   The effective address here is EA = {16'b0, imm_addr}. In big-endian
//   [0:31] bit numbering, the imm_addr[0:15] bits land on addr_out[16:31].
//   So:
//     addr_out[16] = imm_addr[0]
//     addr_out[17] = imm_addr[1]
//     addr_out[30] = imm_addr[14]  (NIC reg select MSB)
//     addr_out[31] = imm_addr[15]  (NIC reg select LSB)
//
//   is_nic_access is true when BOTH addr_out[16] and addr_out[17] are 1.
//   memEn / memWrEn are gated OFF for NIC accesses.
//   nicEn / nicEnWr are gated ON  for NIC accesses.
//   Exactly one device is enabled per memory-reference instruction.
//
// ALU operand/result convention (Big-Endian bit numbering):
//   bit 0 = MSB, bit 63 = LSB of every 64-bit vector.
//   Subfield indices follow ISA manual Figure 1 table (ww selects width).
//
// ww encoding:   00=8-bit  01=16-bit  10=32-bit  11=64-bit
//
// Memory address: EA = {16'b0, imm_addr}  (immediate is full word address)
// Store data:     d_out = rA_data  (top level captured forwarded rD into
//                                   idex_rA_data for store instructions)
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module ex_mem_stage (
    // ---- From ID/EX pipeline register ----
    input  [0:63]  rA_data,     // ALU operand A (or store source data)
    input  [0:63]  rB_data,     // ALU operand B
    input  [0:5]   alu_func,    // R-type function code
    input  [0:1]   ww,          // Word-width field
    input          is_rtype,    // Gate: only compute ALU when high
    input          mem_en,      // Memory-reference enable (load or store)
    input          mem_wr,      // Memory write enable (store)
    input  [0:15]  imm_addr,    // Immediate memory address

    // ---- Outputs ----
    output [0:63]  alu_result,  // Combinational ALU output
    output         memEn,       // DMEM enable    (gated off for NIC access)
    output         memWrEn,     // DMEM write en  (gated off for NIC access)
    output         nicEn,       // NIC enable     (gated off for DMEM access)
    output         nicEnWr,     // NIC write en   (gated off for DMEM access)
    output         is_nic,      // High when this access targets the NIC
                                //  -- forwarded to EX/WB so WB stage can
                                //     mux load data from nic_d_in vs d_in
    output [0:31]  addr_out,    // EA = {16'b0, imm_addr}
    output [0:63]  d_out        // Store data = rA_data
);

// ============================================================
//  func code constants (ISA encoding table)
// ============================================================
localparam FUNC_VAND   = 6'b000001;
localparam FUNC_VOR    = 6'b000010;
localparam FUNC_VXOR   = 6'b000011;
localparam FUNC_VNOT   = 6'b000100;
localparam FUNC_VMOV   = 6'b000101;
localparam FUNC_VADD   = 6'b000110;
localparam FUNC_VSUB   = 6'b000111;
localparam FUNC_VMULEU = 6'b001000;
localparam FUNC_VMULOU = 6'b001001;
localparam FUNC_VSLL   = 6'b001010;
localparam FUNC_VSRL   = 6'b001011;
localparam FUNC_VSRA   = 6'b001100;
localparam FUNC_VRTTH  = 6'b001101;
localparam FUNC_VDIV   = 6'b001110;
localparam FUNC_VMOD   = 6'b001111;
localparam FUNC_VSQEU  = 6'b010000;
localparam FUNC_VSQOU  = 6'b010001;
localparam FUNC_VSQRT  = 6'b010010;

// ============================================================
//  Integer square-root functions (unsigned)
// ============================================================
function [7:0] isqrt8;
    input [7:0] val;
    reg [7:0] res, bit_mask;
    integer k;
    begin
        res = 0;
        for (k = 3; k >= 0; k = k - 1) begin
            bit_mask = res | (8'd1 << k);
            if (bit_mask * bit_mask <= val) res = bit_mask;
        end
        isqrt8 = res;
    end
endfunction

function [15:0] isqrt16;
    input [15:0] val;
    reg [15:0] res, bit_mask;
    integer k;
    begin
        res = 0;
        for (k = 7; k >= 0; k = k - 1) begin
            bit_mask = res | (16'd1 << k);
            if (bit_mask * bit_mask <= val) res = bit_mask;
        end
        isqrt16 = res;
    end
endfunction

function [31:0] isqrt32;
    input [31:0] val;
    reg [31:0] res, bit_mask;
    reg [63:0] product;
    integer k;
    begin
        res = 0;
        for (k = 15; k >= 0; k = k - 1) begin
            bit_mask = res | (32'd1 << k);
            product  = bit_mask * bit_mask;
            if (product <= {32'd0, val}) res = bit_mask;
        end
        isqrt32 = res;
    end
endfunction

function [63:0] isqrt64;
    input [63:0] val;
    reg [63:0] res, bit_mask, product_lo;
    integer k;
    begin
        res = 0;
        for (k = 31; k >= 0; k = k - 1) begin
            bit_mask   = res | (64'd1 << k);
            product_lo = bit_mask * bit_mask;
            if (product_lo <= val) res = bit_mask;
        end
        isqrt64 = res;
    end
endfunction

// ============================================================
//  ALU
// ============================================================
reg [0:63] alu_out;

always @(*) begin
    alu_out = 64'd0;

    if (is_rtype) begin
        case (alu_func)

            // --------------------------------------------------
            // Bitwise -- ww does not affect result (ISA note)
            // --------------------------------------------------
            FUNC_VAND: alu_out = rA_data & rB_data;
            FUNC_VOR:  alu_out = rA_data | rB_data;
            FUNC_VXOR: alu_out = rA_data ^ rB_data;
            FUNC_VNOT: alu_out = ~rA_data;
            FUNC_VMOV: alu_out = rA_data;

            // --------------------------------------------------
            // VADD -- variable width unsigned add, carries dropped
            // --------------------------------------------------
            FUNC_VADD: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = rA_data[0:7]   + rB_data[0:7];
                        alu_out[8:15]  = rA_data[8:15]  + rB_data[8:15];
                        alu_out[16:23] = rA_data[16:23] + rB_data[16:23];
                        alu_out[24:31] = rA_data[24:31] + rB_data[24:31];
                        alu_out[32:39] = rA_data[32:39] + rB_data[32:39];
                        alu_out[40:47] = rA_data[40:47] + rB_data[40:47];
                        alu_out[48:55] = rA_data[48:55] + rB_data[48:55];
                        alu_out[56:63] = rA_data[56:63] + rB_data[56:63];
                    end
                    2'b01: begin
                        alu_out[0:15]  = rA_data[0:15]  + rB_data[0:15];
                        alu_out[16:31] = rA_data[16:31] + rB_data[16:31];
                        alu_out[32:47] = rA_data[32:47] + rB_data[32:47];
                        alu_out[48:63] = rA_data[48:63] + rB_data[48:63];
                    end
                    2'b10: begin
                        alu_out[0:31]  = rA_data[0:31]  + rB_data[0:31];
                        alu_out[32:63] = rA_data[32:63] + rB_data[32:63];
                    end
                    2'b11: alu_out = rA_data + rB_data;
                endcase
            end

            // --------------------------------------------------
            // VSUB -- variable width unsigned subtract
            // --------------------------------------------------
            FUNC_VSUB: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = rA_data[0:7]   - rB_data[0:7];
                        alu_out[8:15]  = rA_data[8:15]  - rB_data[8:15];
                        alu_out[16:23] = rA_data[16:23] - rB_data[16:23];
                        alu_out[24:31] = rA_data[24:31] - rB_data[24:31];
                        alu_out[32:39] = rA_data[32:39] - rB_data[32:39];
                        alu_out[40:47] = rA_data[40:47] - rB_data[40:47];
                        alu_out[48:55] = rA_data[48:55] - rB_data[48:55];
                        alu_out[56:63] = rA_data[56:63] - rB_data[56:63];
                    end
                    2'b01: begin
                        alu_out[0:15]  = rA_data[0:15]  - rB_data[0:15];
                        alu_out[16:31] = rA_data[16:31] - rB_data[16:31];
                        alu_out[32:47] = rA_data[32:47] - rB_data[32:47];
                        alu_out[48:63] = rA_data[48:63] - rB_data[48:63];
                    end
                    2'b10: begin
                        alu_out[0:31]  = rA_data[0:31]  - rB_data[0:31];
                        alu_out[32:63] = rA_data[32:63] - rB_data[32:63];
                    end
                    2'b11: alu_out = rA_data - rB_data;
                endcase
            end

            // --------------------------------------------------
            // VMULEU -- multiply even subfields, double-width result
            // --------------------------------------------------
            FUNC_VMULEU: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:15]  = rA_data[0:7]   * rB_data[0:7];
                        alu_out[16:31] = rA_data[16:23] * rB_data[16:23];
                        alu_out[32:47] = rA_data[32:39] * rB_data[32:39];
                        alu_out[48:63] = rA_data[48:55] * rB_data[48:55];
                    end
                    2'b01: begin
                        alu_out[0:31]  = rA_data[0:15]  * rB_data[0:15];
                        alu_out[32:63] = rA_data[32:47] * rB_data[32:47];
                    end
                    2'b10: alu_out = rA_data[0:31] * rB_data[0:31];
                    default: alu_out = 64'd0;
                endcase
            end

            // --------------------------------------------------
            // VMULOU -- multiply odd subfields, double-width result
            // --------------------------------------------------
            FUNC_VMULOU: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:15]  = rA_data[8:15]  * rB_data[8:15];
                        alu_out[16:31] = rA_data[24:31] * rB_data[24:31];
                        alu_out[32:47] = rA_data[40:47] * rB_data[40:47];
                        alu_out[48:63] = rA_data[56:63] * rB_data[56:63];
                    end
                    2'b01: begin
                        alu_out[0:31]  = rA_data[16:31] * rB_data[16:31];
                        alu_out[32:63] = rA_data[48:63] * rB_data[48:63];
                    end
                    2'b10: alu_out = rA_data[32:63] * rB_data[32:63];
                    default: alu_out = 64'd0;
                endcase
            end

            // --------------------------------------------------
            // VSLL -- shift left logical
            // --------------------------------------------------
            FUNC_VSLL: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = rA_data[0:7]   << rB_data[5:7];
                        alu_out[8:15]  = rA_data[8:15]  << rB_data[13:15];
                        alu_out[16:23] = rA_data[16:23] << rB_data[21:23];
                        alu_out[24:31] = rA_data[24:31] << rB_data[29:31];
                        alu_out[32:39] = rA_data[32:39] << rB_data[37:39];
                        alu_out[40:47] = rA_data[40:47] << rB_data[45:47];
                        alu_out[48:55] = rA_data[48:55] << rB_data[53:55];
                        alu_out[56:63] = rA_data[56:63] << rB_data[61:63];
                    end
                    2'b01: begin
                        alu_out[0:15]  = rA_data[0:15]  << rB_data[12:15];
                        alu_out[16:31] = rA_data[16:31] << rB_data[28:31];
                        alu_out[32:47] = rA_data[32:47] << rB_data[44:47];
                        alu_out[48:63] = rA_data[48:63] << rB_data[60:63];
                    end
                    2'b10: begin
                        alu_out[0:31]  = rA_data[0:31]  << rB_data[27:31];
                        alu_out[32:63] = rA_data[32:63] << rB_data[59:63];
                    end
                    2'b11: alu_out = rA_data << rB_data[58:63];
                endcase
            end

            // --------------------------------------------------
            // VSRL -- shift right logical
            // --------------------------------------------------
            FUNC_VSRL: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = rA_data[0:7]   >> rB_data[5:7];
                        alu_out[8:15]  = rA_data[8:15]  >> rB_data[13:15];
                        alu_out[16:23] = rA_data[16:23] >> rB_data[21:23];
                        alu_out[24:31] = rA_data[24:31] >> rB_data[29:31];
                        alu_out[32:39] = rA_data[32:39] >> rB_data[37:39];
                        alu_out[40:47] = rA_data[40:47] >> rB_data[45:47];
                        alu_out[48:55] = rA_data[48:55] >> rB_data[53:55];
                        alu_out[56:63] = rA_data[56:63] >> rB_data[61:63];
                    end
                    2'b01: begin
                        alu_out[0:15]  = rA_data[0:15]  >> rB_data[12:15];
                        alu_out[16:31] = rA_data[16:31] >> rB_data[28:31];
                        alu_out[32:47] = rA_data[32:47] >> rB_data[44:47];
                        alu_out[48:63] = rA_data[48:63] >> rB_data[60:63];
                    end
                    2'b10: begin
                        alu_out[0:31]  = rA_data[0:31]  >> rB_data[27:31];
                        alu_out[32:63] = rA_data[32:63] >> rB_data[59:63];
                    end
                    2'b11: alu_out = rA_data >> rB_data[58:63];
                endcase
            end

            // --------------------------------------------------
            // VSRA -- shift right arithmetic
            // --------------------------------------------------
            FUNC_VSRA: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = $signed(rA_data[0:7])   >>> rB_data[5:7];
                        alu_out[8:15]  = $signed(rA_data[8:15])  >>> rB_data[13:15];
                        alu_out[16:23] = $signed(rA_data[16:23]) >>> rB_data[21:23];
                        alu_out[24:31] = $signed(rA_data[24:31]) >>> rB_data[29:31];
                        alu_out[32:39] = $signed(rA_data[32:39]) >>> rB_data[37:39];
                        alu_out[40:47] = $signed(rA_data[40:47]) >>> rB_data[45:47];
                        alu_out[48:55] = $signed(rA_data[48:55]) >>> rB_data[53:55];
                        alu_out[56:63] = $signed(rA_data[56:63]) >>> rB_data[61:63];
                    end
                    2'b01: begin
                        alu_out[0:15]  = $signed(rA_data[0:15])  >>> rB_data[12:15];
                        alu_out[16:31] = $signed(rA_data[16:31]) >>> rB_data[28:31];
                        alu_out[32:47] = $signed(rA_data[32:47]) >>> rB_data[44:47];
                        alu_out[48:63] = $signed(rA_data[48:63]) >>> rB_data[60:63];
                    end
                    2'b10: begin
                        alu_out[0:31]  = $signed(rA_data[0:31])  >>> rB_data[27:31];
                        alu_out[32:63] = $signed(rA_data[32:63]) >>> rB_data[59:63];
                    end
                    2'b11: alu_out = $signed(rA_data) >>> rB_data[58:63];
                endcase
            end

            // --------------------------------------------------
            // VRTTH -- rotate by half
            // --------------------------------------------------
            FUNC_VRTTH: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = {rA_data[4:7],   rA_data[0:3]};
                        alu_out[8:15]  = {rA_data[12:15], rA_data[8:11]};
                        alu_out[16:23] = {rA_data[20:23], rA_data[16:19]};
                        alu_out[24:31] = {rA_data[28:31], rA_data[24:27]};
                        alu_out[32:39] = {rA_data[36:39], rA_data[32:35]};
                        alu_out[40:47] = {rA_data[44:47], rA_data[40:43]};
                        alu_out[48:55] = {rA_data[52:55], rA_data[48:51]};
                        alu_out[56:63] = {rA_data[60:63], rA_data[56:59]};
                    end
                    2'b01: begin
                        alu_out[0:15]  = {rA_data[8:15],  rA_data[0:7]};
                        alu_out[16:31] = {rA_data[24:31], rA_data[16:23]};
                        alu_out[32:47] = {rA_data[40:47], rA_data[32:39]};
                        alu_out[48:63] = {rA_data[56:63], rA_data[48:55]};
                    end
                    2'b10: begin
                        alu_out[0:31]  = {rA_data[16:31], rA_data[0:15]};
                        alu_out[32:63] = {rA_data[48:63], rA_data[32:47]};
                    end
                    2'b11: alu_out = {rA_data[32:63], rA_data[0:31]};
                endcase
            end

            // --------------------------------------------------
            // VDIV -- unsigned integer divide
            // --------------------------------------------------
            FUNC_VDIV: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = (rB_data[0:7]   != 0) ? rA_data[0:7]   / rB_data[0:7]   : 8'hFF;
                        alu_out[8:15]  = (rB_data[8:15]  != 0) ? rA_data[8:15]  / rB_data[8:15]  : 8'hFF;
                        alu_out[16:23] = (rB_data[16:23] != 0) ? rA_data[16:23] / rB_data[16:23] : 8'hFF;
                        alu_out[24:31] = (rB_data[24:31] != 0) ? rA_data[24:31] / rB_data[24:31] : 8'hFF;
                        alu_out[32:39] = (rB_data[32:39] != 0) ? rA_data[32:39] / rB_data[32:39] : 8'hFF;
                        alu_out[40:47] = (rB_data[40:47] != 0) ? rA_data[40:47] / rB_data[40:47] : 8'hFF;
                        alu_out[48:55] = (rB_data[48:55] != 0) ? rA_data[48:55] / rB_data[48:55] : 8'hFF;
                        alu_out[56:63] = (rB_data[56:63] != 0) ? rA_data[56:63] / rB_data[56:63] : 8'hFF;
                    end
                    2'b01: begin
                        alu_out[0:15]  = (rB_data[0:15]  != 0) ? rA_data[0:15]  / rB_data[0:15]  : 16'hFFFF;
                        alu_out[16:31] = (rB_data[16:31] != 0) ? rA_data[16:31] / rB_data[16:31] : 16'hFFFF;
                        alu_out[32:47] = (rB_data[32:47] != 0) ? rA_data[32:47] / rB_data[32:47] : 16'hFFFF;
                        alu_out[48:63] = (rB_data[48:63] != 0) ? rA_data[48:63] / rB_data[48:63] : 16'hFFFF;
                    end
                    2'b10: begin
                        alu_out[0:31]  = (rB_data[0:31]  != 0) ? rA_data[0:31]  / rB_data[0:31]  : 32'hFFFFFFFF;
                        alu_out[32:63] = (rB_data[32:63] != 0) ? rA_data[32:63] / rB_data[32:63] : 32'hFFFFFFFF;
                    end
                    2'b11: alu_out = (rB_data != 0) ? rA_data / rB_data : 64'hFFFFFFFFFFFFFFFF;
                endcase
            end

            // --------------------------------------------------
            // VMOD -- unsigned integer modulo
            // --------------------------------------------------
            FUNC_VMOD: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = (rB_data[0:7]   != 0) ? rA_data[0:7]   % rB_data[0:7]   : rA_data[0:7];
                        alu_out[8:15]  = (rB_data[8:15]  != 0) ? rA_data[8:15]  % rB_data[8:15]  : rA_data[8:15];
                        alu_out[16:23] = (rB_data[16:23] != 0) ? rA_data[16:23] % rB_data[16:23] : rA_data[16:23];
                        alu_out[24:31] = (rB_data[24:31] != 0) ? rA_data[24:31] % rB_data[24:31] : rA_data[24:31];
                        alu_out[32:39] = (rB_data[32:39] != 0) ? rA_data[32:39] % rB_data[32:39] : rA_data[32:39];
                        alu_out[40:47] = (rB_data[40:47] != 0) ? rA_data[40:47] % rB_data[40:47] : rA_data[40:47];
                        alu_out[48:55] = (rB_data[48:55] != 0) ? rA_data[48:55] % rB_data[48:55] : rA_data[48:55];
                        alu_out[56:63] = (rB_data[56:63] != 0) ? rA_data[56:63] % rB_data[56:63] : rA_data[56:63];
                    end
                    2'b01: begin
                        alu_out[0:15]  = (rB_data[0:15]  != 0) ? rA_data[0:15]  % rB_data[0:15]  : rA_data[0:15];
                        alu_out[16:31] = (rB_data[16:31] != 0) ? rA_data[16:31] % rB_data[16:31] : rA_data[16:31];
                        alu_out[32:47] = (rB_data[32:47] != 0) ? rA_data[32:47] % rB_data[32:47] : rA_data[32:47];
                        alu_out[48:63] = (rB_data[48:63] != 0) ? rA_data[48:63] % rB_data[48:63] : rA_data[48:63];
                    end
                    2'b10: begin
                        alu_out[0:31]  = (rB_data[0:31]  != 0) ? rA_data[0:31]  % rB_data[0:31]  : rA_data[0:31];
                        alu_out[32:63] = (rB_data[32:63] != 0) ? rA_data[32:63] % rB_data[32:63] : rA_data[32:63];
                    end
                    2'b11: alu_out = (rB_data != 0) ? rA_data % rB_data : rA_data;
                endcase
            end

            // --------------------------------------------------
            // VSQEU -- square even subfields
            // --------------------------------------------------
            FUNC_VSQEU: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:15]  = rA_data[0:7]   * rA_data[0:7];
                        alu_out[16:31] = rA_data[16:23] * rA_data[16:23];
                        alu_out[32:47] = rA_data[32:39] * rA_data[32:39];
                        alu_out[48:63] = rA_data[48:55] * rA_data[48:55];
                    end
                    2'b01: begin
                        alu_out[0:31]  = rA_data[0:15]  * rA_data[0:15];
                        alu_out[32:63] = rA_data[32:47] * rA_data[32:47];
                    end
                    2'b10: alu_out = rA_data[0:31] * rA_data[0:31];
                    default: alu_out = 64'd0;
                endcase
            end

            // --------------------------------------------------
            // VSQOU -- square odd subfields
            // --------------------------------------------------
            FUNC_VSQOU: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:15]  = rA_data[8:15]  * rA_data[8:15];
                        alu_out[16:31] = rA_data[24:31] * rA_data[24:31];
                        alu_out[32:47] = rA_data[40:47] * rA_data[40:47];
                        alu_out[48:63] = rA_data[56:63] * rA_data[56:63];
                    end
                    2'b01: begin
                        alu_out[0:31]  = rA_data[16:31] * rA_data[16:31];
                        alu_out[32:63] = rA_data[48:63] * rA_data[48:63];
                    end
                    2'b10: alu_out = rA_data[32:63] * rA_data[32:63];
                    default: alu_out = 64'd0;
                endcase
            end

            // --------------------------------------------------
            // VSQRT -- unsigned integer square root
            // --------------------------------------------------
            FUNC_VSQRT: begin
                case (ww)
                    2'b00: begin
                        alu_out[0:7]   = isqrt8(rA_data[0:7]);
                        alu_out[8:15]  = isqrt8(rA_data[8:15]);
                        alu_out[16:23] = isqrt8(rA_data[16:23]);
                        alu_out[24:31] = isqrt8(rA_data[24:31]);
                        alu_out[32:39] = isqrt8(rA_data[32:39]);
                        alu_out[40:47] = isqrt8(rA_data[40:47]);
                        alu_out[48:55] = isqrt8(rA_data[48:55]);
                        alu_out[56:63] = isqrt8(rA_data[56:63]);
                    end
                    2'b01: begin
                        alu_out[0:15]  = isqrt16(rA_data[0:15]);
                        alu_out[16:31] = isqrt16(rA_data[16:31]);
                        alu_out[32:47] = isqrt16(rA_data[32:47]);
                        alu_out[48:63] = isqrt16(rA_data[48:63]);
                    end
                    2'b10: begin
                        alu_out[0:31]  = isqrt32(rA_data[0:31]);
                        alu_out[32:63] = isqrt32(rA_data[32:63]);
                    end
                    2'b11: alu_out = isqrt64(rA_data);
                endcase
            end

            default: alu_out = 64'd0;
        endcase
    end
    // is_rtype=0 (load/store/nop): ALU not used, leave alu_out=0
end

assign alu_result = alu_out;

// ============================================================
//  Memory / NIC interface -- purely combinational
// ============================================================
// Effective address. Top 16 bits zero, bottom 16 bits from immediate.
assign addr_out = {16'b0, imm_addr};

// NIC decode: spec says "if memAddr[16] and memAddr[17] are both 1,
// the address refers to a NIC register." This is the EE577B Phase 3
// address-space split between DMEM and the memory-mapped NIC.
wire is_nic_access = addr_out[16] & addr_out[17];
assign is_nic = is_nic_access;

// DMEM enables: active only when the access is NOT targeting the NIC.
assign memEn    = mem_en & ~is_nic_access;
assign memWrEn  = mem_wr & ~is_nic_access;

// NIC enables: active only when the access IS targeting the NIC.
// nicEn  = any memory-reference op (load or store)
// nicEnWr = NIC store (load-type NIC access leaves nicEnWr=0)
assign nicEn    = mem_en &  is_nic_access;
assign nicEnWr  = mem_wr &  is_nic_access;

// Store data path is shared between DMEM and NIC:
// the NIC latches d_out on its own nicEn+nicEnWr handshake.
assign d_out    = rA_data;

endmodule