`timescale 1ns/1ps
// ============================================================
// output_ctrl_xystd.v
// Cardinal Router -- Output Channel Controller (Standard XY)
//
// EE 577B -- Cardinal Router Project
// VARIANT: xystd  (Standard XY address-comparison routing)
//
// Differences from output_ctrl.v (hop-based):
//   ONLY ONE CHANGE: hop right-shift removed.
//   Packet is written to output buffer UNCHANGED.
//   The xystd router needs no hop decrement because routing
//   decisions are made by comparing dst coords at each hop --
//   the packet header never needs modification.
//
// Everything else is IDENTICAL to output_ctrl.v:
//   - Round-robin arbitration (rr_arbiter)
//   - Two output VC buffers (even/odd)
//   - VC multiplexing (write internal, send external)
//   - Mealy FSM for so (depends on buffer state AND ro)
//   - 2-cycle latency per hop preserved
// ============================================================

module output_ctrl_xystd (
    input  wire        clk,
    input  wire        reset,
    input  wire        polarity,

    input  wire [3:0]  request_even,
    input  wire [3:0]  request_odd,

    input  wire [63:0] di_even_0,
    input  wire [63:0] di_even_1,
    input  wire [63:0] di_even_2,
    input  wire [63:0] di_even_3,
    input  wire [63:0] di_odd_0,
    input  wire [63:0] di_odd_1,
    input  wire [63:0] di_odd_2,
    input  wire [63:0] di_odd_3,

    output wire [3:0]  grant_even,
    output wire [3:0]  grant_odd,

    output wire        so,
    input  wire        ro,
    output wire [63:0] do_ext
);

    // ----------------------------------------------------------
    // Output buffer full/empty flags
    // ----------------------------------------------------------
    reg even_out_full;
    reg odd_out_full;

    // ----------------------------------------------------------
    // output_available: is this cycle's write buffer free?
    // ----------------------------------------------------------
    wire output_available = (polarity == 1'b0) ? ~even_out_full
                                               : ~odd_out_full;

    // ----------------------------------------------------------
    // Select active requests for current polarity
    // ----------------------------------------------------------
    wire [3:0] active_request = (polarity == 1'b0) ? request_even
                                                    : request_odd;

    // ----------------------------------------------------------
    // Round-robin arbiter
    // ----------------------------------------------------------
    wire [3:0] arb_grant;

    rr_arbiter arb (
        .clk              (clk),
        .reset            (reset),
        .polarity         (polarity),
        .request          (active_request),
        .output_available (output_available),
        .grant            (arb_grant)
    );

    assign grant_even = (polarity == 1'b0) ? arb_grant : 4'b0000;
    assign grant_odd  = (polarity == 1'b1) ? arb_grant : 4'b0000;

    // ----------------------------------------------------------
    // Data mux: select winning input_ctrl's data
    // ----------------------------------------------------------
    reg [63:0] mux_data;
    always @(*) begin
        case (arb_grant)
            4'b0001: mux_data = (polarity==1'b0) ? di_even_0 : di_odd_0;
            4'b0010: mux_data = (polarity==1'b0) ? di_even_1 : di_odd_1;
            4'b0100: mux_data = (polarity==1'b0) ? di_even_2 : di_odd_2;
            4'b1000: mux_data = (polarity==1'b0) ? di_even_3 : di_odd_3;
            default: mux_data = 64'b0;
        endcase
    end

    // ----------------------------------------------------------
    // xystd: packet passes through UNCHANGED (no hop shift)
    //
    // In hop-based output_ctrl, this is where hopX/hopY are
    // right-shifted by 1 before writing to the output buffer.
    // In xystd, the routing decision is made fresh at each router
    // by comparing dst_x/dst_y to the router's own coordinates --
    // the packet header never needs modification.
    // ----------------------------------------------------------
    wire [63:0] forwarded_packet = mux_data;   // straight pass-through

    // ----------------------------------------------------------
    // Write enables for output VC buffers
    // ----------------------------------------------------------
    wire write_even_out = (|arb_grant) && (polarity == 1'b0) && ~even_out_full;
    wire write_odd_out  = (|arb_grant) && (polarity == 1'b1) && ~odd_out_full;

    // ----------------------------------------------------------
    // Output VC buffer instances
    // ----------------------------------------------------------
    wire [63:0] even_out_data;
    wire [63:0] odd_out_data;

    vc_buffer even_out_buf (
        .clk      (clk),
        .reset    (reset),
        .write_en (write_even_out),
        .di       (forwarded_packet),
        .do       (even_out_data)
    );

    vc_buffer odd_out_buf (
        .clk      (clk),
        .reset    (reset),
        .write_en (write_odd_out),
        .di       (forwarded_packet),
        .do       (odd_out_data)
    );

    // ----------------------------------------------------------
    // Mealy FSM: so and do_ext
    // Even cycle -> send odd  output buffer externally
    // Odd  cycle -> send even output buffer externally
    // ----------------------------------------------------------
    assign so     = (polarity == 1'b0) ? (odd_out_full  && ro)
                                       : (even_out_full && ro);

    assign do_ext = (polarity == 1'b0) ? odd_out_data
                                       : even_out_data;

    // ----------------------------------------------------------
    // Sequential: update output buffer full/empty flags
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            even_out_full <= 1'b0;
            odd_out_full  <= 1'b0;
        end
        else begin
            if (write_even_out)
                even_out_full <= 1'b1;
            else if ((polarity == 1'b1) && even_out_full && ro)
                even_out_full <= 1'b0;

            if (write_odd_out)
                odd_out_full  <= 1'b1;
            else if ((polarity == 1'b0) && odd_out_full && ro)
                odd_out_full  <= 1'b0;
        end
    end

endmodule
