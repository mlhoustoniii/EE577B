/////////////////////////////////////////////////////////////////////
// Project      : EE577B Spring2026 Cardinal CMP - Phase 3
// Filename     : cardinal_cmp.v
// Description  : Top-level 16-core multiprocessor (cardinal_cmp).
//
//   Instantiates:
//     - One cardinal_mesh   : 4x4 router grid (renamed from gold_mesh)
//     - Sixteen cardinal_node modules, one per mesh PE port
//
//   NODE_ID assignment (row-major, per Phase3_Workflow.md §3):
//     NODE_ID = Y*4 + X    (X = column 0-3, Y = row 0-3)
//
//     (X=0,Y=0)->0  (X=1,Y=0)->1  (X=2,Y=0)->2  (X=3,Y=0)->3
//     (X=0,Y=1)->4  (X=1,Y=1)->5  (X=2,Y=1)->6  (X=3,Y=1)->7
//     (X=0,Y=2)->8  (X=1,Y=2)->9  (X=2,Y=2)->10 (X=3,Y=2)->11
//     (X=0,Y=3)->12 (X=1,Y=3)->13 (X=2,Y=3)->14 (X=3,Y=3)->15
//
//   Port naming on cardinal_mesh follows gold_mesh.v convention:
//     nodeXY_pesi  : node  -> router  send (input  to mesh)
//     nodeXY_peri  : router -> node   ready (output from mesh)
//     nodeXY_pedi  : node  -> router  data  (input  to mesh)
//     nodeXY_peso  : router -> node   send  (output from mesh)
//     nodeXY_pero  : node  -> router  ready (input  to mesh)
//     nodeXY_pedo  : router -> node   data  (output from mesh)
//     nodeXY_polarity : router polarity   (output from mesh)
//
//   The cardinal_node wrapper port names (pesi/peri/pedi/peso/pero/
//   pedo/polarity) map 1-to-1 to the mesh PE ports above.
//
//   I/O: clk and reset only — all state is internal.
/////////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module cardinal_cmp (
    input wire clk,
    input wire reset
);

    // ============================================================
    //  Mesh PE wires — one bundle per node (X,Y)
    //  Naming: w_nodeXY_<signal>
    // ============================================================

    // -- Row y=0 --
    wire        w_node00_pesi, w_node00_peri, w_node00_peso, w_node00_pero, w_node00_polarity;
    wire [63:0] w_node00_pedi, w_node00_pedo;

    wire        w_node10_pesi, w_node10_peri, w_node10_peso, w_node10_pero, w_node10_polarity;
    wire [63:0] w_node10_pedi, w_node10_pedo;

    wire        w_node20_pesi, w_node20_peri, w_node20_peso, w_node20_pero, w_node20_polarity;
    wire [63:0] w_node20_pedi, w_node20_pedo;

    wire        w_node30_pesi, w_node30_peri, w_node30_peso, w_node30_pero, w_node30_polarity;
    wire [63:0] w_node30_pedi, w_node30_pedo;

    // -- Row y=1 --
    wire        w_node01_pesi, w_node01_peri, w_node01_peso, w_node01_pero, w_node01_polarity;
    wire [63:0] w_node01_pedi, w_node01_pedo;

    wire        w_node11_pesi, w_node11_peri, w_node11_peso, w_node11_pero, w_node11_polarity;
    wire [63:0] w_node11_pedi, w_node11_pedo;

    wire        w_node21_pesi, w_node21_peri, w_node21_peso, w_node21_pero, w_node21_polarity;
    wire [63:0] w_node21_pedi, w_node21_pedo;

    wire        w_node31_pesi, w_node31_peri, w_node31_peso, w_node31_pero, w_node31_polarity;
    wire [63:0] w_node31_pedi, w_node31_pedo;

    // -- Row y=2 --
    wire        w_node02_pesi, w_node02_peri, w_node02_peso, w_node02_pero, w_node02_polarity;
    wire [63:0] w_node02_pedi, w_node02_pedo;

    wire        w_node12_pesi, w_node12_peri, w_node12_peso, w_node12_pero, w_node12_polarity;
    wire [63:0] w_node12_pedi, w_node12_pedo;

    wire        w_node22_pesi, w_node22_peri, w_node22_peso, w_node22_pero, w_node22_polarity;
    wire [63:0] w_node22_pedi, w_node22_pedo;

    wire        w_node32_pesi, w_node32_peri, w_node32_peso, w_node32_pero, w_node32_polarity;
    wire [63:0] w_node32_pedi, w_node32_pedo;

    // -- Row y=3 --
    wire        w_node03_pesi, w_node03_peri, w_node03_peso, w_node03_pero, w_node03_polarity;
    wire [63:0] w_node03_pedi, w_node03_pedo;

    wire        w_node13_pesi, w_node13_peri, w_node13_peso, w_node13_pero, w_node13_polarity;
    wire [63:0] w_node13_pedi, w_node13_pedo;

    wire        w_node23_pesi, w_node23_peri, w_node23_peso, w_node23_pero, w_node23_polarity;
    wire [63:0] w_node23_pedi, w_node23_pedo;

    wire        w_node33_pesi, w_node33_peri, w_node33_peso, w_node33_pero, w_node33_polarity;
    wire [63:0] w_node33_pedi, w_node33_pedo;

    // ============================================================
    //  cardinal_mesh instantiation (4x4 router grid)
    //  Module name is cardinal_mesh (renamed from gold_mesh)
    // ============================================================
    cardinal_mesh u_mesh (
        .clk    (clk),
        .reset  (reset),

        // -- Row y=0 --
        .node00_pesi     (w_node00_pesi),
        .node00_peri     (w_node00_peri),
        .node00_pedi     (w_node00_pedi),
        .node00_peso     (w_node00_peso),
        .node00_pero     (w_node00_pero),
        .node00_pedo     (w_node00_pedo),
        .node00_polarity (w_node00_polarity),

        .node10_pesi     (w_node10_pesi),
        .node10_peri     (w_node10_peri),
        .node10_pedi     (w_node10_pedi),
        .node10_peso     (w_node10_peso),
        .node10_pero     (w_node10_pero),
        .node10_pedo     (w_node10_pedo),
        .node10_polarity (w_node10_polarity),

        .node20_pesi     (w_node20_pesi),
        .node20_peri     (w_node20_peri),
        .node20_pedi     (w_node20_pedi),
        .node20_peso     (w_node20_peso),
        .node20_pero     (w_node20_pero),
        .node20_pedo     (w_node20_pedo),
        .node20_polarity (w_node20_polarity),

        .node30_pesi     (w_node30_pesi),
        .node30_peri     (w_node30_peri),
        .node30_pedi     (w_node30_pedi),
        .node30_peso     (w_node30_peso),
        .node30_pero     (w_node30_pero),
        .node30_pedo     (w_node30_pedo),
        .node30_polarity (w_node30_polarity),

        // -- Row y=1 --
        .node01_pesi     (w_node01_pesi),
        .node01_peri     (w_node01_peri),
        .node01_pedi     (w_node01_pedi),
        .node01_peso     (w_node01_peso),
        .node01_pero     (w_node01_pero),
        .node01_pedo     (w_node01_pedo),
        .node01_polarity (w_node01_polarity),

        .node11_pesi     (w_node11_pesi),
        .node11_peri     (w_node11_peri),
        .node11_pedi     (w_node11_pedi),
        .node11_peso     (w_node11_peso),
        .node11_pero     (w_node11_pero),
        .node11_pedo     (w_node11_pedo),
        .node11_polarity (w_node11_polarity),

        .node21_pesi     (w_node21_pesi),
        .node21_peri     (w_node21_peri),
        .node21_pedi     (w_node21_pedi),
        .node21_peso     (w_node21_peso),
        .node21_pero     (w_node21_pero),
        .node21_pedo     (w_node21_pedo),
        .node21_polarity (w_node21_polarity),

        .node31_pesi     (w_node31_pesi),
        .node31_peri     (w_node31_peri),
        .node31_pedi     (w_node31_pedi),
        .node31_peso     (w_node31_peso),
        .node31_pero     (w_node31_pero),
        .node31_pedo     (w_node31_pedo),
        .node31_polarity (w_node31_polarity),

        // -- Row y=2 --
        .node02_pesi     (w_node02_pesi),
        .node02_peri     (w_node02_peri),
        .node02_pedi     (w_node02_pedi),
        .node02_peso     (w_node02_peso),
        .node02_pero     (w_node02_pero),
        .node02_pedo     (w_node02_pedo),
        .node02_polarity (w_node02_polarity),

        .node12_pesi     (w_node12_pesi),
        .node12_peri     (w_node12_peri),
        .node12_pedi     (w_node12_pedi),
        .node12_peso     (w_node12_peso),
        .node12_pero     (w_node12_pero),
        .node12_pedo     (w_node12_pedo),
        .node12_polarity (w_node12_polarity),

        .node22_pesi     (w_node22_pesi),
        .node22_peri     (w_node22_peri),
        .node22_pedi     (w_node22_pedi),
        .node22_peso     (w_node22_peso),
        .node22_pero     (w_node22_pero),
        .node22_pedo     (w_node22_pedo),
        .node22_polarity (w_node22_polarity),

        .node32_pesi     (w_node32_pesi),
        .node32_peri     (w_node32_peri),
        .node32_pedi     (w_node32_pedi),
        .node32_peso     (w_node32_peso),
        .node32_pero     (w_node32_pero),
        .node32_pedo     (w_node32_pedo),
        .node32_polarity (w_node32_polarity),

        // -- Row y=3 --
        .node03_pesi     (w_node03_pesi),
        .node03_peri     (w_node03_peri),
        .node03_pedi     (w_node03_pedi),
        .node03_peso     (w_node03_peso),
        .node03_pero     (w_node03_pero),
        .node03_pedo     (w_node03_pedo),
        .node03_polarity (w_node03_polarity),

        .node13_pesi     (w_node13_pesi),
        .node13_peri     (w_node13_peri),
        .node13_pedi     (w_node13_pedi),
        .node13_peso     (w_node13_peso),
        .node13_pero     (w_node13_pero),
        .node13_pedo     (w_node13_pedo),
        .node13_polarity (w_node13_polarity),

        .node23_pesi     (w_node23_pesi),
        .node23_peri     (w_node23_peri),
        .node23_pedi     (w_node23_pedi),
        .node23_peso     (w_node23_peso),
        .node23_pero     (w_node23_pero),
        .node23_pedo     (w_node23_pedo),
        .node23_polarity (w_node23_polarity),

        .node33_pesi     (w_node33_pesi),
        .node33_peri     (w_node33_peri),
        .node33_pedi     (w_node33_pedi),
        .node33_peso     (w_node33_peso),
        .node33_pero     (w_node33_pero),
        .node33_pedo     (w_node33_pedo),
        .node33_polarity (w_node33_polarity)
    );

    // ============================================================
    //  Sixteen cardinal_node instantiations
    //
    //  NODE_ID = Y*4 + X  (row-major, Y=row, X=column)
    //
    //  cardinal_node port mapping:
    //    polarity  <- mesh nodeXY_polarity  (output FROM mesh)
    //    pesi      -> mesh nodeXY_pesi      (input  TO   mesh)
    //    peri      <- mesh nodeXY_peri      (output FROM mesh)
    //    pedi      -> mesh nodeXY_pedi      (input  TO   mesh)
    //    peso      <- mesh nodeXY_peso      (output FROM mesh)
    //    pero      -> mesh nodeXY_pero      (input  TO   mesh)
    //    pedo      <- mesh nodeXY_pedo      (output FROM mesh)
    // ============================================================

    // -- Row y=0 --

    // node00  X=0, Y=0  ->  NODE_ID = 0*4+0 = 0
    cardinal_node #(.NODE_ID(6'd0)) node00 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node00_polarity),
        .pesi     (w_node00_pesi),
        .peri     (w_node00_peri),
        .pedi     (w_node00_pedi),
        .peso     (w_node00_peso),
        .pero     (w_node00_pero),
        .pedo     (w_node00_pedo)
    );

    // node10  X=1, Y=0  ->  NODE_ID = 0*4+1 = 1
    cardinal_node #(.NODE_ID(6'd1)) node10 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node10_polarity),
        .pesi     (w_node10_pesi),
        .peri     (w_node10_peri),
        .pedi     (w_node10_pedi),
        .peso     (w_node10_peso),
        .pero     (w_node10_pero),
        .pedo     (w_node10_pedo)
    );

    // node20  X=2, Y=0  ->  NODE_ID = 0*4+2 = 2
    cardinal_node #(.NODE_ID(6'd2)) node20 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node20_polarity),
        .pesi     (w_node20_pesi),
        .peri     (w_node20_peri),
        .pedi     (w_node20_pedi),
        .peso     (w_node20_peso),
        .pero     (w_node20_pero),
        .pedo     (w_node20_pedo)
    );

    // node30  X=3, Y=0  ->  NODE_ID = 0*4+3 = 3
    cardinal_node #(.NODE_ID(6'd3)) node30 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node30_polarity),
        .pesi     (w_node30_pesi),
        .peri     (w_node30_peri),
        .pedi     (w_node30_pedi),
        .peso     (w_node30_peso),
        .pero     (w_node30_pero),
        .pedo     (w_node30_pedo)
    );

    // -- Row y=1 --

    // node01  X=0, Y=1  ->  NODE_ID = 1*4+0 = 4
    cardinal_node #(.NODE_ID(6'd4)) node01 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node01_polarity),
        .pesi     (w_node01_pesi),
        .peri     (w_node01_peri),
        .pedi     (w_node01_pedi),
        .peso     (w_node01_peso),
        .pero     (w_node01_pero),
        .pedo     (w_node01_pedo)
    );

    // node11  X=1, Y=1  ->  NODE_ID = 1*4+1 = 5
    cardinal_node #(.NODE_ID(6'd5)) node11 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node11_polarity),
        .pesi     (w_node11_pesi),
        .peri     (w_node11_peri),
        .pedi     (w_node11_pedi),
        .peso     (w_node11_peso),
        .pero     (w_node11_pero),
        .pedo     (w_node11_pedo)
    );

    // node21  X=2, Y=1  ->  NODE_ID = 1*4+2 = 6
    cardinal_node #(.NODE_ID(6'd6)) node21 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node21_polarity),
        .pesi     (w_node21_pesi),
        .peri     (w_node21_peri),
        .pedi     (w_node21_pedi),
        .peso     (w_node21_peso),
        .pero     (w_node21_pero),
        .pedo     (w_node21_pedo)
    );

    // node31  X=3, Y=1  ->  NODE_ID = 1*4+3 = 7
    cardinal_node #(.NODE_ID(6'd7)) node31 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node31_polarity),
        .pesi     (w_node31_pesi),
        .peri     (w_node31_peri),
        .pedi     (w_node31_pedi),
        .peso     (w_node31_peso),
        .pero     (w_node31_pero),
        .pedo     (w_node31_pedo)
    );

    // -- Row y=2 --

    // node02  X=0, Y=2  ->  NODE_ID = 2*4+0 = 8
    cardinal_node #(.NODE_ID(6'd8)) node02 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node02_polarity),
        .pesi     (w_node02_pesi),
        .peri     (w_node02_peri),
        .pedi     (w_node02_pedi),
        .peso     (w_node02_peso),
        .pero     (w_node02_pero),
        .pedo     (w_node02_pedo)
    );

    // node12  X=1, Y=2  ->  NODE_ID = 2*4+1 = 9
    cardinal_node #(.NODE_ID(6'd9)) node12 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node12_polarity),
        .pesi     (w_node12_pesi),
        .peri     (w_node12_peri),
        .pedi     (w_node12_pedi),
        .peso     (w_node12_peso),
        .pero     (w_node12_pero),
        .pedo     (w_node12_pedo)
    );

    // node22  X=2, Y=2  ->  NODE_ID = 2*4+2 = 10
    cardinal_node #(.NODE_ID(6'd10)) node22 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node22_polarity),
        .pesi     (w_node22_pesi),
        .peri     (w_node22_peri),
        .pedi     (w_node22_pedi),
        .peso     (w_node22_peso),
        .pero     (w_node22_pero),
        .pedo     (w_node22_pedo)
    );

    // node32  X=3, Y=2  ->  NODE_ID = 2*4+3 = 11
    cardinal_node #(.NODE_ID(6'd11)) node32 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node32_polarity),
        .pesi     (w_node32_pesi),
        .peri     (w_node32_peri),
        .pedi     (w_node32_pedi),
        .peso     (w_node32_peso),
        .pero     (w_node32_pero),
        .pedo     (w_node32_pedo)
    );

    // -- Row y=3 --

    // node03  X=0, Y=3  ->  NODE_ID = 3*4+0 = 12
    cardinal_node #(.NODE_ID(6'd12)) node03 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node03_polarity),
        .pesi     (w_node03_pesi),
        .peri     (w_node03_peri),
        .pedi     (w_node03_pedi),
        .peso     (w_node03_peso),
        .pero     (w_node03_pero),
        .pedo     (w_node03_pedo)
    );

    // node13  X=1, Y=3  ->  NODE_ID = 3*4+1 = 13
    cardinal_node #(.NODE_ID(6'd13)) node13 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node13_polarity),
        .pesi     (w_node13_pesi),
        .peri     (w_node13_peri),
        .pedi     (w_node13_pedi),
        .peso     (w_node13_peso),
        .pero     (w_node13_pero),
        .pedo     (w_node13_pedo)
    );

    // node23  X=2, Y=3  ->  NODE_ID = 3*4+2 = 14
    cardinal_node #(.NODE_ID(6'd14)) node23 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node23_polarity),
        .pesi     (w_node23_pesi),
        .peri     (w_node23_peri),
        .pedi     (w_node23_pedi),
        .peso     (w_node23_peso),
        .pero     (w_node23_pero),
        .pedo     (w_node23_pedo)
    );

    // node33  X=3, Y=3  ->  NODE_ID = 3*4+3 = 15
    cardinal_node #(.NODE_ID(6'd15)) node33 (
        .clk      (clk),
        .reset    (reset),
        .polarity (w_node33_polarity),
        .pesi     (w_node33_pesi),
        .peri     (w_node33_peri),
        .pedi     (w_node33_pedi),
        .peso     (w_node33_peso),
        .pero     (w_node33_pero),
        .pedo     (w_node33_pedo)
    );

endmodule
