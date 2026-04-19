`timescale 1ns/1ps
// ============================================================
// cardinal_nic.v  (Phase 4 synthesis-ready revision)
//
// CHANGE FROM PHASE 3:
//   Three internal signals that cardinal_node.v previously
//   accessed via hierarchical references are now promoted to
//   proper output ports:
//
//     net_input_buf_out  [63:0]  -- exposed net_input_buf
//     input_status_out          -- exposed input_status
//     output_status_out         -- exposed output_status
//
//   This eliminates the cross-module hierarchical reference
//   (u_nic.net_input_buf etc.) that prevented synthesis.
//   All other logic is bit-for-bit identical to Phase 3.
//
//   Simulation backward-compatibility: the Phase 3 testbench
//   (tb_cardinal_nic.v) does not connect these new ports, so
//   they remain unconnected in simulation (legal in Verilog --
//   undriven outputs are simply ignored by the testbench).
// ============================================================

module cardinal_nic (
    input  wire        clk,
    input  wire        reset,

    // Processor Interface
    input  wire [1:0]  addr,
    input  wire [63:0] d_in,
    output reg  [63:0] d_out,
    input  wire        nicEn,
    input  wire        nicWrEn,

    // Network Input Channel (Router -> NIC -> Processor)
    input  wire        net_si,
    output wire        net_ri,
    input  wire [63:0] net_di,

    // Network Output Channel (Processor -> NIC -> Router)
    output wire        net_so,
    input  wire        net_ro,
    output wire [63:0] net_do,

    // Router polarity
    input  wire        net_polarity,

    // ----------------------------------------------------------
    // Phase 4 synthesis ports (NEW -- promoted from internal)
    // cardinal_node.v uses these instead of hierarchical refs
    // ----------------------------------------------------------
    output wire [63:0] net_input_buf_out,   // was u_nic.net_input_buf
    output wire        input_status_out,     // was u_nic.input_status
    output wire        output_status_out     // was u_nic.output_status
);

    // Internal registers (unchanged from Phase 3)
    reg [63:0] net_input_buf;
    reg [63:0] net_output_buf;
    reg        input_status;
    reg        output_status;

    // Expose internal state via new output ports
    assign net_input_buf_out  = net_input_buf;
    assign input_status_out   = input_status;
    assign output_status_out  = output_status;

    // Network Input Channel Control (unchanged)
    assign net_ri = ~input_status;

    // Network Output Channel Control (unchanged)
    assign net_so  = output_status
                   && net_ro
                   && (net_polarity == net_output_buf[63]);
    assign net_do  = net_output_buf;

    // Main Sequential Logic (bit-for-bit identical to Phase 3)
    always @(posedge clk) begin
        if (reset) begin
            net_input_buf  <= 64'h0;
            net_output_buf <= 64'h0;
            input_status   <= 1'b0;
            output_status  <= 1'b0;
            d_out          <= 64'h0;
        end else begin
            // Network Input: latch incoming packet
            if (net_si && !input_status) begin
                net_input_buf <= net_di;
                input_status  <= 1'b1;
            end
            // Network Input: clear on processor read
            if (nicEn && !nicWrEn && addr == 2'b00) begin
                input_status <= 1'b0;
            end

            // Network Output: write from processor
            if (nicEn && nicWrEn && addr == 2'b10 && !output_status) begin
                net_output_buf <= d_in;
                output_status  <= 1'b1;
            end
            // Network Output: clear after router accepts
            if (net_so) begin
                output_status <= 1'b0;
            end

            // Processor read path (registered d_out -- kept for
            // simulation correctness; cardinal_node bypasses this
            // with the combinational mux using the new ports above)
            if (nicEn && !nicWrEn) begin
                case (addr)
                    2'b00: d_out <= net_input_buf;
                    2'b01: d_out <= {63'h0, input_status};
                    2'b10: d_out <= 64'h0;
                    2'b11: d_out <= {63'h0, output_status};
                    default: d_out <= 64'h0;
                endcase
            end else begin
                d_out <= 64'h0;
            end
        end
    end

endmodule
