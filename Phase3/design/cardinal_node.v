/////////////////////////////////////////////////////////////////////
// Project      : EE577B Spring2026 Cardinal CMP - Phase 3
// Filename     : cardinal_node.v
// Description  : Single-node wrapper: one CPU + one IMEM + one DMEM
//                + one NIC, tied to one PE port of the mesh router.
//
// Architecture note (Phase 3 version):
//   The Phase 3 cardinal_cpu was modified per the spec to perform
//   NIC-vs-DMEM address decoding internally and to expose separate
//   memEn/memWrEn and nicEn/nicEnWr output pairs. It also has two
//   load-data input ports: d_in (from DMEM) and nic_d_in (from NIC).
//
//   That means this node wrapper is now PURE STRUCTURAL GLUE. It
//   does NOT do any address decoding, NIC bypass muxing, or load-
//   data selection -- the CPU handles all of that. The wrapper's
//   job is to connect wires:
//
//     CPU memEn/memWrEn  --> dmem enable pins
//     CPU nicEn/nicEnWr  --> NIC enable pins
//     CPU addr_out[30:31]--> NIC addr[1:0]   (register select)
//     CPU d_out          --> dmem.dataIn AND nic.d_in (shared bus)
//     dmem.dataOut       --> CPU d_in
//     nic.d_out          --> CPU nic_d_in
//
//   NIC register mapping (addr[1:0]):
//     2'b00  NIC_IN          (read packet in)
//     2'b01  NIC_IN_STATUS   (read input status)
//     2'b10  NIC_OUT         (write packet out)
//     2'b11  NIC_OUT_STATUS  (read output status)
//
//   Load-path timing:
//     The NIC registers its d_out port. A CPU load to a NIC register
//     arrives at the CPU one cycle later. The CPU's load-use hazard
//     detector already stalls for one cycle after any load, so a
//     dependent instruction cannot consume the NIC data before it
//     is valid. This matches the DMEM timing exactly -- both are
//     "1-cycle latency after the load is issued".
//
// Bit-order note:
//   The CPU uses [0:31] / [0:63] (Cardinal ISA big-endian).
//   The NIC uses [1:0] / [63:0] (standard Verilog).
//   Port-by-name connection aligns by bit index, not by MSB/LSB
//   position, so e.g. cpu_addr_out[30] connects to the MSB of
//   nic.addr and cpu_addr_out[31] to the LSB, which is what we
//   want for the NIC register select.
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module cardinal_node #(
    parameter [5:0] NODE_ID = 6'd0
) (
    input  wire         clk,
    input  wire         reset,

    // ------------------------------------------------------------
    // PE-side connection to this node's mesh router
    // Naming matches the cardinal_mesh PE port convention
    // ------------------------------------------------------------
    input  wire         polarity,   // router polarity to NIC
    output wire         pesi,       // NIC  -> router  send valid
    input  wire         peri,       // router -> NIC   ready
    output wire [63:0]  pedi,       // NIC  -> router  data
    input  wire         peso,       // router -> NIC   send valid
    output wire         pero,       // NIC  -> router  ready
    input  wire [63:0]  pedo        // router -> NIC   data
);

    // ============================================================
    //  CPU <-> wrapper wires
    // ============================================================
    wire [0:31] cpu_pc_out;
    wire [0:31] cpu_inst_in;
    wire [0:31] cpu_addr_out;
    wire        cpu_memEn;
    wire        cpu_memWrEn;
    wire        cpu_nicEn;
    wire        cpu_nicEnWr;
    wire [0:63] cpu_d_out;      // store data from CPU (shared DMEM/NIC)
    wire [0:63] cpu_dmem_d_in;  // load data to CPU from DMEM
    wire [0:63] cpu_nic_d_in;   // load data to CPU from NIC

    // ============================================================
    //  DMEM instance (private, per-node)
    //  Only the low 8 bits of addr_out are used, matching the
    //  Phase 2 testbench wiring and the 256-entry dmem depth.
    //  Enables come directly from the CPU -- the CPU has already
    //  gated memEn off for NIC accesses.
    // ============================================================
    dmem u_dmem (
        .clk      (clk),
        .memEn    (cpu_memEn),
        .memWrEn  (cpu_memWrEn),
        .memAddr  (cpu_addr_out[24:31]),
        .dataIn   (cpu_d_out),
        .dataOut  (cpu_dmem_d_in)
    );

    // ============================================================
    //  IMEM instance (private, per-node)
    //  PC slice matches the Phase 2 testbench (pc_out[22:29]).
    // ============================================================
    imem u_imem (
        .memAddr  (cpu_pc_out[22:29]),
        .dataOut  (cpu_inst_in)
    );

    // ============================================================
    //  NIC instance
    //
    //  Enables come directly from the CPU -- the CPU has already
    //  gated nicEn on only for addresses with addr[16]=1 AND
    //  addr[17]=1 per the NIC spec.
    //
    //  NIC register select takes the bottom two bits of the CPU's
    //  effective address: addr_out[30:31] in big-endian [0:31]
    //  numbering corresponds to the low 2 address bits.
    //
    //  Router PE-port wiring per Section 2.3:
    //     net_si <- peso   (router -> NIC send valid)
    //     net_ri -> pero   (NIC -> router ready)
    //     net_di <- pedo   (router -> NIC data)
    //     net_so -> pesi   (NIC -> router send valid)
    //     net_ro <- peri   (router -> NIC ready)
    //     net_do -> pedi   (NIC -> router data)
    // ============================================================
    cardinal_nic u_nic (
        .clk          (clk),
        .reset        (reset),

        // Processor-side interface
        .addr         ({cpu_addr_out[30], cpu_addr_out[31]}),
        .d_in         (cpu_d_out),
        .d_out        (cpu_nic_d_in),
        .nicEn        (cpu_nicEn),
        .nicWrEn      (cpu_nicEnWr),

        // Router-side input channel (router -> NIC)
        .net_si       (peso),
        .net_ri       (pero),
        .net_di       (pedo),

        // Router-side output channel (NIC -> router)
        .net_so       (pesi),
        .net_ro       (peri),
        .net_do       (pedi),

        // Router polarity
        .net_polarity (polarity)
    );

    // ============================================================
    //  CPU instance (Phase 3 version with NIC integration)
    // ============================================================
    cardinal_cpu u_cpu (
        .clk       (clk),
        .reset     (reset),
        .inst_in   (cpu_inst_in),
        .d_in      (cpu_dmem_d_in),
        .nic_d_in  (cpu_nic_d_in),
        .pc_out    (cpu_pc_out),
        .addr_out  (cpu_addr_out),
        .memEn     (cpu_memEn),
        .memWrEn   (cpu_memWrEn),
        .nicEn     (cpu_nicEn),
        .nicEnWr   (cpu_nicEnWr),
        .d_out     (cpu_d_out)
    );

endmodule