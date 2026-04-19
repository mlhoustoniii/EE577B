`timescale 1ns/1ps
// ============================================================
// input_ctrl_torus.v
// Cardinal Router -- Input Channel Controller (Torus)
//
// EE 577B -- Cardinal Router Project
// VARIANT: torus  (XY routing on 4x4 torus with wrap-around)
//
// Differences from input_ctrl_xystd.v (standard mesh):
//   1. Routing uses MODULAR distance instead of absolute distance
//   2. dx_mod = (dst_x - ROUTER_X) mod 4  (2-bit subtraction)
//      dy_mod = (dst_y - ROUTER_Y) mod 4
//   3. dx_mod==3 -> go West  (1 wrap hop, shorter than 3 East hops)
//      dx_mod==1,2 -> go East (forward)
//      dy_mod==3 -> go South (1 wrap hop, shorter than 3 North hops)
//      dy_mod==1,2 -> go North (forward)
//
// Torus topology: 4x4 grid where edge nodes are connected:
//   (x=0).West <-> (x=3).East  (horizontal wrap)
//   (y=0).South <-> (y=3).North (vertical wrap)
//
// Max hops in torus:  2 (any src->dst)
// Max hops in mesh:   6 (corner to corner)
// This reduces worst-case latency by 3x.
//
// Packet Header Format (64-bit, xystd/torus shared):
//   [63]    = VC polarity (router ignores)
//   [62:56] = Reserved (7 bits, always 0)
//   [55:48] = dst_x  (8-bit destination X)
//   [47:40] = dst_y  (8-bit destination Y)
//   [39:32] = src_x  (8-bit source X)
//   [31:24] = src_y  (8-bit source Y)
//   [23:0]  = Payload (24-bit)
//
// VC multiplexing, ri, request/grant: IDENTICAL to input_ctrl_xystd.v
// ============================================================

module input_ctrl_torus #(
    parameter [7:0] ROUTER_X = 8'd0,
    parameter [7:0] ROUTER_Y = 8'd0
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        polarity,

    input  wire        si,
    output wire        ri,
    input  wire [63:0] di,

    // 5-bit one-hot request: [0]=North [1]=South [2]=East [3]=West [4]=PE
    output wire [4:0]  request_even,
    output wire [4:0]  request_odd,

    input  wire        grant_even,
    input  wire        grant_odd,

    output wire [63:0] do_even,
    output wire [63:0] do_odd
);

    // ----------------------------------------------------------
    // Buffer state
    // ----------------------------------------------------------
    reg even_full;
    reg odd_full;

    // ----------------------------------------------------------
    // Write enables (polarity crossover)
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
    // Destination coordinate extraction
    // (shared xystd/torus packet format)
    // ----------------------------------------------------------
    wire [7:0] even_dst_x = do_even[55:48];
    wire [7:0] even_dst_y = do_even[47:40];
    wire [7:0] odd_dst_x  = do_odd[55:48];
    wire [7:0] odd_dst_y  = do_odd[47:40];

    // ----------------------------------------------------------
    // Torus Modular Distance Computation
    //
    // 2-bit subtraction wraps naturally mod 4 for a 4x4 grid.
    // Coordinates are always 0-3, so only 2 LSBs matter.
    //
    // dx_mod encoding:
    //   2'b00 (0): same column -- X routing done
    //   2'b01 (1): 1 hop East (vs 3 West)  -> East
    //   2'b10 (2): 2 hops either way (tie) -> East
    //   2'b11 (3): 3 hops East = 1 hop West wrap -> West
    //
    // dy_mod encoding:
    //   2'b00 (0): same row -- Y routing done -> PE
    //   2'b01 (1): 1 hop North              -> North
    //   2'b10 (2): 2 hops either way (tie)  -> North
    //   2'b11 (3): 3 hops North = 1 hop South wrap -> South
    // ----------------------------------------------------------
    wire [1:0] even_dx_mod = even_dst_x[1:0] - ROUTER_X[1:0]; // 2-bit mod 4
    wire [1:0] even_dy_mod = even_dst_y[1:0] - ROUTER_Y[1:0];

    wire [1:0] odd_dx_mod  = odd_dst_x[1:0]  - ROUTER_X[1:0];
    wire [1:0] odd_dy_mod  = odd_dst_y[1:0]  - ROUTER_Y[1:0];

    // ----------------------------------------------------------
    // Torus XY Routing -- Even VC buffer
    //
    // Priority: X dimension first (East/West), then Y (North/South)
    // ----------------------------------------------------------
    reg [4:0] route_even;
    always @(*) begin
        if (even_dx_mod != 2'b00) begin
            // X not done -- route in X dimension
            if (even_dx_mod == 2'b11)
                route_even = 5'b01000; // West wrap (bit 3) -- 1 hop wrap < 3 forward
            else
                route_even = 5'b00100; // East      (bit 2) -- dx_mod = 1 or 2
        end
        else begin
            // X done -- route in Y dimension
            if (even_dy_mod == 2'b00)
                route_even = 5'b10000; // PE        (bit 4) -- arrived
            else if (even_dy_mod == 2'b11)
                route_even = 5'b00010; // South wrap (bit 1) -- 1 hop wrap < 3 forward
            else
                route_even = 5'b00001; // North      (bit 0) -- dy_mod = 1 or 2
        end
    end

    // ----------------------------------------------------------
    // Torus XY Routing -- Odd VC buffer
    // ----------------------------------------------------------
    reg [4:0] route_odd;
    always @(*) begin
        if (odd_dx_mod != 2'b00) begin
            if (odd_dx_mod == 2'b11)
                route_odd = 5'b01000; // West wrap
            else
                route_odd = 5'b00100; // East
        end
        else begin
            if (odd_dy_mod == 2'b00)
                route_odd = 5'b10000; // PE
            else if (odd_dy_mod == 2'b11)
                route_odd = 5'b00010; // South wrap
            else
                route_odd = 5'b00001; // North
        end
    end

    // ----------------------------------------------------------
    // Request outputs
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
            if (write_en_even)       even_full <= 1'b1;
            else if (grant_even)     even_full <= 1'b0;

            if (write_en_odd)        odd_full  <= 1'b1;
            else if (grant_odd)      odd_full  <= 1'b0;
        end
    end

    // ----------------------------------------------------------
    // ri -- Ready-In (Moore output)
    // ----------------------------------------------------------
    assign ri = (polarity == 1'b0) ? ~odd_full : ~even_full;

endmodule
