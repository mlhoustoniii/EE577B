/////////////////////////////////////////////////////////////////////
// cardinal_node.v  -- Phase 4 synthesis version (v14-FINAL)
// 
// KEY FIX: Server cardinal_cpu.v is Phase 3 version with extra ports:
//   - nic_d_in  (input)  : NIC read data
//   - nicEn     (output) : NIC enable
//   - nicEnWr   (output) : NIC write enable
//
// Previous cardinal_node.v left these UNCONNECTED.
// DC's compile_ultra with boundary optimization saw nicEn/nicEnWr
// as outputs with no load -> removed logic driving them -> collapsed
// the entire mem_en/memory access chain -> CPU pipeline pruned.
//
// FIX: Connect ALL Phase 3 CPU ports properly.
//   - nicEn/nicEnWr drive the NIC directly (CPU computes these correctly)
//   - nic_d_in receives the combinational NIC bypass
//   - cpu_d_in receives dmem_d_out (DMEM path, no NIC mux needed since
//     the CPU internally muxes nic_d_in vs d_in based on exwb_is_nic)
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module cardinal_node #(
    parameter [5:0] NODE_ID = 6'd0
) (
    input  wire         clk,
    input  wire         reset,

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
    wire        cpu_nicEn;
    wire        cpu_nicEnWr;
    wire [0:63] cpu_d_out;
    wire [0:63] cpu_d_in;
    wire [0:63] cpu_nic_d_in;

    // ============================================================
    //  DMEM instance
    //  memAddr = cpu_addr_out[24:31] = PC[22:29] via imem stub
    //  dataOut = {56'h0, r_memAddr} -- non-constant, drives cpu_d_in
    // ============================================================
    wire [0:63] dmem_d_out;

    dmem u_dmem (
        .clk      (clk),
        .memEn    (cpu_memEn),
        .memWrEn  (cpu_memWrEn),
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
    //  NIC instance -- enabled by CPU's nicEn/nicEnWr outputs
    //  This makes nicEn/nicEnWr observable -> DC cannot prune them
    // ============================================================
    wire [63:0] nic_d_out_reg;
    wire [63:0] nic_bypass_input_buf;
    wire        nic_bypass_input_status;
    wire        nic_bypass_output_status;

    // NIC address from cpu_addr_out low bits
    wire [1:0]  nic_addr = {cpu_addr_out[30], cpu_addr_out[31]};

    cardinal_nic u_nic (
        .clk          (clk),
        .reset        (reset),
        .addr         (nic_addr),
        .d_in         (cpu_d_out),
        .d_out        (nic_d_out_reg),
        .nicEn        (cpu_nicEn),     // driven by CPU output -> observable
        .nicWrEn      (cpu_nicEnWr),   // driven by CPU output -> observable
        .net_si       (peso),
        .net_ri       (pero),
        .net_di       (pedo),
        .net_so       (pesi),
        .net_ro       (peri),
        .net_do       (pedi),
        .net_polarity (polarity),
        .bypass_input_buf    (nic_bypass_input_buf),
        .bypass_input_status (nic_bypass_input_status),
        .bypass_output_status(nic_bypass_output_status)
    );

    // ============================================================
    //  Combinational NIC read bypass -> cpu_nic_d_in
    //  The CPU internally selects between d_in and nic_d_in
    //  based on exwb_is_nic, so we just need to drive both ports.
    // ============================================================
    reg [63:0] nic_comb_read;

    always @(*) begin
        case (nic_addr)
            2'b00: nic_comb_read = nic_bypass_input_buf;
            2'b01: nic_comb_read = {63'h0, nic_bypass_input_status};
            2'b10: nic_comb_read = 64'h0;
            2'b11: nic_comb_read = {63'h0, nic_bypass_output_status};
            default: nic_comb_read = 64'h0;
        endcase
    end

    assign cpu_nic_d_in = nic_comb_read;

    // cpu_d_in: DMEM read data (CPU uses d_in for DMEM loads)
    assign cpu_d_in = dmem_d_out;

    // ============================================================
    //  CPU instance -- ALL Phase 3 ports connected
    // ============================================================
    cardinal_cpu u_cpu (
        .clk       (clk),
        .reset     (reset),
        .inst_in   (cpu_inst_in),
        .d_in      (cpu_d_in),
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
