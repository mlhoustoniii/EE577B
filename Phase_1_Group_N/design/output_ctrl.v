`timescale 1ns/1ps
// ============================================================
// output_ctrl.v
// Cardinal Router -- Output Channel Controller
//
// EE 577B -- Cardinal Router Project
//
// One instance per physical output port (N, S, E, W, PE).
// Each instance manages:
//   - Round-robin arbitration between 4 competing input_ctrls
//   - Two output VC buffers (even and odd)
//   - Header hop value right-shift before forwarding
//   - External handshaking (Mealy FSM for so)
//
// VC Multiplexing (per spec):
//   Even cycle (polarity=0):
//     WRITE -> even output buffer (from winning input, internal)
//     SEND  -> odd  output buffer externally (if full AND ro=1)
//   Odd cycle (polarity=1):
//     WRITE -> odd  output buffer (from winning input, internal)
//     SEND  -> even output buffer externally (if full AND ro=1)
//
// Header Hop Update (per spec):
//   Right-shift the active hop field by 1 before writing to buffer:
//     hopX[55:52]: shift if hopX[0]==1  (still in X dimension)
//     hopY[51:48]: shift if hopX[0]==0 AND hopY[0]==1 (in Y dim)
//     No shift:    hopX[0]==0 AND hopY[0]==0 (arrived at PE)
//   Unary encoding: 4'h7->4'h3->4'h1->4'h0 per hop
//
// so is Mealy: depends on buffer state AND ro input (no clock wait)
// This achieves the mandatory 2-cycle latency per hop:
//   Cycle N:   packet written into output buffer (internal)
//   Cycle N+1: packet sent out when ro asserted (external)
//
// Slot ordering set by gold_router instantiation to match
// the spec-required priority for each output port direction.
// ============================================================

module output_ctrl (
    input  wire        clk,
    input  wire        reset,
    input  wire        polarity,        // 0=even cycle, 1=odd cycle

    // ----------------------------------------------------------
    // Requests from 4 input_ctrls for THIS output port
    // Slot[0] = highest priority, Slot[3] = lowest priority
    // (ordering set by gold_router to match spec priority rules)
    // ----------------------------------------------------------
    input  wire [3:0]  request_even,    // Even VC requests (even cycles)
    input  wire [3:0]  request_odd,     // Odd  VC requests (odd  cycles)

    // ----------------------------------------------------------
    // Data buses from all 4 input_ctrls (always driven per spec)
    // Slot ordering MUST match request_even/odd slot ordering
    // ----------------------------------------------------------
    input  wire [63:0] di_even_0,       // Even VC data from slot 0 input
    input  wire [63:0] di_even_1,       // Even VC data from slot 1 input
    input  wire [63:0] di_even_2,       // Even VC data from slot 2 input
    input  wire [63:0] di_even_3,       // Even VC data from slot 3 input
    input  wire [63:0] di_odd_0,        // Odd  VC data from slot 0 input
    input  wire [63:0] di_odd_1,
    input  wire [63:0] di_odd_2,
    input  wire [63:0] di_odd_3,

    // ----------------------------------------------------------
    // Grant signals back to input_ctrls (one-hot)
    // ----------------------------------------------------------
    output wire [3:0]  grant_even,      // Which slot won even VC arbitration
    output wire [3:0]  grant_odd,       // Which slot won odd  VC arbitration

    // ----------------------------------------------------------
    // External handshake to downstream router or PE
    // so: Mealy -- depends on buffer full AND ro
    // ----------------------------------------------------------
    output wire        so,              // Send-out: data valid on channel
    input  wire        ro,              // Ready-out: downstream can accept
    output wire [63:0] do_ext           // Data driven onto external channel
);

    // ----------------------------------------------------------
    // Output buffer full/empty state flags
    //
    // even_out_full:
    //   SET   when: even cycle AND arbiter grants AND buffer empty
    //   CLEAR when: odd  cycle AND even_out_full AND ro
    //
    // odd_out_full:
    //   SET   when: odd  cycle AND arbiter grants AND buffer empty
    //   CLEAR when: even cycle AND odd_out_full  AND ro
    // ----------------------------------------------------------
    reg even_out_full;
    reg odd_out_full;

    // ----------------------------------------------------------
    // output_available: tells arbiter if current cycle's write
    // buffer is free.
    //   Even cycle -> writing even buffer -> check even_out_full
    //   Odd  cycle -> writing odd  buffer -> check odd_out_full
    // ----------------------------------------------------------
    wire output_available = (polarity == 1'b0) ? ~even_out_full
                                               : ~odd_out_full;

    // ----------------------------------------------------------
    // Select active requests for current polarity
    //   Even cycle -> arbitrate even VC requests
    //   Odd  cycle -> arbitrate odd  VC requests
    // ----------------------------------------------------------
    wire [3:0] active_request = (polarity == 1'b0) ? request_even
                                                    : request_odd;

    // ----------------------------------------------------------
    // Round-robin arbiter instantiation
    //
    // Single arbiter handles both VC types via polarity signal.
    // Internally maintains separate priority pointers per VC.
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

    // Route grant to correct VC output -- only one active per cycle
    assign grant_even = (polarity == 1'b0) ? arb_grant : 4'b0000;
    assign grant_odd  = (polarity == 1'b1) ? arb_grant : 4'b0000;

    // ----------------------------------------------------------
    // Data mux: select winning input_ctrl's data
    //
    // Polarity determines which VC buffer of the winner to read:
    //   Even cycle -> read even VC buffer of winner
    //   Odd  cycle -> read odd  VC buffer of winner
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
    // Hop right-shift header update (per spec)
    //
    // Before writing packet to output buffer, right-shift the
    // active hop field to decrement hop count by 1.
    //
    //   hopX = mux_data[55:52]  (4-bit unary)
    //   hopY = mux_data[51:48]  (4-bit unary)
    //
    // Unary right-shift: {1'b0, field[3:1]}
    //   4'h7 (0111) -> 4'h3 (0011) -> 4'h1 (0001) -> 4'h0 (0000)
    //
    // Rule:
    //   hopX[0]==1 -> shift hopX, hopY unchanged
    //   hopX[0]==0 AND hopY[0]==1 -> hopX unchanged, shift hopY
    //   both 0     -> arrived (no shift, write as-is to PE)
    //
    // All other header bits NEVER modified:
    //   [63]=VC, [62]=dirX, [61]=dirY, [60:56]=reserved,
    //   [47:40]=srcX, [39:32]=srcY, [31:0]=payload
    // ----------------------------------------------------------
    wire        mux_hopX_lsb = mux_data[52]; // LSB of hopX[55:52]
    wire        mux_hopY_lsb = mux_data[48]; // LSB of hopY[51:48]

    reg  [63:0] updated_packet;
    always @(*) begin
        // Default: copy entire packet unchanged
        updated_packet = mux_data;

        if (|arb_grant) begin // Only update when a grant was issued
            if (mux_hopX_lsb) begin
                // Still in X dimension -- right-shift hopX by 1
                // hopX[55:52] -> {0, hopX[55:53]}
                updated_packet[55:52] = {1'b0, mux_data[55:53]};
                // hopY[51:48] unchanged
            end
            else if (mux_hopY_lsb) begin
                // In Y dimension -- right-shift hopY by 1
                // hopY[51:48] -> {0, hopY[51:49]}
                updated_packet[51:48] = {1'b0, mux_data[51:49]};
                // hopX[55:52] stays 4'h0 (already exhausted)
            end
            // else: both 0 -> arrived, no modification
        end
    end

    // ----------------------------------------------------------
    // Write enables for output VC buffers
    //
    // Even output buffer written on even cycles (polarity=0)
    // Odd  output buffer written on odd  cycles (polarity=1)
    // Guard with ~full: arbiter checks output_available, but
    // explicit guard ensures no corner-case double-write.
    // ----------------------------------------------------------
    wire write_even_out = (|arb_grant) && (polarity == 1'b0) && ~even_out_full;
    wire write_odd_out  = (|arb_grant) && (polarity == 1'b1) && ~odd_out_full;

    // ----------------------------------------------------------
    // Output VC buffer instantiations
    //
    // Buffers receive updated_packet (hop-shifted data).
    // Outputs continuously driven (no read enable per spec).
    // ----------------------------------------------------------
    wire [63:0] even_out_data;
    wire [63:0] odd_out_data;

    vc_buffer even_out_buf (
        .clk      (clk),
        .reset    (reset),
        .write_en (write_even_out),
        .di       (updated_packet),
        .do       (even_out_data)
    );

    vc_buffer odd_out_buf (
        .clk      (clk),
        .reset    (reset),
        .write_en (write_odd_out),
        .di       (updated_packet),
        .do       (odd_out_data)
    );

    // ----------------------------------------------------------
    // Mealy FSM: so and do_ext
    //
    // External sending happens on OPPOSITE polarity to internal:
    //   Even cycle (polarity=0) -> send odd  output buffer
    //   Odd  cycle (polarity=1) -> send even output buffer
    //
    // so depends on BOTH buffer state AND ro -- Mealy property.
    // No clock edge required: responds combinationally to ro.
    // ----------------------------------------------------------
    assign so     = (polarity == 1'b0) ? (odd_out_full  && ro)
                                       : (even_out_full && ro);

    assign do_ext = (polarity == 1'b0) ? odd_out_data
                                       : even_out_data;

    // ----------------------------------------------------------
    // Sequential: update output buffer full/empty flags
    //
    // even_out_full:
    //   SET:   even cycle AND write granted AND buffer empty
    //   CLEAR: odd  cycle AND even buffer full AND ro accepted
    //
    // odd_out_full:
    //   SET:   odd  cycle AND write granted AND buffer empty
    //   CLEAR: even cycle AND odd  buffer full AND ro accepted
    //
    // Set and clear cannot conflict: set happens on write cycle,
    // clear happens on the opposite polarity cycle when sending.
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            // Per spec: all so=0 on reset
            // so is combinational, so clearing full flags -> so=0
            even_out_full <= 1'b0;
            odd_out_full  <= 1'b0;
        end
        else begin
            // Even output buffer state transitions
            if (write_even_out)
                even_out_full <= 1'b1;        // Packet written in
            else if ((polarity == 1'b1) && even_out_full && ro)
                even_out_full <= 1'b0;        // Odd cycle: sent externally

            // Odd output buffer state transitions
            if (write_odd_out)
                odd_out_full  <= 1'b1;
            else if ((polarity == 1'b0) && odd_out_full && ro)
                odd_out_full  <= 1'b0;        // Even cycle: sent externally
        end
    end

endmodule
