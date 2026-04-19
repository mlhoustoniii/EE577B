`timescale 1ns/1ps
// ============================================================
// gold_mesh_xystd.v
// Cardinal Bidirectional 4x4 Mesh Network-on-Chip (Standard XY variant)
//
// EE 577B -- Cardinal Mesh Project
//
// Instantiates 16 gold_router modules in a 4x4 grid
//
// Port naming convention (per spec Figure 2):
//   nodeXY_* where X=column (0-3), Y=row (0-3)
//   nodeXY_pesi  = PE send-in  to   router(X,Y)
//   nodeXY_peri  = PE ready-in from router(X,Y)
//   nodeXY_pedi  = PE data-in  to   router(X,Y)
//   nodeXY_peso  = PE send-out from router(X,Y)
//   nodeXY_pero  = PE ready-out to  router(X,Y)
//   nodeXY_pedo  = PE data-out from router(X,Y)
//   nodeXY_polarity = polarity from router(X,Y)
//
// Grid Layout (Y increases upward, North=up, South=down):
//
//   node03--node13--node23--node33   (row y=3, top)
//     |       |       |       |
//   node02--node12--node22--node32   (row y=2)
//     |       |       |       |
//   node01--node11--node21--node31   (row y=1)
//     |       |       |       |
//   node00--node10--node20--node30   (row y=0, bottom)
//
// Edge Port Tie-off Rules (ports pointing off-grid):
//   si  = 1'b0   (no upstream sender exists)
//   di  = 64'b0  (no data)
//   ro  = 1'b1   (always ready -- nothing will ever send)
//   ri  = ()     (output, left unconnected safely)
//   so  = ()     (output, left unconnected safely)
//   do  = ()     (output, left unconnected safely)
//
// Routing: Standard XY coordinate-comparison
//   dst_x[55:48], dst_y[47:40]: destination coordinates
//   ROUTER_X/ROUTER_Y: each router compares vs own coordinates
//
// Handshaking:
//   Transfer occurs when both si and ri are simultaneously high
// ============================================================

module gold_mesh_xystd (
    input  wire        clk,
    input  wire        reset,

    // ----------------------------------------------------------
    // Row y=0 (bottom row): node00, node10, node20, node30
    // ----------------------------------------------------------

    // node00 (x=0, y=0) PE interface
    input  wire        node00_pesi,
    output wire        node00_peri,
    input  wire [63:0] node00_pedi,
    output wire        node00_peso,
    input  wire        node00_pero,
    output wire [63:0] node00_pedo,
    output wire        node00_polarity,

    // node10 (x=1, y=0) PE interface
    input  wire        node10_pesi,
    output wire        node10_peri,
    input  wire [63:0] node10_pedi,
    output wire        node10_peso,
    input  wire        node10_pero,
    output wire [63:0] node10_pedo,
    output wire        node10_polarity,

    // node20 (x=2, y=0) PE interface
    input  wire        node20_pesi,
    output wire        node20_peri,
    input  wire [63:0] node20_pedi,
    output wire        node20_peso,
    input  wire        node20_pero,
    output wire [63:0] node20_pedo,
    output wire        node20_polarity,

    // node30 (x=3, y=0) PE interface
    input  wire        node30_pesi,
    output wire        node30_peri,
    input  wire [63:0] node30_pedi,
    output wire        node30_peso,
    input  wire        node30_pero,
    output wire [63:0] node30_pedo,
    output wire        node30_polarity,

    // ----------------------------------------------------------
    // Row y=1: node01, node11, node21, node31
    // ----------------------------------------------------------

    // node01 (x=0, y=1) PE interface
    input  wire        node01_pesi,
    output wire        node01_peri,
    input  wire [63:0] node01_pedi,
    output wire        node01_peso,
    input  wire        node01_pero,
    output wire [63:0] node01_pedo,
    output wire        node01_polarity,

    // node11 (x=1, y=1) PE interface
    input  wire        node11_pesi,
    output wire        node11_peri,
    input  wire [63:0] node11_pedi,
    output wire        node11_peso,
    input  wire        node11_pero,
    output wire [63:0] node11_pedo,
    output wire        node11_polarity,

    // node21 (x=2, y=1) PE interface
    input  wire        node21_pesi,
    output wire        node21_peri,
    input  wire [63:0] node21_pedi,
    output wire        node21_peso,
    input  wire        node21_pero,
    output wire [63:0] node21_pedo,
    output wire        node21_polarity,

    // node31 (x=3, y=1) PE interface
    input  wire        node31_pesi,
    output wire        node31_peri,
    input  wire [63:0] node31_pedi,
    output wire        node31_peso,
    input  wire        node31_pero,
    output wire [63:0] node31_pedo,
    output wire        node31_polarity,

    // ----------------------------------------------------------
    // Row y=2: node02, node12, node22, node32
    // ----------------------------------------------------------

    // node02 (x=0, y=2) PE interface
    input  wire        node02_pesi,
    output wire        node02_peri,
    input  wire [63:0] node02_pedi,
    output wire        node02_peso,
    input  wire        node02_pero,
    output wire [63:0] node02_pedo,
    output wire        node02_polarity,

    // node12 (x=1, y=2) PE interface
    input  wire        node12_pesi,
    output wire        node12_peri,
    input  wire [63:0] node12_pedi,
    output wire        node12_peso,
    input  wire        node12_pero,
    output wire [63:0] node12_pedo,
    output wire        node12_polarity,

    // node22 (x=2, y=2) PE interface
    input  wire        node22_pesi,
    output wire        node22_peri,
    input  wire [63:0] node22_pedi,
    output wire        node22_peso,
    input  wire        node22_pero,
    output wire [63:0] node22_pedo,
    output wire        node22_polarity,

    // node32 (x=3, y=2) PE interface
    input  wire        node32_pesi,
    output wire        node32_peri,
    input  wire [63:0] node32_pedi,
    output wire        node32_peso,
    input  wire        node32_pero,
    output wire [63:0] node32_pedo,
    output wire        node32_polarity,

    // ----------------------------------------------------------
    // Row y=3 (top row): node03, node13, node23, node33
    // ----------------------------------------------------------

    // node03 (x=0, y=3) PE interface
    input  wire        node03_pesi,
    output wire        node03_peri,
    input  wire [63:0] node03_pedi,
    output wire        node03_peso,
    input  wire        node03_pero,
    output wire [63:0] node03_pedo,
    output wire        node03_polarity,

    // node13 (x=1, y=3) PE interface
    input  wire        node13_pesi,
    output wire        node13_peri,
    input  wire [63:0] node13_pedi,
    output wire        node13_peso,
    input  wire        node13_pero,
    output wire [63:0] node13_pedo,
    output wire        node13_polarity,

    // node23 (x=2, y=3) PE interface
    input  wire        node23_pesi,
    output wire        node23_peri,
    input  wire [63:0] node23_pedi,
    output wire        node23_peso,
    input  wire        node23_pero,
    output wire [63:0] node23_pedo,
    output wire        node23_polarity,

    // node33 (x=3, y=3) PE interface
    input  wire        node33_pesi,
    output wire        node33_peri,
    input  wire [63:0] node33_pedi,
    output wire        node33_peso,
    input  wire        node33_pero,
    output wire [63:0] node33_pedo,
    output wire        node33_polarity
);

    // ----------------------------------------------------------
    // Internal inter-router link wires
    //
    // Naming: {so/ro/do}_{dir}_x{X}y{Y}
    //   dir: e=eastward  n=northward
    //   _e links: router(X,Y) east-out -> router(X+1,Y) west-in
    //   _n links: router(X,Y) north-out -> router(X,Y+1) south-in
    //
    // Each bidirectional link needs BOTH directions:
    //   so_e_x0y0: send  from (0,0) going East  -> into (1,0) West
    //   so_w_x1y0: send  from (1,0) going West  -> into (0,0) East
    // ----------------------------------------------------------

    // ----------------------------------------------------------
    // Horizontal (East-West) links -- Row y=0
    // ----------------------------------------------------------
    wire        so_e_x0y0; wire ro_e_x0y0; wire [63:0] do_e_x0y0;
    wire        so_w_x1y0; wire ro_w_x1y0; wire [63:0] do_w_x1y0;

    wire        so_e_x1y0; wire ro_e_x1y0; wire [63:0] do_e_x1y0;
    wire        so_w_x2y0; wire ro_w_x2y0; wire [63:0] do_w_x2y0;

    wire        so_e_x2y0; wire ro_e_x2y0; wire [63:0] do_e_x2y0;
    wire        so_w_x3y0; wire ro_w_x3y0; wire [63:0] do_w_x3y0;

    // ----------------------------------------------------------
    // Horizontal (East-West) links -- Row y=1
    // ----------------------------------------------------------
    wire        so_e_x0y1; wire ro_e_x0y1; wire [63:0] do_e_x0y1;
    wire        so_w_x1y1; wire ro_w_x1y1; wire [63:0] do_w_x1y1;

    wire        so_e_x1y1; wire ro_e_x1y1; wire [63:0] do_e_x1y1;
    wire        so_w_x2y1; wire ro_w_x2y1; wire [63:0] do_w_x2y1;

    wire        so_e_x2y1; wire ro_e_x2y1; wire [63:0] do_e_x2y1;
    wire        so_w_x3y1; wire ro_w_x3y1; wire [63:0] do_w_x3y1;

    // ----------------------------------------------------------
    // Horizontal (East-West) links -- Row y=2
    // ----------------------------------------------------------
    wire        so_e_x0y2; wire ro_e_x0y2; wire [63:0] do_e_x0y2;
    wire        so_w_x1y2; wire ro_w_x1y2; wire [63:0] do_w_x1y2;

    wire        so_e_x1y2; wire ro_e_x1y2; wire [63:0] do_e_x1y2;
    wire        so_w_x2y2; wire ro_w_x2y2; wire [63:0] do_w_x2y2;

    wire        so_e_x2y2; wire ro_e_x2y2; wire [63:0] do_e_x2y2;
    wire        so_w_x3y2; wire ro_w_x3y2; wire [63:0] do_w_x3y2;

    // ----------------------------------------------------------
    // Horizontal (East-West) links -- Row y=3
    // ----------------------------------------------------------
    wire        so_e_x0y3; wire ro_e_x0y3; wire [63:0] do_e_x0y3;
    wire        so_w_x1y3; wire ro_w_x1y3; wire [63:0] do_w_x1y3;

    wire        so_e_x1y3; wire ro_e_x1y3; wire [63:0] do_e_x1y3;
    wire        so_w_x2y3; wire ro_w_x2y3; wire [63:0] do_w_x2y3;

    wire        so_e_x2y3; wire ro_e_x2y3; wire [63:0] do_e_x2y3;
    wire        so_w_x3y3; wire ro_w_x3y3; wire [63:0] do_w_x3y3;

    // ----------------------------------------------------------
    // Vertical (North-South) links -- Column x=0
    // ----------------------------------------------------------
    wire        so_n_x0y0; wire ro_n_x0y0; wire [63:0] do_n_x0y0;
    wire        so_s_x0y1; wire ro_s_x0y1; wire [63:0] do_s_x0y1;

    wire        so_n_x0y1; wire ro_n_x0y1; wire [63:0] do_n_x0y1;
    wire        so_s_x0y2; wire ro_s_x0y2; wire [63:0] do_s_x0y2;

    wire        so_n_x0y2; wire ro_n_x0y2; wire [63:0] do_n_x0y2;
    wire        so_s_x0y3; wire ro_s_x0y3; wire [63:0] do_s_x0y3;

    // ----------------------------------------------------------
    // Vertical (North-South) links -- Column x=1
    // ----------------------------------------------------------
    wire        so_n_x1y0; wire ro_n_x1y0; wire [63:0] do_n_x1y0;
    wire        so_s_x1y1; wire ro_s_x1y1; wire [63:0] do_s_x1y1;

    wire        so_n_x1y1; wire ro_n_x1y1; wire [63:0] do_n_x1y1;
    wire        so_s_x1y2; wire ro_s_x1y2; wire [63:0] do_s_x1y2;

    wire        so_n_x1y2; wire ro_n_x1y2; wire [63:0] do_n_x1y2;
    wire        so_s_x1y3; wire ro_s_x1y3; wire [63:0] do_s_x1y3;

    // ----------------------------------------------------------
    // Vertical (North-South) links -- Column x=2
    // ----------------------------------------------------------
    wire        so_n_x2y0; wire ro_n_x2y0; wire [63:0] do_n_x2y0;
    wire        so_s_x2y1; wire ro_s_x2y1; wire [63:0] do_s_x2y1;

    wire        so_n_x2y1; wire ro_n_x2y1; wire [63:0] do_n_x2y1;
    wire        so_s_x2y2; wire ro_s_x2y2; wire [63:0] do_s_x2y2;

    wire        so_n_x2y2; wire ro_n_x2y2; wire [63:0] do_n_x2y2;
    wire        so_s_x2y3; wire ro_s_x2y3; wire [63:0] do_s_x2y3;

    // ----------------------------------------------------------
    // Vertical (North-South) links -- Column x=3
    // ----------------------------------------------------------
    wire        so_n_x3y0; wire ro_n_x3y0; wire [63:0] do_n_x3y0;
    wire        so_s_x3y1; wire ro_s_x3y1; wire [63:0] do_s_x3y1;

    wire        so_n_x3y1; wire ro_n_x3y1; wire [63:0] do_n_x3y1;
    wire        so_s_x3y2; wire ro_s_x3y2; wire [63:0] do_s_x3y2;

    wire        so_n_x3y2; wire ro_n_x3y2; wire [63:0] do_n_x3y2;
    wire        so_s_x3y3; wire ro_s_x3y3; wire [63:0] do_s_x3y3;

    // ==========================================================
    // Router Instantiations -- 16 total
    // ROUTER_X/Y passed as parameters to each router instance
    //
    // Port connection rules per spec:
    //   North port of (X,Y) <--> South port of (X,Y+1)
    //   East  port of (X,Y) <--> West  port of (X+1,Y)
    //
    // Edge tie-offs:
    //   si=1'b0, di=64'b0, ro=1'b1
    //   ri/so/do left open (outputs, safe to leave unconnected)
    // ==========================================================

    // ----------------------------------------------------------
    // ROW y=0 -- Bottom row
    // South ports ALL tied off (bottom grid edge)
    // ----------------------------------------------------------

    // node00: (x=0, y=0) bottom-left corner
    // North ? node01 South | East ? node10 West
    // South: TIED OFF | West: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd0), .ROUTER_Y(8'd0)) router_x0y0 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node00_polarity),
        // North ? (0,1) south
        .nsi      (so_s_x0y1),   .nri  (ro_s_x0y1),
        .ndi      (do_s_x0y1),   .nso  (so_n_x0y0),
        .nro      (ro_n_x0y0),   .ndo  (do_n_x0y0),
        // South -- TIED OFF
        .ssi      (1'b0),         .sri  (),
        .sdi      (64'b0),        .sso  (),
        .sro      (1'b1),         .sdo  (),
        // East ? (1,0) west
        .esi      (so_w_x1y0),   .eri  (ro_w_x1y0),
        .edi      (do_w_x1y0),   .eso  (so_e_x0y0),
        .ero      (ro_e_x0y0),   .edo  (do_e_x0y0),
        // West -- TIED OFF
        .wsi      (1'b0),         .wri  (),
        .wdi      (64'b0),        .wso  (),
        .wro      (1'b1),         .wdo  (),
        // PE
        .pesi     (node00_pesi),  .peri (node00_peri),
        .pedi     (node00_pedi),  .peso (node00_peso),
        .pero     (node00_pero),  .pedo (node00_pedo)
    );

    // node10: (x=1, y=0) bottom row
    // North ? node11 South | East ? node20 West | West ? node00 East
    // South: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd1), .ROUTER_Y(8'd0)) router_x1y0 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node10_polarity),
        // North ? (1,1) south
        .nsi      (so_s_x1y1),   .nri  (ro_s_x1y1),
        .ndi      (do_s_x1y1),   .nso  (so_n_x1y0),
        .nro      (ro_n_x1y0),   .ndo  (do_n_x1y0),
        // South -- TIED OFF
        .ssi      (1'b0),         .sri  (),
        .sdi      (64'b0),        .sso  (),
        .sro      (1'b1),         .sdo  (),
        // East ? (2,0) west
        .esi      (so_w_x2y0),   .eri  (ro_w_x2y0),
        .edi      (do_w_x2y0),   .eso  (so_e_x1y0),
        .ero      (ro_e_x1y0),   .edo  (do_e_x1y0),
        // West ? (0,0) east
        .wsi      (so_e_x0y0),   .wri  (ro_e_x0y0),
        .wdi      (do_e_x0y0),   .wso  (so_w_x1y0),
        .wro      (ro_w_x1y0),   .wdo  (do_w_x1y0),
        // PE
        .pesi     (node10_pesi),  .peri (node10_peri),
        .pedi     (node10_pedi),  .peso (node10_peso),
        .pero     (node10_pero),  .pedo (node10_pedo)
    );

    // node20: (x=2, y=0) bottom row
    // North ? node21 South | East ? node30 West | West ? node10 East
    // South: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd2), .ROUTER_Y(8'd0)) router_x2y0 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node20_polarity),
        // North ? (2,1) south
        .nsi      (so_s_x2y1),   .nri  (ro_s_x2y1),
        .ndi      (do_s_x2y1),   .nso  (so_n_x2y0),
        .nro      (ro_n_x2y0),   .ndo  (do_n_x2y0),
        // South -- TIED OFF
        .ssi      (1'b0),         .sri  (),
        .sdi      (64'b0),        .sso  (),
        .sro      (1'b1),         .sdo  (),
        // East ? (3,0) west
        .esi      (so_w_x3y0),   .eri  (ro_w_x3y0),
        .edi      (do_w_x3y0),   .eso  (so_e_x2y0),
        .ero      (ro_e_x2y0),   .edo  (do_e_x2y0),
        // West ? (1,0) east
        .wsi      (so_e_x1y0),   .wri  (ro_e_x1y0),
        .wdi      (do_e_x1y0),   .wso  (so_w_x2y0),
        .wro      (ro_w_x2y0),   .wdo  (do_w_x2y0),
        // PE
        .pesi     (node20_pesi),  .peri (node20_peri),
        .pedi     (node20_pedi),  .peso (node20_peso),
        .pero     (node20_pero),  .pedo (node20_pedo)
    );

    // node30: (x=3, y=0) bottom-right corner
    // North ? node31 South | West ? node20 East
    // South: TIED OFF | East: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd3), .ROUTER_Y(8'd0)) router_x3y0 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node30_polarity),
        // North ? (3,1) south
        .nsi      (so_s_x3y1),   .nri  (ro_s_x3y1),
        .ndi      (do_s_x3y1),   .nso  (so_n_x3y0),
        .nro      (ro_n_x3y0),   .ndo  (do_n_x3y0),
        // South -- TIED OFF
        .ssi      (1'b0),         .sri  (),
        .sdi      (64'b0),        .sso  (),
        .sro      (1'b1),         .sdo  (),
        // East -- TIED OFF
        .esi      (1'b0),         .eri  (),
        .edi      (64'b0),        .eso  (),
        .ero      (1'b1),         .edo  (),
        // West ? (2,0) east
        .wsi      (so_e_x2y0),   .wri  (ro_e_x2y0),
        .wdi      (do_e_x2y0),   .wso  (so_w_x3y0),
        .wro      (ro_w_x3y0),   .wdo  (do_w_x3y0),
        // PE
        .pesi     (node30_pesi),  .peri (node30_peri),
        .pedi     (node30_pedi),  .peso (node30_peso),
        .pero     (node30_pero),  .pedo (node30_pedo)
    );

    // ----------------------------------------------------------
    // ROW y=1
    // ----------------------------------------------------------

    // node01: (x=0, y=1) left edge
    // West: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd0), .ROUTER_Y(8'd1)) router_x0y1 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node01_polarity),
        // North ? (0,2) south
        .nsi      (so_s_x0y2),   .nri  (ro_s_x0y2),
        .ndi      (do_s_x0y2),   .nso  (so_n_x0y1),
        .nro      (ro_n_x0y1),   .ndo  (do_n_x0y1),
        // South ? (0,0) north
        .ssi      (so_n_x0y0),   .sri  (ro_n_x0y0),
        .sdi      (do_n_x0y0),   .sso  (so_s_x0y1),
        .sro      (ro_s_x0y1),   .sdo  (do_s_x0y1),
        // East ? (1,1) west
        .esi      (so_w_x1y1),   .eri  (ro_w_x1y1),
        .edi      (do_w_x1y1),   .eso  (so_e_x0y1),
        .ero      (ro_e_x0y1),   .edo  (do_e_x0y1),
        // West -- TIED OFF
        .wsi      (1'b0),         .wri  (),
        .wdi      (64'b0),        .wso  (),
        .wro      (1'b1),         .wdo  (),
        // PE
        .pesi     (node01_pesi),  .peri (node01_peri),
        .pedi     (node01_pedi),  .peso (node01_peso),
        .pero     (node01_pero),  .pedo (node01_pedo)
    );

    // node11: (x=1, y=1) interior
    gold_router_xystd #(.ROUTER_X(8'd1), .ROUTER_Y(8'd1)) router_x1y1 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node11_polarity),
        // North ? (1,2) south
        .nsi      (so_s_x1y2),   .nri  (ro_s_x1y2),
        .ndi      (do_s_x1y2),   .nso  (so_n_x1y1),
        .nro      (ro_n_x1y1),   .ndo  (do_n_x1y1),
        // South ? (1,0) north
        .ssi      (so_n_x1y0),   .sri  (ro_n_x1y0),
        .sdi      (do_n_x1y0),   .sso  (so_s_x1y1),
        .sro      (ro_s_x1y1),   .sdo  (do_s_x1y1),
        // East ? (2,1) west
        .esi      (so_w_x2y1),   .eri  (ro_w_x2y1),
        .edi      (do_w_x2y1),   .eso  (so_e_x1y1),
        .ero      (ro_e_x1y1),   .edo  (do_e_x1y1),
        // West ? (0,1) east
        .wsi      (so_e_x0y1),   .wri  (ro_e_x0y1),
        .wdi      (do_e_x0y1),   .wso  (so_w_x1y1),
        .wro      (ro_w_x1y1),   .wdo  (do_w_x1y1),
        // PE
        .pesi     (node11_pesi),  .peri (node11_peri),
        .pedi     (node11_pedi),  .peso (node11_peso),
        .pero     (node11_pero),  .pedo (node11_pedo)
    );

    // node21: (x=2, y=1) interior
    gold_router_xystd #(.ROUTER_X(8'd2), .ROUTER_Y(8'd1)) router_x2y1 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node21_polarity),
        // North ? (2,2) south
        .nsi      (so_s_x2y2),   .nri  (ro_s_x2y2),
        .ndi      (do_s_x2y2),   .nso  (so_n_x2y1),
        .nro      (ro_n_x2y1),   .ndo  (do_n_x2y1),
        // South ? (2,0) north
        .ssi      (so_n_x2y0),   .sri  (ro_n_x2y0),
        .sdi      (do_n_x2y0),   .sso  (so_s_x2y1),
        .sro      (ro_s_x2y1),   .sdo  (do_s_x2y1),
        // East ? (3,1) west
        .esi      (so_w_x3y1),   .eri  (ro_w_x3y1),
        .edi      (do_w_x3y1),   .eso  (so_e_x2y1),
        .ero      (ro_e_x2y1),   .edo  (do_e_x2y1),
        // West ? (1,1) east
        .wsi      (so_e_x1y1),   .wri  (ro_e_x1y1),
        .wdi      (do_e_x1y1),   .wso  (so_w_x2y1),
        .wro      (ro_w_x2y1),   .wdo  (do_w_x2y1),
        // PE
        .pesi     (node21_pesi),  .peri (node21_peri),
        .pedi     (node21_pedi),  .peso (node21_peso),
        .pero     (node21_pero),  .pedo (node21_pedo)
    );

    // node31: (x=3, y=1) right edge
    // East: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd3), .ROUTER_Y(8'd1)) router_x3y1 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node31_polarity),
        // North ? (3,2) south
        .nsi      (so_s_x3y2),   .nri  (ro_s_x3y2),
        .ndi      (do_s_x3y2),   .nso  (so_n_x3y1),
        .nro      (ro_n_x3y1),   .ndo  (do_n_x3y1),
        // South ? (3,0) north
        .ssi      (so_n_x3y0),   .sri  (ro_n_x3y0),
        .sdi      (do_n_x3y0),   .sso  (so_s_x3y1),
        .sro      (ro_s_x3y1),   .sdo  (do_s_x3y1),
        // East -- TIED OFF
        .esi      (1'b0),         .eri  (),
        .edi      (64'b0),        .eso  (),
        .ero      (1'b1),         .edo  (),
        // West ? (2,1) east
        .wsi      (so_e_x2y1),   .wri  (ro_e_x2y1),
        .wdi      (do_e_x2y1),   .wso  (so_w_x3y1),
        .wro      (ro_w_x3y1),   .wdo  (do_w_x3y1),
        // PE
        .pesi     (node31_pesi),  .peri (node31_peri),
        .pedi     (node31_pedi),  .peso (node31_peso),
        .pero     (node31_pero),  .pedo (node31_pedo)
    );

    // ----------------------------------------------------------
    // ROW y=2
    // ----------------------------------------------------------

    // node02: (x=0, y=2) left edge
    // West: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd0), .ROUTER_Y(8'd2)) router_x0y2 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node02_polarity),
        // North ? (0,3) south
        .nsi      (so_s_x0y3),   .nri  (ro_s_x0y3),
        .ndi      (do_s_x0y3),   .nso  (so_n_x0y2),
        .nro      (ro_n_x0y2),   .ndo  (do_n_x0y2),
        // South ? (0,1) north
        .ssi      (so_n_x0y1),   .sri  (ro_n_x0y1),
        .sdi      (do_n_x0y1),   .sso  (so_s_x0y2),
        .sro      (ro_s_x0y2),   .sdo  (do_s_x0y2),
        // East ? (1,2) west
        .esi      (so_w_x1y2),   .eri  (ro_w_x1y2),
        .edi      (do_w_x1y2),   .eso  (so_e_x0y2),
        .ero      (ro_e_x0y2),   .edo  (do_e_x0y2),
        // West -- TIED OFF
        .wsi      (1'b0),         .wri  (),
        .wdi      (64'b0),        .wso  (),
        .wro      (1'b1),         .wdo  (),
        // PE
        .pesi     (node02_pesi),  .peri (node02_peri),
        .pedi     (node02_pedi),  .peso (node02_peso),
        .pero     (node02_pero),  .pedo (node02_pedo)
    );

    // node12: (x=1, y=2) interior
    gold_router_xystd #(.ROUTER_X(8'd1), .ROUTER_Y(8'd2)) router_x1y2 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node12_polarity),
        // North ? (1,3) south
        .nsi      (so_s_x1y3),   .nri  (ro_s_x1y3),
        .ndi      (do_s_x1y3),   .nso  (so_n_x1y2),
        .nro      (ro_n_x1y2),   .ndo  (do_n_x1y2),
        // South ? (1,1) north
        .ssi      (so_n_x1y1),   .sri  (ro_n_x1y1),
        .sdi      (do_n_x1y1),   .sso  (so_s_x1y2),
        .sro      (ro_s_x1y2),   .sdo  (do_s_x1y2),
        // East ? (2,2) west
        .esi      (so_w_x2y2),   .eri  (ro_w_x2y2),
        .edi      (do_w_x2y2),   .eso  (so_e_x1y2),
        .ero      (ro_e_x1y2),   .edo  (do_e_x1y2),
        // West ? (0,2) east
        .wsi      (so_e_x0y2),   .wri  (ro_e_x0y2),
        .wdi      (do_e_x0y2),   .wso  (so_w_x1y2),
        .wro      (ro_w_x1y2),   .wdo  (do_w_x1y2),
        // PE
        .pesi     (node12_pesi),  .peri (node12_peri),
        .pedi     (node12_pedi),  .peso (node12_peso),
        .pero     (node12_pero),  .pedo (node12_pedo)
    );

    // node22: (x=2, y=2) interior
    gold_router_xystd #(.ROUTER_X(8'd2), .ROUTER_Y(8'd2)) router_x2y2 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node22_polarity),
        // North ? (2,3) south
        .nsi      (so_s_x2y3),   .nri  (ro_s_x2y3),
        .ndi      (do_s_x2y3),   .nso  (so_n_x2y2),
        .nro      (ro_n_x2y2),   .ndo  (do_n_x2y2),
        // South ? (2,1) north
        .ssi      (so_n_x2y1),   .sri  (ro_n_x2y1),
        .sdi      (do_n_x2y1),   .sso  (so_s_x2y2),
        .sro      (ro_s_x2y2),   .sdo  (do_s_x2y2),
        // East ? (3,2) west
        .esi      (so_w_x3y2),   .eri  (ro_w_x3y2),
        .edi      (do_w_x3y2),   .eso  (so_e_x2y2),
        .ero      (ro_e_x2y2),   .edo  (do_e_x2y2),
        // West ? (1,2) east
        .wsi      (so_e_x1y2),   .wri  (ro_e_x1y2),
        .wdi      (do_e_x1y2),   .wso  (so_w_x2y2),
        .wro      (ro_w_x2y2),   .wdo  (do_w_x2y2),
        // PE
        .pesi     (node22_pesi),  .peri (node22_peri),
        .pedi     (node22_pedi),  .peso (node22_peso),
        .pero     (node22_pero),  .pedo (node22_pedo)
    );

    // node32: (x=3, y=2) right edge
    // East: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd3), .ROUTER_Y(8'd2)) router_x3y2 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node32_polarity),
        // North ? (3,3) south
        .nsi      (so_s_x3y3),   .nri  (ro_s_x3y3),
        .ndi      (do_s_x3y3),   .nso  (so_n_x3y2),
        .nro      (ro_n_x3y2),   .ndo  (do_n_x3y2),
        // South ? (3,1) north
        .ssi      (so_n_x3y1),   .sri  (ro_n_x3y1),
        .sdi      (do_n_x3y1),   .sso  (so_s_x3y2),
        .sro      (ro_s_x3y2),   .sdo  (do_s_x3y2),
        // East -- TIED OFF
        .esi      (1'b0),         .eri  (),
        .edi      (64'b0),        .eso  (),
        .ero      (1'b1),         .edo  (),
        // West ? (2,2) east
        .wsi      (so_e_x2y2),   .wri  (ro_e_x2y2),
        .wdi      (do_e_x2y2),   .wso  (so_w_x3y2),
        .wro      (ro_w_x3y2),   .wdo  (do_w_x3y2),
        // PE
        .pesi     (node32_pesi),  .peri (node32_peri),
        .pedi     (node32_pedi),  .peso (node32_peso),
        .pero     (node32_pero),  .pedo (node32_pedo)
    );

    // ----------------------------------------------------------
    // ROW y=3 -- Top row
    // North ports ALL tied off (top grid edge)
    // ----------------------------------------------------------

    // node03: (x=0, y=3) top-left corner
    // North: TIED OFF | West: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd0), .ROUTER_Y(8'd3)) router_x0y3 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node03_polarity),
        // North -- TIED OFF
        .nsi      (1'b0),         .nri  (),
        .ndi      (64'b0),        .nso  (),
        .nro      (1'b1),         .ndo  (),
        // South ? (0,2) north
        .ssi      (so_n_x0y2),   .sri  (ro_n_x0y2),
        .sdi      (do_n_x0y2),   .sso  (so_s_x0y3),
        .sro      (ro_s_x0y3),   .sdo  (do_s_x0y3),
        // East ? (1,3) west
        .esi      (so_w_x1y3),   .eri  (ro_w_x1y3),
        .edi      (do_w_x1y3),   .eso  (so_e_x0y3),
        .ero      (ro_e_x0y3),   .edo  (do_e_x0y3),
        // West -- TIED OFF
        .wsi      (1'b0),         .wri  (),
        .wdi      (64'b0),        .wso  (),
        .wro      (1'b1),         .wdo  (),
        // PE
        .pesi     (node03_pesi),  .peri (node03_peri),
        .pedi     (node03_pedi),  .peso (node03_peso),
        .pero     (node03_pero),  .pedo (node03_pedo)
    );

    // node13: (x=1, y=3) top edge
    // North: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd1), .ROUTER_Y(8'd3)) router_x1y3 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node13_polarity),
        // North -- TIED OFF
        .nsi      (1'b0),         .nri  (),
        .ndi      (64'b0),        .nso  (),
        .nro      (1'b1),         .ndo  (),
        // South ? (1,2) north
        .ssi      (so_n_x1y2),   .sri  (ro_n_x1y2),
        .sdi      (do_n_x1y2),   .sso  (so_s_x1y3),
        .sro      (ro_s_x1y3),   .sdo  (do_s_x1y3),
        // East ? (2,3) west
        .esi      (so_w_x2y3),   .eri  (ro_w_x2y3),
        .edi      (do_w_x2y3),   .eso  (so_e_x1y3),
        .ero      (ro_e_x1y3),   .edo  (do_e_x1y3),
        // West ? (0,3) east
        .wsi      (so_e_x0y3),   .wri  (ro_e_x0y3),
        .wdi      (do_e_x0y3),   .wso  (so_w_x1y3),
        .wro      (ro_w_x1y3),   .wdo  (do_w_x1y3),
        // PE
        .pesi     (node13_pesi),  .peri (node13_peri),
        .pedi     (node13_pedi),  .peso (node13_peso),
        .pero     (node13_pero),  .pedo (node13_pedo)
    );

    // node23: (x=2, y=3) top edge
    // North: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd2), .ROUTER_Y(8'd3)) router_x2y3 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node23_polarity),
        // North -- TIED OFF
        .nsi      (1'b0),         .nri  (),
        .ndi      (64'b0),        .nso  (),
        .nro      (1'b1),         .ndo  (),
        // South ? (2,2) north
        .ssi      (so_n_x2y2),   .sri  (ro_n_x2y2),
        .sdi      (do_n_x2y2),   .sso  (so_s_x2y3),
        .sro      (ro_s_x2y3),   .sdo  (do_s_x2y3),
        // East ? (3,3) west
        .esi      (so_w_x3y3),   .eri  (ro_w_x3y3),
        .edi      (do_w_x3y3),   .eso  (so_e_x2y3),
        .ero      (ro_e_x2y3),   .edo  (do_e_x2y3),
        // West ? (1,3) east
        .wsi      (so_e_x1y3),   .wri  (ro_e_x1y3),
        .wdi      (do_e_x1y3),   .wso  (so_w_x2y3),
        .wro      (ro_w_x2y3),   .wdo  (do_w_x2y3),
        // PE
        .pesi     (node23_pesi),  .peri (node23_peri),
        .pedi     (node23_pedi),  .peso (node23_peso),
        .pero     (node23_pero),  .pedo (node23_pedo)
    );

    // node33: (x=3, y=3) top-right corner
    // North: TIED OFF | East: TIED OFF
    gold_router_xystd #(.ROUTER_X(8'd3), .ROUTER_Y(8'd3)) router_x3y3 (
        .clk      (clk),
        .reset    (reset),
        .polarity (node33_polarity),
        // North -- TIED OFF
        .nsi      (1'b0),         .nri  (),
        .ndi      (64'b0),        .nso  (),
        .nro      (1'b1),         .ndo  (),
        // South ? (3,2) north
        .ssi      (so_n_x3y2),   .sri  (ro_n_x3y2),
        .sdi      (do_n_x3y2),   .sso  (so_s_x3y3),
        .sro      (ro_s_x3y3),   .sdo  (do_s_x3y3),
        // East -- TIED OFF
        .esi      (1'b0),         .eri  (),
        .edi      (64'b0),        .eso  (),
        .ero      (1'b1),         .edo  (),
        // West ? (2,3) east
        .wsi      (so_e_x2y3),   .wri  (ro_e_x2y3),
        .wdi      (do_e_x2y3),   .wso  (so_w_x3y3),
        .wro      (ro_w_x3y3),   .wdo  (do_w_x3y3),
        // PE
        .pesi     (node33_pesi),  .peri (node33_peri),
        .pedi     (node33_pedi),  .peso (node33_peso),
        .pero     (node33_pero),  .pedo (node33_pedo)
    );

endmodule
