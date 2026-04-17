`timescale 1ns/1ps
// ============================================================
// input_ctrl.v
// Cardinal Router -- Input Channel Controller
//
// EE 577B -- Cardinal Router Project
//
// One instance per physical input port (N, S, E, W, PE).
// Contains two vc_buffer instances: one even VC, one odd VC.
//
// Responsibilities:
//   1. Receive incoming packet into correct VC buffer
//   2. Decode routing header using XY dimension-order routing
//   3. Assert request to correct output controller
//   4. Drive ri (Moore FSM output -- reflects buffer availability)
//
// Header Format (64-bit):
//   [63]     = VC polarity (router ignores -- uses internal polarity)
//   [62]     = dirX: 0=East, 1=West
//   [61]     = dirY: 0=South, 1=North
//   [60:56]  = Reserved (5 bits)
//   [55:52]  = hopX (4-bit unary: remaining X hops)
//   [51:48]  = hopY (4-bit unary: remaining Y hops)
//   [47:40]  = Source X (8-bit)
//   [39:32]  = Source Y (8-bit)
//   [31:0]   = Payload (32-bit)
//
// Routing Logic (XY dimension-order, header-driven):
//   Step 1: hopX[0]==1  -> still in X dimension
//             dirX=0 -> East  [bit 2]
//             dirX=1 -> West  [bit 3]
//   Step 2: hopX[0]==0 AND hopY[0]==1 -> X done, in Y dimension
//             dirY=0 -> South [bit 1]
//             dirY=1 -> North [bit 0]
//   Step 3: hopX[0]==0 AND hopY[0]==0 -> arrived -> PE [bit 4]
//
// No ROUTER_X/ROUTER_Y parameters needed.
// Routing is purely header-driven -- no coordinate comparison.
//
// VC Multiplexing (per spec):
//   Even cycle (polarity=0):
//     External = odd  VC -> write odd  buffer (if si asserted)
//     Internal = even VC -> assert request_even (if even buffer full)
//   Odd cycle (polarity=1):
//     External = even VC -> write even buffer (if si asserted)
//     Internal = odd  VC -> assert request_odd  (if odd buffer full)
//
// ri (Moore FSM output):
//   Even cycle -> ri reflects ~odd_full  (odd  is active external VC)
//   Odd  cycle -> ri reflects ~even_full (even is active external VC)
//   ri=1 means "buffer empty -- you may send"
//   ri=0 means "buffer full  -- do not send"
//
// Request bit encoding: [0]=North [1]=South [2]=East [3]=West [4]=PE
// ============================================================

module input_ctrl (
    input  wire        clk,
    input  wire        reset,
    input  wire        polarity,       // Router internal polarity (0=even, 1=odd)

    // ----------------------------------------------------------
    // External handshake (from upstream router or PE)
    // ----------------------------------------------------------
    input  wire        si,             // Send-in: upstream has valid data
    output wire        ri,             // Ready-in: our buffer is empty (Moore)
    input  wire [63:0] di,             // 64-bit incoming packet data

    // ----------------------------------------------------------
    // Request signals to output controllers
    // 5-bit one-hot: [0]=North [1]=South [2]=East [3]=West [4]=PE
    // request_even active on even cycles (internal even VC action)
    // request_odd  active on odd  cycles (internal odd  VC action)
    // ----------------------------------------------------------
    output wire [4:0]  request_even,
    output wire [4:0]  request_odd,

    // ----------------------------------------------------------
    // Grant signals back from output controllers
    // 1 = this input's packet was accepted by the output this cycle
    // ----------------------------------------------------------
    input  wire        grant_even,
    input  wire        grant_odd,

    // ----------------------------------------------------------
    // Data outputs to crossbar MUX in output controllers
    // Always driven (no read enable -- per spec)
    // ----------------------------------------------------------
    output wire [63:0] do_even,        // Even VC buffer contents
    output wire [63:0] do_odd          // Odd  VC buffer contents
);

    // ----------------------------------------------------------
    // Moore state: one full/empty flag per VC buffer
    // These are the single source of truth for all control logic.
    // ----------------------------------------------------------
    reg even_full;
    reg odd_full;

    // ----------------------------------------------------------
    // Write enable logic
    //
    // Polarity crossover (per spec):
    //   Even cycle (polarity=0) -> external uses odd  VC -> write odd  buffer
    //   Odd  cycle (polarity=1) -> external uses even VC -> write even buffer
    //
    // Guard with ~full: never overwrite a packet already in buffer.
    // ----------------------------------------------------------
    wire write_en_even = si && (polarity == 1'b1) && ~even_full;
    wire write_en_odd  = si && (polarity == 1'b0) && ~odd_full;

    // ----------------------------------------------------------
    // VC buffer instantiations
    //
    // vc_buffer: 64-bit synchronous write register
    //   write_en -> write on posedge clk
    //   do       -> continuously driven (no read enable needed)
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
    // Header field extraction -- Even VC buffer
    //
    // dirX [62]:    0=East, 1=West
    // dirY [61]:    0=South, 1=North
    // hopX [55:52]: 4-bit unary remaining X hops
    // hopY [51:48]: 4-bit unary remaining Y hops
    //
    // Routing uses only LSB of each hop field:
    //   hopX LSB = do_even[52]
    //   hopY LSB = do_even[48]
    // ----------------------------------------------------------
    wire       even_dirX     = do_even[62];
    wire       even_dirY     = do_even[61];
    wire       even_hopX_lsb = do_even[52]; // LSB of hopX[55:52]
    wire       even_hopY_lsb = do_even[48]; // LSB of hopY[51:48]

    // ----------------------------------------------------------
    // Header field extraction -- Odd VC buffer
    // ----------------------------------------------------------
    wire       odd_dirX     = do_odd[62];
    wire       odd_dirY     = do_odd[61];
    wire       odd_hopX_lsb = do_odd[52];
    wire       odd_hopY_lsb = do_odd[48];

    // ----------------------------------------------------------
    // XY Routing decode -- Even VC buffer (combinational)
    //
    // Step 1: hopX LSB=1 -> still traversing X dimension
    //           dirX=0 -> East [2], dirX=1 -> West [3]
    // Step 2: hopX LSB=0, hopY LSB=1 -> traversing Y dimension
    //           dirY=0 -> South [1], dirY=1 -> North [0]
    // Step 3: both LSBs=0 -> arrived at destination -> PE [4]
    // ----------------------------------------------------------
    reg [4:0] route_even;
    always @(*) begin
        if (even_hopX_lsb) begin
            // X dimension not yet complete -- route East or West
            if (!even_dirX)
                route_even = 5'b00100; // East  (bit 2)
            else
                route_even = 5'b01000; // West  (bit 3)
        end
        else if (even_hopY_lsb) begin
            // X complete, Y dimension not yet done -- route N or S
            if (!even_dirY)
                route_even = 5'b00010; // South (bit 1)
            else
                route_even = 5'b00001; // North (bit 0)
        end
        else begin
            // Both X and Y hops exhausted -- packet arrived
            route_even = 5'b10000; // PE (bit 4)
        end
    end

    // ----------------------------------------------------------
    // XY Routing decode -- Odd VC buffer (same logic, odd data)
    // ----------------------------------------------------------
    reg [4:0] route_odd;
    always @(*) begin
        if (odd_hopX_lsb) begin
            if (!odd_dirX)
                route_odd = 5'b00100; // East
            else
                route_odd = 5'b01000; // West
        end
        else if (odd_hopY_lsb) begin
            if (!odd_dirY)
                route_odd = 5'b00010; // South
            else
                route_odd = 5'b00001; // North
        end
        else begin
            route_odd = 5'b10000;     // PE
        end
    end

    // ----------------------------------------------------------
    // Request outputs to output controllers
    //
    // Only assert when:
    //   1. Buffer is full (valid packet present)
    //   2. Correct polarity cycle for internal action:
    //      Even buffer -> internal action on EVEN cycles (polarity=0)
    //      Odd  buffer -> internal action on ODD  cycles (polarity=1)
    // ----------------------------------------------------------
    assign request_even = (even_full && (polarity == 1'b0)) ? route_even
                                                             : 5'b00000;
    assign request_odd  = (odd_full  && (polarity == 1'b1)) ? route_odd
                                                             : 5'b00000;

    // ----------------------------------------------------------
    // Moore State Machine -- update full/empty flags on clock edge
    //
    // Write and grant cannot both be true simultaneously:
    //   write_en_even requires ~even_full
    //   grant_even    requires  even_full (only granted if full)
    // Safe to use separate if branches (no priority conflict).
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            even_full <= 1'b0;  // All buffers empty on reset
            odd_full  <= 1'b0;
        end
        else begin
            // Even VC buffer state transitions
            if (write_en_even)
                even_full <= 1'b1;        // Packet written in -> full
            else if (grant_even)
                even_full <= 1'b0;        // Packet forwarded out -> empty

            // Odd VC buffer state transitions
            if (write_en_odd)
                odd_full  <= 1'b1;
            else if (grant_odd)
                odd_full  <= 1'b0;
        end
    end

    // ----------------------------------------------------------
    // ri -- Ready-In signal (Moore FSM output)
    //
    // Purely reflects buffer status for the EXTERNAL-active VC:
    //   Even cycle (polarity=0) -> external VC is odd  -> ~odd_full
    //   Odd  cycle (polarity=1) -> external VC is even -> ~even_full
    //
    // Moore: output depends ONLY on state (full flags), not inputs.
    // ----------------------------------------------------------
    assign ri = (polarity == 1'b0) ? ~odd_full : ~even_full;

endmodule
