`timescale 1ns/1ps
// ============================================================
// cardinal_router.v
// Cardinal Bidirectional 2D Mesh NoC Router
//
// EE 577B -- Cardinal Router Project
//
// 5-port router: North, South, East, West, PE
// Each port has one input_ctrl (with 2 VC buffers)
// Each port has one output_ctrl (with arbiter + 2 VC buffers)
//
// Routing: XY dimension-order, header-driven (direction + hop)
//   hopX[55:52]: unary-encoded remaining X hops
//   hopY[51:48]: unary-encoded remaining Y hops
//   dirX[62]:    0=East, 1=West
//   dirY[61]:    0=South, 1=North
//
// VC Multiplexing:
//   Even cycle: even VC internal, odd  VC external
//   Odd  cycle: odd  VC internal, even VC external
//
// Arbitration Priority (spec-mandated for PE output):
//   PE   output: N -> S -> E -> W  (spec Figure, Section 9)
//   Other outputs: freedom clause -- see slot comments below
//
// Port naming follows spec Figure 1 exactly:
//   {dir}si/ri/di -- input  channel (si=send-in, ri=ready-in)
//   {dir}so/ro/do -- output channel (so=send-out, ro=ready-out)
//   dir: n=North s=South e=East w=West pe=ProcessingElement
// ============================================================

module cardinal_router (
    input  wire        clk,
    input  wire        reset,
    output wire        polarity,        // Even(0)/Odd(1) cycle indicator

    // ----------------------------------------------------------
    // North Port -- connects to router above in mesh
    // ----------------------------------------------------------
    input  wire        nsi,             // North send-in
    output wire        nri,             // North ready-in
    input  wire [63:0] ndi,             // North data-in
    output wire        nso,             // North send-out
    input  wire        nro,             // North ready-out
    output wire [63:0] ndo,             // North data-out

    // ----------------------------------------------------------
    // South Port -- connects to router below in mesh
    // ----------------------------------------------------------
    input  wire        ssi,             // South send-in
    output wire        sri,             // South ready-in
    input  wire [63:0] sdi,             // South data-in
    output wire        sso,             // South send-out
    input  wire        sro,             // South ready-out
    output wire [63:0] sdo,             // South data-out

    // ----------------------------------------------------------
    // East Port -- connects to router to the right in mesh
    // ----------------------------------------------------------
    input  wire        esi,             // East send-in
    output wire        eri,             // East ready-in
    input  wire [63:0] edi,             // East data-in
    output wire        eso,             // East send-out
    input  wire        ero,             // East ready-out
    output wire [63:0] edo,             // East data-out

    // ----------------------------------------------------------
    // West Port -- connects to router to the left in mesh
    // ----------------------------------------------------------
    input  wire        wsi,             // West send-in
    output wire        wri,             // West ready-in
    input  wire [63:0] wdi,             // West data-in
    output wire        wso,             // West send-out
    input  wire        wro,             // West ready-out
    output wire [63:0] wdo,             // West data-out

    // ----------------------------------------------------------
    // PE Port -- connects to local Processing Element
    // ----------------------------------------------------------
    input  wire        pesi,            // PE send-in
    output wire        peri,            // PE ready-in
    input  wire [63:0] pedi,            // PE data-in
    output wire        peso,            // PE send-out
    input  wire        pero,            // PE ready-out
    output wire [63:0] pedo             // PE data-out
);

    // ----------------------------------------------------------
    // Polarity Generator
    //
    // Per spec:
    //   "polarity initialized to 0 when reset is asserted"
    //   "toggles to 1 at first rising clk edge after reset"
    //   "toggles every cycle thereafter while reset is negated"
    //
    // This drives the entire VC multiplexing scheme
    // ----------------------------------------------------------
    reg polarity_reg;

    always @(posedge clk) begin
        if (reset)
            polarity_reg <= 1'b0;       // Even during reset
        else
            polarity_reg <= ~polarity_reg; // Toggle every cycle
    end

    assign polarity = polarity_reg;

    // ----------------------------------------------------------
    // Internal data wires -- from each input_ctrl to crossbar
    //
    // ic0 = North input_ctrl
    // ic1 = South input_ctrl
    // ic2 = East  input_ctrl
    // ic3 = West  input_ctrl
    // ic4 = PE    input_ctrl
    //
    // do_even: contents of even VC buffer (always driven)
    // do_odd:  contents of odd  VC buffer (always driven)
    // ----------------------------------------------------------
    wire [63:0] ic0_do_even, ic0_do_odd; // North
    wire [63:0] ic1_do_even, ic1_do_odd; // South
    wire [63:0] ic2_do_even, ic2_do_odd; // East
    wire [63:0] ic3_do_even, ic3_do_odd; // West
    wire [63:0] ic4_do_even, ic4_do_odd; // PE

    // ----------------------------------------------------------
    // Request wires -- from each input_ctrl to all output_ctrls
    //
    // 5-bit one-hot: [0]=N [1]=S [2]=E [3]=W [4]=PE
    // Only one bit high at a time (XY routing -> one direction)
    // _even active on even cycles, _odd active on odd cycles
    // ----------------------------------------------------------
    wire [4:0] ic0_req_even, ic0_req_odd; // North requests
    wire [4:0] ic1_req_even, ic1_req_odd; // South requests
    wire [4:0] ic2_req_even, ic2_req_odd; // East  requests
    wire [4:0] ic3_req_even, ic3_req_odd; // West  requests
    wire [4:0] ic4_req_even, ic4_req_odd; // PE    requests

    // ----------------------------------------------------------
    // Grant wires -- from each output_ctrl back to input_ctrls
    //
    // [3:0] one-hot: which slot (input) was granted this cycle
    // ----------------------------------------------------------
    wire [3:0] oc_north_grant_even, oc_north_grant_odd;
    wire [3:0] oc_south_grant_even, oc_south_grant_odd;
    wire [3:0] oc_east_grant_even,  oc_east_grant_odd;
    wire [3:0] oc_west_grant_even,  oc_west_grant_odd;
    wire [3:0] oc_pe_grant_even,    oc_pe_grant_odd;

    // ----------------------------------------------------------
    // Grant routing back to input_ctrls (OR reduction)
    //
    // Each input_ctrl receives a single grant_even and grant_odd.
    // XY routing guarantees only ONE output is requested per cycle
    // so at most one grant source can be high -- OR is safe.
    //
    // Slot assignments (from output_ctrl instantiation below):
    //
    // oc_north slots: [0]=S(ic1) [1]=E(ic2) [2]=W(ic3) [3]=PE(ic4)
    // oc_south slots: [0]=N(ic0) [1]=E(ic2) [2]=W(ic3) [3]=PE(ic4)
    // oc_east  slots: [0]=N(ic0) [1]=S(ic1) [2]=W(ic3) [3]=PE(ic4)
    // oc_west  slots: [0]=N(ic0) [1]=S(ic1) [2]=E(ic2) [3]=PE(ic4)
    // oc_pe    slots: [0]=N(ic0) [1]=S(ic1) [2]=E(ic2) [3]=W(ic3)
    //
    // ic0(North) can go to:  South, East, West, PE outputs
    //   oc_south[0], oc_east[0], oc_west[0], oc_pe[0]
    //
    // ic1(South) can go to:  North, East, West, PE outputs
    //   oc_north[0], oc_east[1], oc_west[1], oc_pe[1]
    //
    // ic2(East)  can go to:  North, South, West, PE outputs
    //   oc_north[1], oc_south[1], oc_west[2], oc_pe[2]
    //
    // ic3(West)  can go to:  North, South, East, PE outputs
    //   oc_north[2], oc_south[2], oc_east[2], oc_pe[3]
    //
    // ic4(PE)    can go to:  North, South, East, West outputs
    //   oc_north[3], oc_south[3], oc_east[3], oc_west[3]
    // ----------------------------------------------------------

    // ic0 (North input) grant signals
    wire ic0_grant_even = oc_south_grant_even[0] | oc_east_grant_even[0]
                        | oc_west_grant_even[0]  | oc_pe_grant_even[0];
    wire ic0_grant_odd  = oc_south_grant_odd[0]  | oc_east_grant_odd[0]
                        | oc_west_grant_odd[0]   | oc_pe_grant_odd[0];

    // ic1 (South input) grant signals
    wire ic1_grant_even = oc_north_grant_even[0] | oc_east_grant_even[1]
                        | oc_west_grant_even[1]  | oc_pe_grant_even[1];
    wire ic1_grant_odd  = oc_north_grant_odd[0]  | oc_east_grant_odd[1]
                        | oc_west_grant_odd[1]   | oc_pe_grant_odd[1];

    // ic2 (East input) grant signals
    wire ic2_grant_even = oc_north_grant_even[1] | oc_south_grant_even[1]
                        | oc_west_grant_even[2]  | oc_pe_grant_even[2];
    wire ic2_grant_odd  = oc_north_grant_odd[1]  | oc_south_grant_odd[1]
                        | oc_west_grant_odd[2]   | oc_pe_grant_odd[2];

    // ic3 (West input) grant signals
    wire ic3_grant_even = oc_north_grant_even[2] | oc_south_grant_even[2]
                        | oc_east_grant_even[2]  | oc_pe_grant_even[3];
    wire ic3_grant_odd  = oc_north_grant_odd[2]  | oc_south_grant_odd[2]
                        | oc_east_grant_odd[2]   | oc_pe_grant_odd[3];

    // ic4 (PE input) grant signals
    wire ic4_grant_even = oc_north_grant_even[3] | oc_south_grant_even[3]
                        | oc_east_grant_even[3]  | oc_west_grant_even[3];
    wire ic4_grant_odd  = oc_north_grant_odd[3]  | oc_south_grant_odd[3]
                        | oc_east_grant_odd[3]   | oc_west_grant_odd[3];

    // ----------------------------------------------------------
    // Input Controller Instantiations
    //
    // No ROUTER_X/Y parameters needed -- routing is header-driven
    // Each input_ctrl decodes hopX/hopY/dirX/dirY from packet header
    // ----------------------------------------------------------

    // ic0: North input controller
    input_ctrl ic_north (
        .clk         (clk),
        .reset       (reset),
        .polarity    (polarity_reg),
        .si          (nsi),
        .ri          (nri),
        .di          (ndi),
        .request_even(ic0_req_even),
        .request_odd (ic0_req_odd),
        .grant_even  (ic0_grant_even),
        .grant_odd   (ic0_grant_odd),
        .do_even     (ic0_do_even),
        .do_odd      (ic0_do_odd)
    );

    // ic1: South input controller
    input_ctrl ic_south (
        .clk         (clk),
        .reset       (reset),
        .polarity    (polarity_reg),
        .si          (ssi),
        .ri          (sri),
        .di          (sdi),
        .request_even(ic1_req_even),
        .request_odd (ic1_req_odd),
        .grant_even  (ic1_grant_even),
        .grant_odd   (ic1_grant_odd),
        .do_even     (ic1_do_even),
        .do_odd      (ic1_do_odd)
    );

    // ic2: East input controller
    input_ctrl ic_east (
        .clk         (clk),
        .reset       (reset),
        .polarity    (polarity_reg),
        .si          (esi),
        .ri          (eri),
        .di          (edi),
        .request_even(ic2_req_even),
        .request_odd (ic2_req_odd),
        .grant_even  (ic2_grant_even),
        .grant_odd   (ic2_grant_odd),
        .do_even     (ic2_do_even),
        .do_odd      (ic2_do_odd)
    );

    // ic3: West input controller
    input_ctrl ic_west (
        .clk         (clk),
        .reset       (reset),
        .polarity    (polarity_reg),
        .si          (wsi),
        .ri          (wri),
        .di          (wdi),
        .request_even(ic3_req_even),
        .request_odd (ic3_req_odd),
        .grant_even  (ic3_grant_even),
        .grant_odd   (ic3_grant_odd),
        .do_even     (ic3_do_even),
        .do_odd      (ic3_do_odd)
    );

    // ic4: PE input controller
    input_ctrl ic_pe (
        .clk         (clk),
        .reset       (reset),
        .polarity    (polarity_reg),
        .si          (pesi),
        .ri          (peri),
        .di          (pedi),
        .request_even(ic4_req_even),
        .request_odd (ic4_req_odd),
        .grant_even  (ic4_grant_even),
        .grant_odd   (ic4_grant_odd),
        .do_even     (ic4_do_even),
        .do_odd      (ic4_do_odd)
    );

    // ----------------------------------------------------------
    // Output Controller Instantiations
    //
    // For each output_ctrl:
    //   - 4 requesting inputs (never self -- no U-turns)
    //   - Slot[0] = highest priority, Slot[3] = lowest
    //   - request bit used = the bit corresponding to THIS output
    //     direction in the requesting input's 5-bit request vector
    //   - data bus slots MUST match request slot ordering exactly
    //
    // Request bit encoding: [0]=N [1]=S [2]=E [3]=W [4]=PE
    // ----------------------------------------------------------

    // ----------------------------------------------------------
    // oc_north: North output controller
    // Arbitrates: S(ic1), E(ic2), W(ic3), PE(ic4)
    // Priority:   S(0) -> E(1) -> W(2) -> PE(3)  [freedom clause]
    // Request bit checked: [0] = North direction
    // ----------------------------------------------------------
    output_ctrl oc_north (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        // Requests -- bit[0]=North from each competing input
        .request_even ({ic4_req_even[0], ic3_req_even[0],
                        ic2_req_even[0], ic1_req_even[0]}),
        .request_odd  ({ic4_req_odd[0],  ic3_req_odd[0],
                        ic2_req_odd[0],  ic1_req_odd[0]}),
        // Data buses -- slots must match request slot order
        // slot0=ic1(S), slot1=ic2(E), slot2=ic3(W), slot3=ic4(PE)
        .di_even_0    (ic1_do_even),    // slot 0: South
        .di_even_1    (ic2_do_even),    // slot 1: East
        .di_even_2    (ic3_do_even),    // slot 2: West
        .di_even_3    (ic4_do_even),    // slot 3: PE
        .di_odd_0     (ic1_do_odd),
        .di_odd_1     (ic2_do_odd),
        .di_odd_2     (ic3_do_odd),
        .di_odd_3     (ic4_do_odd),
        // Grants back to input_ctrls
        .grant_even   (oc_north_grant_even),
        .grant_odd    (oc_north_grant_odd),
        // External channel
        .so           (nso),
        .ro           (nro),
        .do_ext       (ndo)
    );

    // ----------------------------------------------------------
    // oc_south: South output controller
    // Arbitrates: N(ic0), E(ic2), W(ic3), PE(ic4)
    // Priority:   N(0) -> E(1) -> W(2) -> PE(3)  [freedom clause]
    // Request bit checked: [1] = South direction
    // ----------------------------------------------------------
    output_ctrl oc_south (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        // Requests -- bit[1]=South from each competing input
        .request_even ({ic4_req_even[1], ic3_req_even[1],
                        ic2_req_even[1], ic0_req_even[1]}),
        .request_odd  ({ic4_req_odd[1],  ic3_req_odd[1],
                        ic2_req_odd[1],  ic0_req_odd[1]}),
        // slot0=ic0(N), slot1=ic2(E), slot2=ic3(W), slot3=ic4(PE)
        .di_even_0    (ic0_do_even),    // slot 0: North
        .di_even_1    (ic2_do_even),    // slot 1: East
        .di_even_2    (ic3_do_even),    // slot 2: West
        .di_even_3    (ic4_do_even),    // slot 3: PE
        .di_odd_0     (ic0_do_odd),
        .di_odd_1     (ic2_do_odd),
        .di_odd_2     (ic3_do_odd),
        .di_odd_3     (ic4_do_odd),
        .grant_even   (oc_south_grant_even),
        .grant_odd    (oc_south_grant_odd),
        .so           (sso),
        .ro           (sro),
        .do_ext       (sdo)
    );

    // ----------------------------------------------------------
    // oc_east: East output controller
    // Arbitrates: N(ic0), S(ic1), W(ic3), PE(ic4)
    // Priority:   N(0) -> S(1) -> W(2) -> PE(3)  [freedom clause]
    // Request bit checked: [2] = East direction
    // ----------------------------------------------------------
    output_ctrl oc_east (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        // Requests -- bit[2]=East from each competing input
        .request_even ({ic4_req_even[2], ic3_req_even[2],
                        ic1_req_even[2], ic0_req_even[2]}),
        .request_odd  ({ic4_req_odd[2],  ic3_req_odd[2],
                        ic1_req_odd[2],  ic0_req_odd[2]}),
        // slot0=ic0(N), slot1=ic1(S), slot2=ic3(W), slot3=ic4(PE)
        .di_even_0    (ic0_do_even),    // slot 0: North
        .di_even_1    (ic1_do_even),    // slot 1: South
        .di_even_2    (ic3_do_even),    // slot 2: West
        .di_even_3    (ic4_do_even),    // slot 3: PE
        .di_odd_0     (ic0_do_odd),
        .di_odd_1     (ic1_do_odd),
        .di_odd_2     (ic3_do_odd),
        .di_odd_3     (ic4_do_odd),
        .grant_even   (oc_east_grant_even),
        .grant_odd    (oc_east_grant_odd),
        .so           (eso),
        .ro           (ero),
        .do_ext       (edo)
    );

    // ----------------------------------------------------------
    // oc_west: West output controller
    // Arbitrates: N(ic0), S(ic1), E(ic2), PE(ic4)
    // Priority:   N(0) -> S(1) -> E(2) -> PE(3)  [freedom clause]
    // Request bit checked: [3] = West direction
    // ----------------------------------------------------------
    output_ctrl oc_west (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        // Requests -- bit[3]=West from each competing input
        .request_even ({ic4_req_even[3], ic2_req_even[3],
                        ic1_req_even[3], ic0_req_even[3]}),
        .request_odd  ({ic4_req_odd[3],  ic2_req_odd[3],
                        ic1_req_odd[3],  ic0_req_odd[3]}),
        // slot0=ic0(N), slot1=ic1(S), slot2=ic2(E), slot3=ic4(PE)
        .di_even_0    (ic0_do_even),    // slot 0: North
        .di_even_1    (ic1_do_even),    // slot 1: South
        .di_even_2    (ic2_do_even),    // slot 2: East
        .di_even_3    (ic4_do_even),    // slot 3: PE
        .di_odd_0     (ic0_do_odd),
        .di_odd_1     (ic1_do_odd),
        .di_odd_2     (ic2_do_odd),
        .di_odd_3     (ic4_do_odd),
        .grant_even   (oc_west_grant_even),
        .grant_odd    (oc_west_grant_odd),
        .so           (wso),
        .ro           (wro),
        .do_ext       (wdo)
    );

    // ----------------------------------------------------------
    // oc_pe: PE output controller
    // Arbitrates: N(ic0), S(ic1), E(ic2), W(ic3)
    // Priority:   N(0) -> S(1) -> E(2) -> W(3)  <- SPEC MANDATED
    // Request bit checked: [4] = PE direction
    // ----------------------------------------------------------
    output_ctrl oc_pe (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        // Requests -- bit[4]=PE from each competing input
        // Slot order MUST be N->S->E->W per spec
        .request_even ({ic3_req_even[4], ic2_req_even[4],
                        ic1_req_even[4], ic0_req_even[4]}),
        .request_odd  ({ic3_req_odd[4],  ic2_req_odd[4],
                        ic1_req_odd[4],  ic0_req_odd[4]}),
        // slot0=ic0(N), slot1=ic1(S), slot2=ic2(E), slot3=ic3(W)
        .di_even_0    (ic0_do_even),    // slot 0: North (highest priority)
        .di_even_1    (ic1_do_even),    // slot 1: South
        .di_even_2    (ic2_do_even),    // slot 2: East
        .di_even_3    (ic3_do_even),    // slot 3: West  (lowest priority)
        .di_odd_0     (ic0_do_odd),
        .di_odd_1     (ic1_do_odd),
        .di_odd_2     (ic2_do_odd),
        .di_odd_3     (ic3_do_odd),
        .grant_even   (oc_pe_grant_even),
        .grant_odd    (oc_pe_grant_odd),
        .so           (peso),
        .ro           (pero),
        .do_ext       (pedo)
    );

endmodule
