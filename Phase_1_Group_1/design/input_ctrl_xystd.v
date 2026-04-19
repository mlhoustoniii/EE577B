`timescale 1ns/1ps
// ============================================================
// input_ctrl_xystd.v
// Cardinal Router -- Input Channel Controller (Standard XY)
//
// EE 577B -- Cardinal Router Project
// VARIANT: xystd  (Standard XY address-comparison routing)
//
// Differences from input_ctrl.v (hop-based):
//   1. Packet header carries dst_x/dst_y instead of hopX/hopY/dir
//   2. Routing decision: compare dst coords to THIS router's coords
//   3. No hop decrement (that lives in output_ctrl for hop version;
//      xystd output_ctrl passes packet UNCHANGED)
//   4. Router coordinates passed as parameters ROUTER_X, ROUTER_Y
//
// New Packet Header Format (64-bit, xystd):
//   [63]    = VC polarity (router ignores)
//   [62:56] = Reserved (7 bits, set to 0)
//   [55:48] = dst_x (8-bit destination X coordinate)
//   [47:40] = dst_y (8-bit destination Y coordinate)
//   [39:32] = src_x (8-bit source X coordinate)
//   [31:24] = src_y (8-bit source Y coordinate)
//   [23:0]  = Payload (24-bit)
//
// Routing Logic (XY dimension-order, coordinate-comparison):
//   Step 1: dst_x > ROUTER_X  -> East  [bit 2]
//   Step 2: dst_x < ROUTER_X  -> West  [bit 3]
//   Step 3: dst_y > ROUTER_Y  -> North [bit 0]  (after X done)
//   Step 4: dst_y < ROUTER_Y  -> South [bit 1]  (after X done)
//   Step 5: dst_x==ROUTER_X AND dst_y==ROUTER_Y -> PE [bit 4]
//
// VC Multiplexing, ri, request/grant logic:
//   IDENTICAL to input_ctrl.v -- no changes needed.
// ============================================================

module input_ctrl_xystd #(
    parameter [7:0] ROUTER_X = 8'd0,   // This router's X coordinate
    parameter [7:0] ROUTER_Y = 8'd0    // This router's Y coordinate
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        polarity,        // 0=even cycle, 1=odd cycle

    // External handshake
    input  wire        si,
    output wire        ri,
    input  wire [63:0] di,

    // Requests to output controllers (5-bit one-hot)
    // [0]=North [1]=South [2]=East [3]=West [4]=PE
    output wire [4:0]  request_even,
    output wire [4:0]  request_odd,

    // Grants from output controllers
    input  wire        grant_even,
    input  wire        grant_odd,

    // Data to crossbar MUX
    output wire [63:0] do_even,
    output wire [63:0] do_odd
);

    // ----------------------------------------------------------
    // Buffer full/empty state registers
    // ----------------------------------------------------------
    reg even_full;
    reg odd_full;

    // ----------------------------------------------------------
    // Write enables (polarity crossover -- per spec)
    // Even cycle (pol=0): external VC = odd  -> write odd  buffer
    // Odd  cycle (pol=1): external VC = even -> write even buffer
    // ----------------------------------------------------------
    wire write_en_even = si && (polarity == 1'b1) && ~even_full;
    wire write_en_odd  = si && (polarity == 1'b0) && ~odd_full;

    // ----------------------------------------------------------
    // VC Buffer instances
    // ----------------------------------------------------------
    vc_buffer even_buf (
        .clk      (clk),
        .reset    (reset),
        .write_en (write_en_even),
        .di       (di),
        .do       (do_even)
    );

    vc_buffer odd_buf (
        .clk      (clk),
        .reset    (reset),
        .write_en (write_en_odd),
        .di       (di),
        .do       (do_odd)
    );

    // ----------------------------------------------------------
    // Destination coordinate extraction from packet headers
    //
    // xystd format:
    //   dst_x = pkt[55:48]
    //   dst_y = pkt[47:40]
    // ----------------------------------------------------------
    wire [7:0] even_dst_x = do_even[55:48];
    wire [7:0] even_dst_y = do_even[47:40];

    wire [7:0] odd_dst_x  = do_odd[55:48];
    wire [7:0] odd_dst_y  = do_odd[47:40];

    // ----------------------------------------------------------
    // Standard XY Routing decode -- Even VC buffer
    //
    // Priority: X dimension first (East/West), then Y (North/South)
    //   dst_x > ROUTER_X -> East  (bit 2)
    //   dst_x < ROUTER_X -> West  (bit 3)
    //   dst_x == ROUTER_X AND dst_y > ROUTER_Y -> North (bit 0)
    //   dst_x == ROUTER_X AND dst_y < ROUTER_Y -> South (bit 1)
    //   dst_x == ROUTER_X AND dst_y == ROUTER_Y -> PE   (bit 4)
    //
    // Unsigned comparison: coordinates are 8-bit unsigned
    // ----------------------------------------------------------
    reg [4:0] route_even;
    always @(*) begin
        if (even_dst_x > ROUTER_X)
            route_even = 5'b00100;      // East  (bit 2)
        else if (even_dst_x < ROUTER_X)
            route_even = 5'b01000;      // West  (bit 3)
        else if (even_dst_y > ROUTER_Y)
            route_even = 5'b00001;      // North (bit 0)
        else if (even_dst_y < ROUTER_Y)
            route_even = 5'b00010;      // South (bit 1)
        else
            route_even = 5'b10000;      // PE    (bit 4) -- arrived
    end

    // ----------------------------------------------------------
    // Standard XY Routing decode -- Odd VC buffer
    // ----------------------------------------------------------
    reg [4:0] route_odd;
    always @(*) begin
        if (odd_dst_x > ROUTER_X)
            route_odd = 5'b00100;       // East
        else if (odd_dst_x < ROUTER_X)
            route_odd = 5'b01000;       // West
        else if (odd_dst_y > ROUTER_Y)
            route_odd = 5'b00001;       // North
        else if (odd_dst_y < ROUTER_Y)
            route_odd = 5'b00010;       // South
        else
            route_odd = 5'b10000;       // PE
    end

    // ----------------------------------------------------------
    // Request outputs -- only assert on correct polarity cycle
    // and only when buffer is full (valid packet present)
    // ----------------------------------------------------------
    assign request_even = (even_full && (polarity == 1'b0)) ? route_even
                                                             : 5'b00000;
    assign request_odd  = (odd_full  && (polarity == 1'b1)) ? route_odd
                                                             : 5'b00000;

    // ----------------------------------------------------------
    // Moore FSM -- update full/empty flags
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            even_full <= 1'b0;
            odd_full  <= 1'b0;
        end
        else begin
            if (write_en_even)        even_full <= 1'b1;
            else if (grant_even)      even_full <= 1'b0;

            if (write_en_odd)         odd_full  <= 1'b1;
            else if (grant_odd)       odd_full  <= 1'b0;
        end
    end

    // ----------------------------------------------------------
    // ri -- Ready-In (Moore output, reflects external VC status)
    // Even cycle -> external VC = odd  -> ~odd_full
    // Odd  cycle -> external VC = even -> ~even_full
    // ----------------------------------------------------------
    assign ri = (polarity == 1'b0) ? ~odd_full : ~even_full;

endmodule
