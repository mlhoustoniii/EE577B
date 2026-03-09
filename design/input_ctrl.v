`timescale 1ns/1ps

module input_ctrl #(
    parameter ROUTER_X = 0,   // This router's X coordinate in the 3x3 mesh
    parameter ROUTER_Y = 0    // This router's Y coordinate in the 3x3 mesh
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        polarity,       // Current clock cycle polarity (0=even, 1=odd)

    // ---------------------------------------------------------------
    // External handshake (from upstream router or PE)
    input  wire        si,             // Send-in from upstream
    output wire        ri,             // Ready-in to upstream (Moore SM output)
    input  wire [63:0] din,             // 64-bit packet data in

    // ---------------------------------------------------------------
    // Request signals to output controllers
    // Port encoding: [0]=North [1]=South [2]=East [3]=West [4]=PE
    // Even VC requests only active on even polarity cycles (internal)
    // Odd  VC requests only active on odd  polarity cycles (internal)
    output wire [4:0]  request_even,
    output wire [4:0]  request_odd,

    // ---------------------------------------------------------------
    // Grant signals back from output controllers
    input  wire        grant_even,
    input  wire        grant_odd,

    // Data outputs
    output wire [63:0] dout_even,
    output wire [63:0] dout_odd
);

    // latched full/empty flags for Moore FSM convention
    reg even_full;
    reg odd_full;

    // External data is ODD  VC on EVEN cycles (polarity=0)
    // External data is EVEN VC on ODD  cycles (polarity=1)
    // Only write if the corresponding buffer is empty
    wire pkt_vc        = din[63];
    wire write_en_even = si && (pkt_vc == 1'b0) && ~even_full;
    wire write_en_odd  = si && (pkt_vc == 1'b1) && ~odd_full;

    // Instantiate two VC buffers — one per virtual channel type
    vc_buffer even_buf (
        .clk      (clk),
        .rst    (reset),
        .ri (write_en_even),        // Buffer is not full and is ready
        .din       (din),
        .dout       (dout_even)
    );

    vc_buffer odd_buf (
        .clk      (clk),
        .rst    (reset),
        .ri (write_en_odd),         // Buffer is not full and is ready
        .din       (din),
        .dout       (dout_odd)
    );


    // Mesh packet header format
    //   [63]    = VC polarity
    //   [62:61] = Destination X (Dx)
    //   [60:59] = Destination Y (Dy)
    //   [58:57] = Source X
    //   [56:55] = Source Y
    //   [54:32] = Reserved
    //   [31:0]  = Payload
    wire [1:0] even_dest_x = dout_even[62:61];
    wire [1:0] even_dest_y = dout_even[60:59];

    wire [1:0] odd_dest_x  = dout_odd[62:61];
    wire [1:0] odd_dest_y  = dout_odd[60:59];

    // Routing decision for even VC buffer contents
    reg [4:0] route_even;
    always @(*) begin
        if      (even_dest_x > ROUTER_X) route_even = 5'b00100; // East
        else if (even_dest_x < ROUTER_X) route_even = 5'b01000; // West
        else if (even_dest_y > ROUTER_Y) route_even = 5'b00001; // North
        else if (even_dest_y < ROUTER_Y) route_even = 5'b00010; // South
        else                             route_even = 5'b10000; // PE: arrived
    end

    // Routing decision for odd VC buffer contents
    reg [4:0] route_odd;
    always @(*) begin
        if      (odd_dest_x > ROUTER_X) route_odd = 5'b00100; // East
        else if (odd_dest_x < ROUTER_X) route_odd = 5'b01000; // West
        else if (odd_dest_y > ROUTER_Y) route_odd = 5'b00001; // North
        else if (odd_dest_y < ROUTER_Y) route_odd = 5'b00010; // South
        else                            route_odd  = 5'b10000; // PE: arrived
    end

    // ---------------------------------------------------------------
    // Request outputs: only valid when buffer is full AND
    // it is the correct polarity cycle for internal forwarding
    //   Even VC acts internally on EVEN cycles (polarity=0)
    //   Odd  VC acts internally on ODD  cycles (polarity=1)
    // ---------------------------------------------------------------
    assign request_even = (even_full && (polarity == 1'b0)) ? route_even : 5'b00000;
    assign request_odd  = (odd_full  && (polarity == 1'b1)) ? route_odd : 5'b00000;

    // ---------------------------------------------------------------
    // Moore State Machine: update full/empty flags on clock edge
    // Write takes priority check is safe because write_en already
    // requires ~full, so write and grant cannot both be true
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            even_full <= 1'b0;
            odd_full  <= 1'b0;
        end
        else begin
            // Even VC buffer state transitions
            if (write_en_even)
                even_full <= 1'b1;       // Packet written in: now full
            else if (grant_even)
                even_full <= 1'b0;       // Packet forwarded out: now empty

            // Odd VC buffer state transitions
            if (write_en_odd)
                odd_full  <= 1'b1;
            else if (grant_odd)
                odd_full  <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // ri: Moore output — purely reflects buffer status for current
    // external polarity. Asserted (=1) means buffer is EMPTY.
    //   Even cycle → external is odd VC  → ri reflects odd  buffer
    //   Odd  cycle → external is even VC → ri reflects even buffer
    // ---------------------------------------------------------------
    assign ri = (polarity == 1'b0) ? ~odd_full : ~even_full;

endmodule
