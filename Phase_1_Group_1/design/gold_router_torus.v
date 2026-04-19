`timescale 1ns/1ps
// ============================================================
// gold_router_torus.v
// Cardinal Router -- Single Router (Standard XY)
//
// EE 577B -- Cardinal Router Project
// VARIANT: torus  (XY routing on 4x4 torus with wrap-around)
//
// Differences from gold_router.v:
//   1. Parameters ROUTER_X, ROUTER_Y specify this router's coords
//      (passed to all 5 input_ctrl_torus instances)
//   2. Instantiates input_ctrl_torus instead of input_ctrl
//   3. Instantiates output_ctrl_torus instead of output_ctrl
//   4. Ports are IDENTICAL to gold_router.v (drop-in compatible)
//
// Architecture: 5 input channels x 5 output channels
//   ic0=North, ic1=South, ic2=East, ic3=West, ic4=PE
//   oc_north, oc_south, oc_east, oc_west, oc_pe
//
// Polarity generator, arbitration wiring, grant routing:
//   IDENTICAL to gold_router.v
// ============================================================

module gold_router_torus #(
    parameter [7:0] ROUTER_X = 8'd0,   // X coordinate of this router
    parameter [7:0] ROUTER_Y = 8'd0    // Y coordinate of this router
) (
    input  wire        clk,
    input  wire        reset,
    output wire        polarity,        // Even(0)/Odd(1) cycle indicator

    // North port
    input  wire        nsi,
    output wire        nri,
    input  wire [63:0] ndi,
    input  wire        nro,
    output wire        nso,
    output wire [63:0] ndo,

    // South port
    input  wire        ssi,
    output wire        sri,
    input  wire [63:0] sdi,
    input  wire        sro,
    output wire        sso,
    output wire [63:0] sdo,

    // East port
    input  wire        esi,
    output wire        eri,
    input  wire [63:0] edi,
    input  wire        ero,
    output wire        eso,
    output wire [63:0] edo,

    // West port
    input  wire        wsi,
    output wire        wri,
    input  wire [63:0] wdi,
    input  wire        wro,
    output wire        wso,
    output wire [63:0] wdo,

    // PE port
    input  wire        pesi,
    output wire        peri,
    input  wire [63:0] pedi,
    input  wire        pero,
    output wire        peso,
    output wire [63:0] pedo
);

    // ----------------------------------------------------------
    // Polarity generator (identical to gold_router.v)
    // Reset -> 0, toggles each cycle
    // ----------------------------------------------------------
    reg polarity_reg;
    always @(posedge clk) begin
        if (reset)
            polarity_reg <= 1'b0;
        else
            polarity_reg <= ~polarity_reg;
    end
    assign polarity = polarity_reg;

    // ----------------------------------------------------------
    // Internal data wires: input_ctrl outputs to crossbar
    // ----------------------------------------------------------
    wire [63:0] ic0_do_even, ic0_do_odd;   // North
    wire [63:0] ic1_do_even, ic1_do_odd;   // South
    wire [63:0] ic2_do_even, ic2_do_odd;   // East
    wire [63:0] ic3_do_even, ic3_do_odd;   // West
    wire [63:0] ic4_do_even, ic4_do_odd;   // PE

    // ----------------------------------------------------------
    // Request wires: 5-bit one-hot from each input_ctrl
    // ----------------------------------------------------------
    wire [4:0] ic0_req_even, ic0_req_odd;
    wire [4:0] ic1_req_even, ic1_req_odd;
    wire [4:0] ic2_req_even, ic2_req_odd;
    wire [4:0] ic3_req_even, ic3_req_odd;
    wire [4:0] ic4_req_even, ic4_req_odd;

    // ----------------------------------------------------------
    // Grant wires: 4-bit one-hot from each output_ctrl
    // ----------------------------------------------------------
    wire [3:0] oc_north_grant_even, oc_north_grant_odd;
    wire [3:0] oc_south_grant_even, oc_south_grant_odd;
    wire [3:0] oc_east_grant_even,  oc_east_grant_odd;
    wire [3:0] oc_west_grant_even,  oc_west_grant_odd;
    wire [3:0] oc_pe_grant_even,    oc_pe_grant_odd;

    // ----------------------------------------------------------
    // Grant routing back to input_ctrls (OR reduction)
    // Slot assignments (identical to gold_router.v):
    //   oc_north: [0]=S [1]=E [2]=W [3]=PE
    //   oc_south: [0]=N [1]=E [2]=W [3]=PE
    //   oc_east:  [0]=N [1]=S [2]=W [3]=PE
    //   oc_west:  [0]=N [1]=S [2]=E [3]=PE
    //   oc_pe:    [0]=N [1]=S [2]=E [3]=W
    // ----------------------------------------------------------
    wire ic0_grant_even = oc_south_grant_even[0] | oc_east_grant_even[0]
                        | oc_west_grant_even[0]  | oc_pe_grant_even[0];
    wire ic0_grant_odd  = oc_south_grant_odd[0]  | oc_east_grant_odd[0]
                        | oc_west_grant_odd[0]   | oc_pe_grant_odd[0];

    wire ic1_grant_even = oc_north_grant_even[0] | oc_east_grant_even[1]
                        | oc_west_grant_even[1]  | oc_pe_grant_even[1];
    wire ic1_grant_odd  = oc_north_grant_odd[0]  | oc_east_grant_odd[1]
                        | oc_west_grant_odd[1]   | oc_pe_grant_odd[1];

    wire ic2_grant_even = oc_north_grant_even[1] | oc_south_grant_even[1]
                        | oc_west_grant_even[2]  | oc_pe_grant_even[2];
    wire ic2_grant_odd  = oc_north_grant_odd[1]  | oc_south_grant_odd[1]
                        | oc_west_grant_odd[2]   | oc_pe_grant_odd[2];

    wire ic3_grant_even = oc_north_grant_even[2] | oc_south_grant_even[2]
                        | oc_east_grant_even[2]  | oc_pe_grant_even[3];
    wire ic3_grant_odd  = oc_north_grant_odd[2]  | oc_south_grant_odd[2]
                        | oc_east_grant_odd[2]   | oc_pe_grant_odd[3];

    wire ic4_grant_even = oc_north_grant_even[3] | oc_south_grant_even[3]
                        | oc_east_grant_even[3]  | oc_west_grant_even[3];
    wire ic4_grant_odd  = oc_north_grant_odd[3]  | oc_south_grant_odd[3]
                        | oc_east_grant_odd[3]   | oc_west_grant_odd[3];

    // ----------------------------------------------------------
    // Input Controller Instantiations (torus variant)
    // ROUTER_X and ROUTER_Y propagated to each controller
    // ----------------------------------------------------------

    input_ctrl_torus #(.ROUTER_X(ROUTER_X), .ROUTER_Y(ROUTER_Y)) ic_north (
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

    input_ctrl_torus #(.ROUTER_X(ROUTER_X), .ROUTER_Y(ROUTER_Y)) ic_south (
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

    input_ctrl_torus #(.ROUTER_X(ROUTER_X), .ROUTER_Y(ROUTER_Y)) ic_east (
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

    input_ctrl_torus #(.ROUTER_X(ROUTER_X), .ROUTER_Y(ROUTER_Y)) ic_west (
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

    input_ctrl_torus #(.ROUTER_X(ROUTER_X), .ROUTER_Y(ROUTER_Y)) ic_pe (
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
    // Output Controller Instantiations (torus variant)
    // Slot/priority ordering IDENTICAL to gold_router.v
    // ----------------------------------------------------------

    output_ctrl_torus oc_north (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        .request_even ({ic4_req_even[0], ic3_req_even[0],
                        ic2_req_even[0], ic1_req_even[0]}),
        .request_odd  ({ic4_req_odd[0],  ic3_req_odd[0],
                        ic2_req_odd[0],  ic1_req_odd[0]}),
        .di_even_0    (ic1_do_even),
        .di_even_1    (ic2_do_even),
        .di_even_2    (ic3_do_even),
        .di_even_3    (ic4_do_even),
        .di_odd_0     (ic1_do_odd),
        .di_odd_1     (ic2_do_odd),
        .di_odd_2     (ic3_do_odd),
        .di_odd_3     (ic4_do_odd),
        .grant_even   (oc_north_grant_even),
        .grant_odd    (oc_north_grant_odd),
        .so           (nso),
        .ro           (nro),
        .do_ext       (ndo)
    );

    output_ctrl_torus oc_south (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        .request_even ({ic4_req_even[1], ic3_req_even[1],
                        ic2_req_even[1], ic0_req_even[1]}),
        .request_odd  ({ic4_req_odd[1],  ic3_req_odd[1],
                        ic2_req_odd[1],  ic0_req_odd[1]}),
        .di_even_0    (ic0_do_even),
        .di_even_1    (ic2_do_even),
        .di_even_2    (ic3_do_even),
        .di_even_3    (ic4_do_even),
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

    output_ctrl_torus oc_east (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        .request_even ({ic4_req_even[2], ic3_req_even[2],
                        ic1_req_even[2], ic0_req_even[2]}),
        .request_odd  ({ic4_req_odd[2],  ic3_req_odd[2],
                        ic1_req_odd[2],  ic0_req_odd[2]}),
        .di_even_0    (ic0_do_even),
        .di_even_1    (ic1_do_even),
        .di_even_2    (ic3_do_even),
        .di_even_3    (ic4_do_even),
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

    output_ctrl_torus oc_west (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        .request_even ({ic4_req_even[3], ic2_req_even[3],
                        ic1_req_even[3], ic0_req_even[3]}),
        .request_odd  ({ic4_req_odd[3],  ic2_req_odd[3],
                        ic1_req_odd[3],  ic0_req_odd[3]}),
        .di_even_0    (ic0_do_even),
        .di_even_1    (ic1_do_even),
        .di_even_2    (ic2_do_even),
        .di_even_3    (ic4_do_even),
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

    output_ctrl_torus oc_pe (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity_reg),
        .request_even ({ic3_req_even[4], ic2_req_even[4],
                        ic1_req_even[4], ic0_req_even[4]}),
        .request_odd  ({ic3_req_odd[4],  ic2_req_odd[4],
                        ic1_req_odd[4],  ic0_req_odd[4]}),
        .di_even_0    (ic0_do_even),
        .di_even_1    (ic1_do_even),
        .di_even_2    (ic2_do_even),
        .di_even_3    (ic3_do_even),
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
