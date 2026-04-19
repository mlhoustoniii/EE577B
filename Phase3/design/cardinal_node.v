`timescale 1ns/10ps
/////////////////////////////////////////////////////////////////////
// cardinal_node.v  (Phase 4 synthesis-ready revision)
//
// CHANGE FROM PHASE 3:
//   The combinational NIC read bypass (Section 2.4, Option 1)
//   previously used hierarchical references to read NIC internals:
//     u_nic.net_input_buf
//     u_nic.input_status
//     u_nic.output_status
//
//   These are now driven via the three new output ports added to
//   cardinal_nic in the Phase 4 revision:
//     net_input_buf_out  -> nic_input_buf
//     input_status_out   -> nic_input_status
//     output_status_out  -> nic_output_status
//
//   The bypass mux logic is otherwise bit-for-bit identical.
//   All other wiring is unchanged from Phase 3.
/////////////////////////////////////////////////////////////////////

module cardinal_node #(
    parameter [5:0] NODE_ID = 6'd0
) (
    input  wire         clk,
    input  wire         reset,

    // PE-side connection to this node's mesh router
    input  wire         polarity,
    output wire         pesi,
    input  wire         peri,
    output wire [63:0]  pedi,
    input  wire         peso,
    output wire         pero,
    input  wire [63:0]  pedo
);

    // ============================================================
    //  CPU <-> wrapper wires
    // ============================================================
    wire [0:31] cpu_pc_out;
    wire [0:31] cpu_inst_in;
    wire [0:31] cpu_addr_out;
    wire        cpu_memEn;
    wire        cpu_memWrEn;
    wire [0:63] cpu_d_out;
    reg  [0:63] cpu_d_in;

    // ============================================================
    //  Memory-map decode (unchanged from Phase 3)
    // ============================================================
    wire        nic_select = cpu_addr_out[16];
    wire [1:0]  nic_addr   = {cpu_addr_out[30], cpu_addr_out[31]};

    wire        nic_en     =  cpu_memEn &  nic_select;
    wire        nic_wrEn   =  cpu_memEn &  cpu_memWrEn &  nic_select;

    wire        dmem_en    =  cpu_memEn & ~nic_select;
    wire        dmem_wrEn  =  cpu_memEn &  cpu_memWrEn & ~nic_select;

    // ============================================================
    //  DMEM instance
    // ============================================================
    wire [0:63] dmem_d_out;

    dmem u_dmem (
        .clk      (clk),
        .memEn    (dmem_en),
        .memWrEn  (dmem_wrEn),
        .memAddr  (cpu_addr_out[24:31]),
        .dataIn   (cpu_d_out),
        .dataOut  (dmem_d_out)
    );

    // ============================================================
    //  IMEM instance
    // ============================================================
    imem u_imem (
        .memAddr  (cpu_pc_out[22:29]),
        .dataOut  (cpu_inst_in)
    );

    // ============================================================
    //  NIC instance
    //  New ports net_input_buf_out, input_status_out,
    //  output_status_out are connected to local wires below.
    // ============================================================
    wire [63:0] nic_d_out_unused;

    // Wires for the three promoted NIC internal signals
    wire [63:0] nic_input_buf;      // was u_nic.net_input_buf
    wire        nic_input_status;   // was u_nic.input_status
    wire        nic_output_status;  // was u_nic.output_status

    cardinal_nic u_nic (
        .clk                (clk),
        .reset              (reset),

        // Processor-side interface
        .addr               (nic_addr),
        .d_in               (cpu_d_out),
        .d_out              (nic_d_out_unused),
        .nicEn              (nic_en),
        .nicWrEn            (nic_wrEn),

        // Router-side input channel
        .net_si             (peso),
        .net_ri             (pero),
        .net_di             (pedo),

        // Router-side output channel
        .net_so             (pesi),
        .net_ro             (peri),
        .net_do             (pedi),

        // Router polarity
        .net_polarity       (polarity),

        // Phase 4 synthesis ports -- replaces hierarchical refs
        .net_input_buf_out  (nic_input_buf),
        .input_status_out   (nic_input_status),
        .output_status_out  (nic_output_status)
    );

    // ============================================================
    //  CPU instance
    // ============================================================
    cardinal_cpu u_cpu (
        .clk       (clk),
        .reset     (reset),
        .inst_in   (cpu_inst_in),
        .d_in      (cpu_d_in),
        .pc_out    (cpu_pc_out),
        .addr_out  (cpu_addr_out),
        .memEn     (cpu_memEn),
        .memWrEn   (cpu_memWrEn),
        .d_out     (cpu_d_out)
    );

    // ============================================================
    //  Combinational NIC read bypass (Section 2.4, Option 1)
    //  NOW USES PORT CONNECTIONS instead of hierarchical refs.
    //  Logic is bit-for-bit identical to Phase 3.
    // ============================================================
    reg [63:0] nic_comb_read;

    always @(*) begin
        case (nic_addr)
            2'b00: nic_comb_read = nic_input_buf;                  // NIC_IN
            2'b01: nic_comb_read = {63'h0, nic_input_status};      // NIC_IN_STATUS
            2'b10: nic_comb_read = 64'h0;                          // NIC_OUT (write-only)
            2'b11: nic_comb_read = {63'h0, nic_output_status};     // NIC_OUT_STATUS
            default: nic_comb_read = 64'h0;
        endcase
    end

    always @(*) begin
        if (nic_en && !nic_wrEn)
            cpu_d_in = nic_comb_read;   // combinational NIC bypass
        else
            cpu_d_in = dmem_d_out;      // default: DMEM read data
    end

endmodule
