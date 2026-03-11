`timescale 1ns/1ps
// ============================================================
// tb_gold_mesh.v -- Cardinal 4x4 Mesh Comprehensive Testbench
// EE 577B VLSI Design Projects
//
// Test Cases:
//   TC1  : Reset verification -- peso=0, peri=1, polarity sequence
//   TC2  : Single hop East       node00(0,0)->node10(1,0)
//   TC3  : Single hop North      node00(0,0)->node01(0,1)
//   TC4  : Single hop West       node30(3,0)->node20(2,0)
//   TC5  : Single hop South      node03(0,3)->node02(0,2)
//   TC6  : 3-hop East            node00(0,0)->node30(3,0)
//   TC7  : 3-hop North           node00(0,0)->node03(0,3)
//   TC8  : Diagonal NE           node00(0,0)->node33(3,3)
//   TC9  : Diagonal SW           node33(3,3)->node00(0,0)
//   TC10 : Router-router handshake no blocking (back-to-back)
//   TC11 : Router-router handshake WITH blocking (pero toggled)
//   TC12 : Contention -- 4 senders -> node22 simultaneously
//   TC13 : Arbiter priority rotation -- contention 3 rounds
//   TC14 : Full 16-phase gather (all->node_k for k=0..15)
//
// Header format (64-bit):
//   [63]     = VC bit  (IGNORED by router Phase 1; set to 0)
//   [62]     = dirX    (0=East, 1=West)
//   [61]     = dirY    (0=South, 1=North)
//   [60:56]  = Reserved (always 5'b0)
//   [55:52]  = hopX    (unary: 0hop=4'h0, 1hop=4'h1,
//                              2hop=4'h3, 3hop=4'h7)
//   [51:48]  = hopY    (unary: same encoding)
//   [47:40]  = Source X (8-bit, set to sender column)
//   [39:32]  = Source Y (8-bit, set to sender row)
//   [31:0]   = Payload (32-bit)
//
// Injection rule:
//   input_ctrl writes even buffer when polarity=1 (odd cycle)
//   input_ctrl writes odd  buffer when polarity=0 (even cycle)
//   -> inject pesi on polarity=1 to write even VC buffer
//   -> peri must also be 1 (buffer not full) at injection time
//
// Node coordinate map (X=col, Y=row):
//   node00 node10 node20 node30   <- Y=0 (bottom)
//   node01 node11 node21 node31   <- Y=1
//   node02 node12 node22 node32   <- Y=2
//   node03 node13 node23 node33   <- Y=3 (top)
//
// Clock: 250 MHz -> period = 4 ns
// Reset: synchronous active-high; released at negedge clk
// ============================================================

module tb_gold_mesh_2;

    // ----------------------------------------------------------
    // Clock and timing
    // ----------------------------------------------------------
    parameter CLK_HALF   = 2;           // 2ns half-period -> 4ns full
    parameter RESET_CYC  = 6;           // Hold reset this many cycles
    parameter MAX_WAIT   = 200;         // Per-operation timeout (cycles)
    parameter NUM_NODES  = 16;

    reg clk;
    reg reset;

    initial  clk = 1'b0;
    always #(CLK_HALF) clk = ~clk;

    // ----------------------------------------------------------
    // DUT interface signals -- 16 nodes x 7 signals
    // All declared as per gold_mesh.v port list
    // ----------------------------------------------------------

    // ---- PE send-in (TB drives -> router) ----
    reg  node00_pesi, node10_pesi, node20_pesi, node30_pesi;
    reg  node01_pesi, node11_pesi, node21_pesi, node31_pesi;
    reg  node02_pesi, node12_pesi, node22_pesi, node32_pesi;
    reg  node03_pesi, node13_pesi, node23_pesi, node33_pesi;

    // ---- PE ready-in (router -> TB: 1=buffer empty) ----
    wire node00_peri, node10_peri, node20_peri, node30_peri;
    wire node01_peri, node11_peri, node21_peri, node31_peri;
    wire node02_peri, node12_peri, node22_peri, node32_peri;
    wire node03_peri, node13_peri, node23_peri, node33_peri;

    // ---- PE data-in (TB drives -> router) ----
    reg  [63:0] node00_pedi, node10_pedi, node20_pedi, node30_pedi;
    reg  [63:0] node01_pedi, node11_pedi, node21_pedi, node31_pedi;
    reg  [63:0] node02_pedi, node12_pedi, node22_pedi, node32_pedi;
    reg  [63:0] node03_pedi, node13_pedi, node23_pedi, node33_pedi;

    // ---- PE send-out (router -> TB: 1=packet arrived) ----
    wire node00_peso, node10_peso, node20_peso, node30_peso;
    wire node01_peso, node11_peso, node21_peso, node31_peso;
    wire node02_peso, node12_peso, node22_peso, node32_peso;
    wire node03_peso, node13_peso, node23_peso, node33_peso;

    // ---- PE ready-out (TB drives -> router: 1=PE can accept) ----
    reg  node00_pero, node10_pero, node20_pero, node30_pero;
    reg  node01_pero, node11_pero, node21_pero, node31_pero;
    reg  node02_pero, node12_pero, node22_pero, node32_pero;
    reg  node03_pero, node13_pero, node23_pero, node33_pero;

    // ---- PE data-out (router -> TB: arriving packet) ----
    wire [63:0] node00_pedo, node10_pedo, node20_pedo, node30_pedo;
    wire [63:0] node01_pedo, node11_pedo, node21_pedo, node31_pedo;
    wire [63:0] node02_pedo, node12_pedo, node22_pedo, node32_pedo;
    wire [63:0] node03_pedo, node13_pedo, node23_pedo, node33_pedo;

    // ---- Router polarity outputs ----
    wire node00_polarity, node10_polarity, node20_polarity, node30_polarity;
    wire node01_polarity, node11_polarity, node21_polarity, node31_polarity;
    wire node02_polarity, node12_polarity, node22_polarity, node32_polarity;
    wire node03_polarity, node13_polarity, node23_polarity, node33_polarity;

    // ----------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------
    gold_mesh dut (
        .clk             (clk),   .reset           (reset),
        .node00_pesi     (node00_pesi),  .node00_peri (node00_peri),
        .node00_pedi     (node00_pedi),  .node00_peso (node00_peso),
        .node00_pero     (node00_pero),  .node00_pedo (node00_pedo),
        .node00_polarity (node00_polarity),
        .node10_pesi     (node10_pesi),  .node10_peri (node10_peri),
        .node10_pedi     (node10_pedi),  .node10_peso (node10_peso),
        .node10_pero     (node10_pero),  .node10_pedo (node10_pedo),
        .node10_polarity (node10_polarity),
        .node20_pesi     (node20_pesi),  .node20_peri (node20_peri),
        .node20_pedi     (node20_pedi),  .node20_peso (node20_peso),
        .node20_pero     (node20_pero),  .node20_pedo (node20_pedo),
        .node20_polarity (node20_polarity),
        .node30_pesi     (node30_pesi),  .node30_peri (node30_peri),
        .node30_pedi     (node30_pedi),  .node30_peso (node30_peso),
        .node30_pero     (node30_pero),  .node30_pedo (node30_pedo),
        .node30_polarity (node30_polarity),
        .node01_pesi     (node01_pesi),  .node01_peri (node01_peri),
        .node01_pedi     (node01_pedi),  .node01_peso (node01_peso),
        .node01_pero     (node01_pero),  .node01_pedo (node01_pedo),
        .node01_polarity (node01_polarity),
        .node11_pesi     (node11_pesi),  .node11_peri (node11_peri),
        .node11_pedi     (node11_pedi),  .node11_peso (node11_peso),
        .node11_pero     (node11_pero),  .node11_pedo (node11_pedo),
        .node11_polarity (node11_polarity),
        .node21_pesi     (node21_pesi),  .node21_peri (node21_peri),
        .node21_pedi     (node21_pedi),  .node21_peso (node21_peso),
        .node21_pero     (node21_pero),  .node21_pedo (node21_pedo),
        .node21_polarity (node21_polarity),
        .node31_pesi     (node31_pesi),  .node31_peri (node31_peri),
        .node31_pedi     (node31_pedi),  .node31_peso (node31_peso),
        .node31_pero     (node31_pero),  .node31_pedo (node31_pedo),
        .node31_polarity (node31_polarity),
        .node02_pesi     (node02_pesi),  .node02_peri (node02_peri),
        .node02_pedi     (node02_pedi),  .node02_peso (node02_peso),
        .node02_pero     (node02_pero),  .node02_pedo (node02_pedo),
        .node02_polarity (node02_polarity),
        .node12_pesi     (node12_pesi),  .node12_peri (node12_peri),
        .node12_pedi     (node12_pedi),  .node12_peso (node12_peso),
        .node12_pero     (node12_pero),  .node12_pedo (node12_pedo),
        .node12_polarity (node12_polarity),
        .node22_pesi     (node22_pesi),  .node22_peri (node22_peri),
        .node22_pedi     (node22_pedi),  .node22_peso (node22_peso),
        .node22_pero     (node22_pero),  .node22_pedo (node22_pedo),
        .node22_polarity (node22_polarity),
        .node32_pesi     (node32_pesi),  .node32_peri (node32_peri),
        .node32_pedi     (node32_pedi),  .node32_peso (node32_peso),
        .node32_pero     (node32_pero),  .node32_pedo (node32_pedo),
        .node32_polarity (node32_polarity),
        .node03_pesi     (node03_pesi),  .node03_peri (node03_peri),
        .node03_pedi     (node03_pedi),  .node03_peso (node03_peso),
        .node03_pero     (node03_pero),  .node03_pedo (node03_pedo),
        .node03_polarity (node03_polarity),
        .node13_pesi     (node13_pesi),  .node13_peri (node13_peri),
        .node13_pedi     (node13_pedi),  .node13_peso (node13_peso),
        .node13_pero     (node13_pero),  .node13_pedo (node13_pedo),
        .node13_polarity (node13_polarity),
        .node23_pesi     (node23_pesi),  .node23_peri (node23_peri),
        .node23_pedi     (node23_pedi),  .node23_peso (node23_peso),
        .node23_pero     (node23_pero),  .node23_pedo (node23_pedo),
        .node23_polarity (node23_polarity),
        .node33_pesi     (node33_pesi),  .node33_peri (node33_peri),
        .node33_pedi     (node33_pedi),  .node33_peso (node33_peso),
        .node33_pero     (node33_pero),  .node33_pedo (node33_pedo),
        .node33_polarity (node33_polarity)
    );

    // ----------------------------------------------------------
    // Node coordinate lookup tables (flat id -> X, Y)
    // flat_id = Y*4 + X  (row-major, matches spec Figure 2)
    //   id=0  -> (X=0,Y=0)=node00    id=4  -> (X=0,Y=1)=node01
    //   id=1  -> (X=1,Y=0)=node10    id=5  -> (X=1,Y=1)=node11
    //   id=2  -> (X=2,Y=0)=node20    id=6  -> (X=2,Y=1)=node21
    //   id=3  -> (X=3,Y=0)=node30    id=7  -> (X=3,Y=1)=node31
    //   id=8  -> (X=0,Y=2)=node02    id=12 -> (X=0,Y=3)=node03
    //   id=9  -> (X=1,Y=2)=node12    id=13 -> (X=1,Y=3)=node13
    //   id=10 -> (X=2,Y=2)=node22    id=14 -> (X=2,Y=3)=node23
    //   id=11 -> (X=3,Y=2)=node32    id=15 -> (X=3,Y=3)=node33
    // ----------------------------------------------------------
    integer NODE_X [0:15];
    integer NODE_Y [0:15];

    // ----------------------------------------------------------
    // Verification scoreboard and counters
    // ----------------------------------------------------------
    integer pass_count;
    integer fail_count;
    integer pkt_received [0:15];   // arrival counter per dest node
    integer pkt_expected [0:15];   // expected count per dest node
    integer seen [0:15][0:15];     // seen[dst][src]=1 once received
    integer current_phase;         // which gather phase is running (-1=none)

    // ----------------------------------------------------------
    // Output file handles (per spec submission requirements)
    // gather_phaseN.res  -- one per destination node
    // start_end_time.out -- phase timing log
    // ----------------------------------------------------------
    integer fh_phase [0:15];
    integer fh_time;

    // ----------------------------------------------------------
    // Utility: build 64-bit packet header from coordinates
    //
    //   vc=0 always (router ignores in Phase 1; even VC)
    //   dirX: 0=East (dst_x > src_x), 1=West (dst_x < src_x)
    //   dirY: 1=North(dst_y > src_y), 0=South(dst_y < src_y)
    //   hopX: unary encoding of |dst_x - src_x|
    //   hopY: unary encoding of |dst_y - src_y|
    //   src_x/src_y embedded for end-to-end verification
    // ----------------------------------------------------------
    function [3:0] encode_hops;
        input integer n;
        begin
            case (n)
                0:       encode_hops = 4'h0;  // 0000 -- no hops
                1:       encode_hops = 4'h1;  // 0001 -- 1 hop
                2:       encode_hops = 4'h3;  // 0011 -- 2 hops
                3:       encode_hops = 4'h7;  // 0111 -- 3 hops
                default: encode_hops = 4'h0;
            endcase
        end
    endfunction

    function [63:0] make_pkt;
        input integer src_x, src_y, dst_x, dst_y;
        input [31:0]  payload;
        integer dx, dy;
        reg     dirX, dirY;
        reg [3:0] hopX, hopY;
        begin
            dx   = dst_x - src_x;
            dy   = dst_y - src_y;

            dirX = (dx < 0) ? 1'b1 : 1'b0;    // 1=West, 0=East
            dirY = (dy > 0) ? 1'b1 : 1'b0;    // 1=North, 0=South

            hopX = encode_hops((dx < 0) ? -dx : dx);
            hopY = encode_hops((dy < 0) ? -dy : dy);

            make_pkt = {
                1'b0,           // [63]    VC=0 (even; ignored by router)
                dirX,           // [62]    direction X
                dirY,           // [61]    direction Y
                5'b00000,       // [60:56] reserved
                hopX,           // [55:52] X hops remaining
                hopY,           // [51:48] Y hops remaining
                src_x[7:0],     // [47:40] source X  (integer->8-bit, no promotion)
                src_y[7:0],     // [39:32] source Y  (integer->8-bit, no promotion)
                payload         // [31:0]  payload
            };
        end
    endfunction

    // ----------------------------------------------------------
    // Utility: read polarity signal of node (x,y)
    // ----------------------------------------------------------
    function get_polarity;
        input integer nx, ny;
        reg [3:0] id4;
        begin
            id4 = ny[1:0]*4 + nx[1:0];
            case (id4)
                4'd0:  get_polarity = node00_polarity;
                4'd1:  get_polarity = node10_polarity;
                4'd2:  get_polarity = node20_polarity;
                4'd3:  get_polarity = node30_polarity;
                4'd4:  get_polarity = node01_polarity;
                4'd5:  get_polarity = node11_polarity;
                4'd6:  get_polarity = node21_polarity;
                4'd7:  get_polarity = node31_polarity;
                4'd8:  get_polarity = node02_polarity;
                4'd9:  get_polarity = node12_polarity;
                4'd10: get_polarity = node22_polarity;
                4'd11: get_polarity = node32_polarity;
                4'd12: get_polarity = node03_polarity;
                4'd13: get_polarity = node13_polarity;
                4'd14: get_polarity = node23_polarity;
                4'd15: get_polarity = node33_polarity;
                default: get_polarity = 1'bx;
            endcase
        end
    endfunction

    // ----------------------------------------------------------
    // Utility: read peri signal of node (x,y)
    // ----------------------------------------------------------
    function get_peri;
        input integer nx, ny;
        reg [3:0] id4;
        begin
            id4 = ny[1:0]*4 + nx[1:0];
            case (id4)
                4'd0:  get_peri = node00_peri;
                4'd1:  get_peri = node10_peri;
                4'd2:  get_peri = node20_peri;
                4'd3:  get_peri = node30_peri;
                4'd4:  get_peri = node01_peri;
                4'd5:  get_peri = node11_peri;
                4'd6:  get_peri = node21_peri;
                4'd7:  get_peri = node31_peri;
                4'd8:  get_peri = node02_peri;
                4'd9:  get_peri = node12_peri;
                4'd10: get_peri = node22_peri;
                4'd11: get_peri = node32_peri;
                4'd12: get_peri = node03_peri;
                4'd13: get_peri = node13_peri;
                4'd14: get_peri = node23_peri;
                4'd15: get_peri = node33_peri;
                default: get_peri = 1'bx;
            endcase
        end
    endfunction

    // ----------------------------------------------------------
    // Utility: read peso of node (x,y)
    // ----------------------------------------------------------
    function get_peso;
        input integer nx, ny;
        reg [3:0] id4;
        begin
            id4 = ny[1:0]*4 + nx[1:0];
            case (id4)
                4'd0:  get_peso = node00_peso;
                4'd1:  get_peso = node10_peso;
                4'd2:  get_peso = node20_peso;
                4'd3:  get_peso = node30_peso;
                4'd4:  get_peso = node01_peso;
                4'd5:  get_peso = node11_peso;
                4'd6:  get_peso = node21_peso;
                4'd7:  get_peso = node31_peso;
                4'd8:  get_peso = node02_peso;
                4'd9:  get_peso = node12_peso;
                4'd10: get_peso = node22_peso;
                4'd11: get_peso = node32_peso;
                4'd12: get_peso = node03_peso;
                4'd13: get_peso = node13_peso;
                4'd14: get_peso = node23_peso;
                4'd15: get_peso = node33_peso;
                default: get_peso = 1'bx;
            endcase
        end
    endfunction

    // ----------------------------------------------------------
    // Utility: read pedo of node (x,y)
    // ----------------------------------------------------------
    function [63:0] get_pedo;
        input integer nx, ny;
        reg [3:0] id4;
        begin
            id4 = ny[1:0]*4 + nx[1:0];
            case (id4)
                4'd0:  get_pedo = node00_pedo;
                4'd1:  get_pedo = node10_pedo;
                4'd2:  get_pedo = node20_pedo;
                4'd3:  get_pedo = node30_pedo;
                4'd4:  get_pedo = node01_pedo;
                4'd5:  get_pedo = node11_pedo;
                4'd6:  get_pedo = node21_pedo;
                4'd7:  get_pedo = node31_pedo;
                4'd8:  get_pedo = node02_pedo;
                4'd9:  get_pedo = node12_pedo;
                4'd10: get_pedo = node22_pedo;
                4'd11: get_pedo = node32_pedo;
                4'd12: get_pedo = node03_pedo;
                4'd13: get_pedo = node13_pedo;
                4'd14: get_pedo = node23_pedo;
                4'd15: get_pedo = node33_pedo;
                default: get_pedo = 64'hx;
            endcase
        end
    endfunction

    // ----------------------------------------------------------
    // Task: assert/deassert pesi+pedi for a given node (x,y)
    // ----------------------------------------------------------
    task drive_pe_in;
        input integer nx, ny;
        input [63:0]  data;
        input         en;
        reg [3:0] id4;
        begin
            id4 = ny[1:0]*4 + nx[1:0];
            case (id4)
                4'd0:  begin node00_pesi=en; node00_pedi=data; end
                4'd1:  begin node10_pesi=en; node10_pedi=data; end
                4'd2:  begin node20_pesi=en; node20_pedi=data; end
                4'd3:  begin node30_pesi=en; node30_pedi=data; end
                4'd4:  begin node01_pesi=en; node01_pedi=data; end
                4'd5:  begin node11_pesi=en; node11_pedi=data; end
                4'd6:  begin node21_pesi=en; node21_pedi=data; end
                4'd7:  begin node31_pesi=en; node31_pedi=data; end
                4'd8:  begin node02_pesi=en; node02_pedi=data; end
                4'd9:  begin node12_pesi=en; node12_pedi=data; end
                4'd10: begin node22_pesi=en; node22_pedi=data; end
                4'd11: begin node32_pesi=en; node32_pedi=data; end
                4'd12: begin node03_pesi=en; node03_pedi=data; end
                4'd13: begin node13_pesi=en; node13_pedi=data; end
                4'd14: begin node23_pesi=en; node23_pedi=data; end
                4'd15: begin node33_pesi=en; node33_pedi=data; end
            endcase
        end
    endtask

    // ----------------------------------------------------------
    // Task: inject one packet into node(src_x, src_y)
    //
    // Protocol:
    //   1. Build packet header from source/dest coordinates
    //   2. Wait at negedge until polarity=1 AND peri=1
    //      (polarity=1 so write_en_even activates -> even VC buffer)
    //   3. Assert pesi+pedi for exactly ONE full cycle
    //   4. Deassert at next negedge
    //
    // The negedge-driven stimulus gives maximum setup time before
    // the following posedge latches the data into the VC buffer.
    // ----------------------------------------------------------
    task inject_pkt;
        input integer src_x, src_y, dst_x, dst_y;
        input [31:0]  payload;
        reg [63:0] pkt;
        integer    wcnt;
        begin
            pkt  = make_pkt(src_x, src_y, dst_x, dst_y, payload);
            wcnt = 0;

            // Align to a negedge first
            @(negedge clk);

            // Spin until correct polarity AND buffer empty
            while (!(get_polarity(src_x, src_y) === 1'b1 &&
                     get_peri(src_x, src_y)     === 1'b1)) begin
                @(negedge clk);
                wcnt = wcnt + 1;
                if (wcnt > MAX_WAIT) begin
                    $display("  TIMEOUT inject_pkt: node(%0d,%0d) @ %0t",
                             src_x, src_y, $time);
                    disable inject_pkt;
                end
            end

            // Drive data and assert send for one cycle
            drive_pe_in(src_x, src_y, pkt, 1'b1);
            @(negedge clk);
            drive_pe_in(src_x, src_y, 64'h0, 1'b0);
        end
    endtask

    // ----------------------------------------------------------
    // Task: block until a packet arrives at node(dst_x, dst_y)
    // Returns received packet value
    // ----------------------------------------------------------
    task wait_pkt;
        input  integer dst_x, dst_y;
        output [63:0]  pkt_out;
        integer wcnt;
        begin
            wcnt = 0;
            @(posedge clk);
            while (get_peso(dst_x, dst_y) !== 1'b1) begin
                @(posedge clk);
                wcnt = wcnt + 1;
                if (wcnt > MAX_WAIT) begin
                    $display("  TIMEOUT wait_pkt: node(%0d,%0d) @ %0t",
                             dst_x, dst_y, $time);
                    pkt_out = 64'hDEAD_BEEF_DEAD_BEEF;
                    disable wait_pkt;
                end
            end
            pkt_out = get_pedo(dst_x, dst_y);
        end
    endtask

    // ----------------------------------------------------------
    // Task: check one received packet and report pass/fail
    //
    // Checks:
    //   hopX[55:52] = 4'h0  (all X hops consumed)
    //   hopY[51:48] = 4'h0  (all Y hops consumed)
    //   srcX[47:40] = exp_src_x
    //   srcY[39:32] = exp_src_y
    //   payload[31:0] = exp_payload
    // ----------------------------------------------------------
    task check_pkt;
        input [63:0]  pkt;
        input integer exp_src_x, exp_src_y;
        input [31:0]  exp_payload;
        input integer tc_num;
        reg [3:0] rx_hopX, rx_hopY;
        reg [7:0] rx_srcX, rx_srcY;
        begin
            rx_hopX = pkt[55:52];
            rx_hopY = pkt[51:48];
            rx_srcX = pkt[47:40];
            rx_srcY = pkt[39:32];

            // hopX must be zero at destination
            if (rx_hopX === 4'h0) begin
                $display("  PASS [TC%0d] hopX=0 at dest", tc_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [TC%0d] hopX=%0h (expected 0)", tc_num, rx_hopX);
                fail_count = fail_count + 1;
            end

            // hopY must be zero at destination
            if (rx_hopY === 4'h0) begin
                $display("  PASS [TC%0d] hopY=0 at dest", tc_num);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [TC%0d] hopY=%0h (expected 0)", tc_num, rx_hopY);
                fail_count = fail_count + 1;
            end

            // Source X coordinate preserved
            if (rx_srcX === exp_src_x) begin
                $display("  PASS [TC%0d] srcX=%0d correct", tc_num, rx_srcX);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [TC%0d] srcX=%0d expected %0d",
                         tc_num, rx_srcX, exp_src_x);
                fail_count = fail_count + 1;
            end

            // Source Y coordinate preserved
            if (rx_srcY === exp_src_y) begin
                $display("  PASS [TC%0d] srcY=%0d correct", tc_num, rx_srcY);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [TC%0d] srcY=%0d expected %0d",
                         tc_num, rx_srcY, exp_src_y);
                fail_count = fail_count + 1;
            end

            // Payload preserved end-to-end
            if (pkt[31:0] === exp_payload) begin
                $display("  PASS [TC%0d] payload=0x%08h correct",
                         tc_num, exp_payload);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [TC%0d] payload=0x%08h expected 0x%08h",
                         tc_num, pkt[31:0], exp_payload);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ----------------------------------------------------------
    // Task: apply and release reset
    // Per spec: reset released at negedge clk
    // ----------------------------------------------------------
    task do_reset;
        integer i;
        begin
            reset = 1'b1;
            repeat(RESET_CYC) @(posedge clk);
            @(negedge clk);
            reset = 1'b0;
            $display("  Reset released at %0t ns", $time);
        end
    endtask

    // ----------------------------------------------------------
    // Task: drain -- wait N cycles for pipeline to clear
    // ----------------------------------------------------------
    task drain;
        input integer n;
        begin
            repeat(n) @(posedge clk);
        end
    endtask

    // ----------------------------------------------------------
    // Arrival monitor (combinational always block)
    // Fires every posedge during gather phases (current_phase >= 0)
    // Records arrivals into scoreboard for TC12-TC14 / TC14 gather
    // ----------------------------------------------------------
    integer   mon_x, mon_y, mon_id, mon_src_x, mon_src_y, mon_src_id;
    reg [63:0] mon_pkt;

    always @(posedge clk) begin : arrival_monitor
        if (!reset && current_phase >= 0) begin
            // Check all 16 nodes
            if (node00_peso) begin
                mon_pkt    = node00_pedo;
                mon_x      = 0; mon_y = 0;
                mon_id     = 0;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(0, 0, mon_pkt);
            end
            if (node10_peso) begin
                mon_pkt    = node10_pedo;
                mon_x      = 1; mon_y = 0;
                mon_id     = 1;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(1, 0, mon_pkt);
            end
            if (node20_peso) begin
                mon_pkt    = node20_pedo;
                mon_x      = 2; mon_y = 0;
                mon_id     = 2;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(2, 0, mon_pkt);
            end
            if (node30_peso) begin
                mon_pkt    = node30_pedo;
                mon_x      = 3; mon_y = 0;
                mon_id     = 3;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(3, 0, mon_pkt);
            end
            if (node01_peso) begin
                mon_pkt    = node01_pedo;
                mon_x      = 0; mon_y = 1;
                mon_id     = 4;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(0, 1, mon_pkt);
            end
            if (node11_peso) begin
                mon_pkt    = node11_pedo;
                mon_x      = 1; mon_y = 1;
                mon_id     = 5;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(1, 1, mon_pkt);
            end
            if (node21_peso) begin
                mon_pkt    = node21_pedo;
                mon_x      = 2; mon_y = 1;
                mon_id     = 6;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(2, 1, mon_pkt);
            end
            if (node31_peso) begin
                mon_pkt    = node31_pedo;
                mon_x      = 3; mon_y = 1;
                mon_id     = 7;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(3, 1, mon_pkt);
            end
            if (node02_peso) begin
                mon_pkt    = node02_pedo;
                mon_x      = 0; mon_y = 2;
                mon_id     = 8;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(0, 2, mon_pkt);
            end
            if (node12_peso) begin
                mon_pkt    = node12_pedo;
                mon_x      = 1; mon_y = 2;
                mon_id     = 9;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(1, 2, mon_pkt);
            end
            if (node22_peso) begin
                mon_pkt    = node22_pedo;
                mon_x      = 2; mon_y = 2;
                mon_id     = 10;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(2, 2, mon_pkt);
            end
            if (node32_peso) begin
                mon_pkt    = node32_pedo;
                mon_x      = 3; mon_y = 2;
                mon_id     = 11;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(3, 2, mon_pkt);
            end
            if (node03_peso) begin
                mon_pkt    = node03_pedo;
                mon_x      = 0; mon_y = 3;
                mon_id     = 12;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(0, 3, mon_pkt);
            end
            if (node13_peso) begin
                mon_pkt    = node13_pedo;
                mon_x      = 1; mon_y = 3;
                mon_id     = 13;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(1, 3, mon_pkt);
            end
            if (node23_peso) begin
                mon_pkt    = node23_pedo;
                mon_x      = 2; mon_y = 3;
                mon_id     = 14;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(2, 3, mon_pkt);
            end
            if (node33_peso) begin
                mon_pkt    = node33_pedo;
                mon_x      = 3; mon_y = 3;
                mon_id     = 15;
                mon_src_x  = mon_pkt[47:40];
                mon_src_y  = mon_pkt[39:32];
                mon_src_id = mon_src_y * 4 + mon_src_x;
                record_arrival(3, 3, mon_pkt);
            end
        end
    end

    // ----------------------------------------------------------
    // Task: record one arrival (called from monitor always block)
    // ----------------------------------------------------------
    task record_arrival;
        input integer dst_x, dst_y;
        input [63:0]  pkt;
        integer dst_id, src_id, sx, sy;
        begin
            dst_id = dst_y * 4 + dst_x;
            sx     = pkt[47:40];
            sy     = pkt[39:32];
            src_id = sy * 4 + sx;

            pkt_received[dst_id] = pkt_received[dst_id] + 1;

            // Verify hops exhausted
            if (pkt[55:52] !== 4'h0 || pkt[51:48] !== 4'h0) begin
                $display("  FAIL [Phase %0d] Hops not zero at dest(%0d,%0d)! hopX=%h hopY=%h from(%0d,%0d)",

                         current_phase, dst_x, dst_y,
                         pkt[55:52], pkt[51:48], sx, sy);
                fail_count = fail_count + 1;
            end else begin
                pass_count = pass_count + 1;
            end

            // Source tracking: mark this (dst,src) pair as seen
            // For TC14 completeness check (each source should appear exactly once).
            // For TC10/TC13 same src->dst retransmit: seen[][] already=1, that's OK.
            seen[dst_id][src_id] = 1;

            // Duplicate detection: only flag if we received MORE packets than expected.
            // This allows TC10 (3 pkts same src->dst) and TC13 round-2 reuse
            // without false DUPLICATE failures, while still catching true over-delivery.
            if (pkt_received[dst_id] > pkt_expected[dst_id]) begin
                $display("  FAIL [Phase %0d] OVERCOUNT at(%0d,%0d): got %0d expected %0d from(%0d,%0d)",
                         current_phase, dst_x, dst_y,
                         pkt_received[dst_id], pkt_expected[dst_id], sx, sy);
                fail_count = fail_count + 1;
            end

            // Log to gather result file
            $fdisplay(fh_phase[dst_id],
                "phase=%0d time=%0t dst=(%0d,%0d)[%0d] src=(%0d,%0d)[%0d] pkt=%h",

                current_phase, $time,
                dst_x, dst_y, dst_id,
                sx, sy, src_id, pkt);

            $display("  [Phase %0d | %0t] (%0d,%0d)<-(%0d,%0d) pkt=%h [%0d/%0d]",

                     current_phase, $time,
                     dst_x, dst_y, sx, sy,
                     pkt,
                     pkt_received[dst_id],
                     pkt_expected[dst_id]);
        end
    endtask

    // ----------------------------------------------------------
    // Task: wait for gather phase to drain completely
    // Polls pkt_received[dest] until it reaches pkt_expected[dest]
    // ----------------------------------------------------------
    task wait_phase_done;
        input integer dest_id;
        integer wcnt;
        begin
            wcnt = 0;
            while (pkt_received[dest_id] < pkt_expected[dest_id]) begin
                @(posedge clk);
                wcnt = wcnt + 1;
                if (wcnt > MAX_WAIT * 6) begin
                    $display("  TIMEOUT [Phase %0d] got %0d/%0d",
                             current_phase,
                             pkt_received[dest_id],
                             pkt_expected[dest_id]);
                    $fdisplay(fh_time,
                              "TIMEOUT Phase %0d: %0d/%0d",
                              current_phase,
                              pkt_received[dest_id],
                              pkt_expected[dest_id]);
                    fail_count = fail_count + 1;
                    disable wait_phase_done;
                end
            end
        end
    endtask

    // ----------------------------------------------------------
    // Task: reset all scoreboards and per-node counters
    // ----------------------------------------------------------
    task clear_scoreboard;
        integer i, j;
        begin
            for (i = 0; i < NUM_NODES; i = i + 1) begin
                pkt_received[i] = 0;
                pkt_expected[i] = 0;
                for (j = 0; j < NUM_NODES; j = j + 1)
                    seen[i][j] = 0;
            end
        end
    endtask

    // ----------------------------------------------------------
    // Task: set all pero to a given value
    // ----------------------------------------------------------
    task set_all_pero;
        input val;
        begin
            node00_pero=val; node10_pero=val; node20_pero=val; node30_pero=val;
            node01_pero=val; node11_pero=val; node21_pero=val; node31_pero=val;
            node02_pero=val; node12_pero=val; node22_pero=val; node32_pero=val;
            node03_pero=val; node13_pero=val; node23_pero=val; node33_pero=val;
        end
    endtask

    // ----------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------
    integer  i, j, p;
    reg [63:0] rx;

    initial begin
        // ---- Coordinate table ----
        NODE_X[0]=0;  NODE_Y[0]=0;    // node00
        NODE_X[1]=1;  NODE_Y[1]=0;    // node10
        NODE_X[2]=2;  NODE_Y[2]=0;    // node20
        NODE_X[3]=3;  NODE_Y[3]=0;    // node30
        NODE_X[4]=0;  NODE_Y[4]=1;    // node01
        NODE_X[5]=1;  NODE_Y[5]=1;    // node11
        NODE_X[6]=2;  NODE_Y[6]=1;    // node21
        NODE_X[7]=3;  NODE_Y[7]=1;    // node31
        NODE_X[8]=0;  NODE_Y[8]=2;    // node02
        NODE_X[9]=1;  NODE_Y[9]=2;    // node12
        NODE_X[10]=2; NODE_Y[10]=2;   // node22
        NODE_X[11]=3; NODE_Y[11]=2;   // node32
        NODE_X[12]=0; NODE_Y[12]=3;   // node03
        NODE_X[13]=1; NODE_Y[13]=3;   // node13
        NODE_X[14]=2; NODE_Y[14]=3;   // node23
        NODE_X[15]=3; NODE_Y[15]=3;   // node33

        // ---- Open output files ----
        fh_phase[0]  = $fopen("gather_phase0.res",  "w");
        fh_phase[1]  = $fopen("gather_phase1.res",  "w");
        fh_phase[2]  = $fopen("gather_phase2.res",  "w");
        fh_phase[3]  = $fopen("gather_phase3.res",  "w");
        fh_phase[4]  = $fopen("gather_phase4.res",  "w");
        fh_phase[5]  = $fopen("gather_phase5.res",  "w");
        fh_phase[6]  = $fopen("gather_phase6.res",  "w");
        fh_phase[7]  = $fopen("gather_phase7.res",  "w");
        fh_phase[8]  = $fopen("gather_phase8.res",  "w");
        fh_phase[9]  = $fopen("gather_phase9.res",  "w");
        fh_phase[10] = $fopen("gather_phase10.res", "w");
        fh_phase[11] = $fopen("gather_phase11.res", "w");
        fh_phase[12] = $fopen("gather_phase12.res", "w");
        fh_phase[13] = $fopen("gather_phase13.res", "w");
        fh_phase[14] = $fopen("gather_phase14.res", "w");
        fh_phase[15] = $fopen("gather_phase15.res", "w");
        fh_time      = $fopen("start_end_time.out", "w");

        // File headers
        for (i = 0; i < NUM_NODES; i = i + 1)
            $fdisplay(fh_phase[i],
                "// Cardinal Mesh Gather Results -- Dest node(%0d,%0d) id=%0d",

                NODE_X[i], NODE_Y[i], i);
        $fdisplay(fh_time, "// Cardinal 4x4 Mesh -- Phase Timing");
        $fdisplay(fh_time, "// ===================================");
        $fdisplay(fh_time, "// Sim start: %0t", $time);

        // ---- Waveform ----
        $dumpfile("tb_gold_mesh_2.vcd");
        $dumpvars(0, tb_gold_mesh_2);

        // ---- Init ----
        pass_count    = 0;
        fail_count    = 0;
        current_phase = -1;    // Disable arrival monitor during TC1-TC13
        clear_scoreboard;

        // All pesi deasserted, all pero asserted
        {node00_pesi, node10_pesi, node20_pesi, node30_pesi,
         node01_pesi, node11_pesi, node21_pesi, node31_pesi,
         node02_pesi, node12_pesi, node22_pesi, node32_pesi,
         node03_pesi, node13_pesi, node23_pesi, node33_pesi} = 16'h0000;

        {node00_pedi, node10_pedi, node20_pedi, node30_pedi,
         node01_pedi, node11_pedi, node21_pedi, node31_pedi,
         node02_pedi, node12_pedi, node22_pedi, node32_pedi,
         node03_pedi, node13_pedi, node23_pedi, node33_pedi} = 0;

        set_all_pero(1'b1);

        // =========================================================
        // TC1 -- RESET BEHAVIOR
        // Spec: all so=0 (peso=0), all ri=1 (peri=1) during reset
        //       polarity=0 during reset, toggles to 1 at first posedge
        // =========================================================
        $display("\n=== TC1: Reset Behavior ===");
        reset = 1'b1;

        // Check DURING reset (after first posedge to let flops settle)
        @(posedge clk); #0.1;

        // All peri must be 1 (Moore ri signal, reset forces buffers empty)
        if (node00_peri & node11_peri & node22_peri & node33_peri &
            node10_peri & node01_peri & node30_peri & node03_peri &
            node20_peri & node02_peri & node31_peri & node13_peri) begin
            $display("  PASS [TC1] All peri=1 during reset (buffers empty)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC1] Not all peri=1 during reset");
            fail_count = fail_count + 1;
        end

        // All peso must be 0 (so=0 per spec)
        if (!node00_peso & !node11_peso & !node22_peso & !node33_peso &
            !node10_peso & !node01_peso & !node30_peso & !node03_peso &
            !node20_peso & !node02_peso & !node31_peso & !node13_peso) begin
            $display("  PASS [TC1] All peso=0 during reset (so deasserted)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC1] Not all peso=0 during reset");
            fail_count = fail_count + 1;
        end

        // Polarity must be 0 during reset (per spec "initialized to 0")
        if (node00_polarity === 1'b0) begin
            $display("  PASS [TC1] polarity=0 during reset");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC1] polarity=%0b during reset (expected 0)",
                     node00_polarity);
            fail_count = fail_count + 1;
        end

        // Release reset at negedge (per spec requirement)
        repeat(RESET_CYC-1) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("  Reset released at %0t ns", $time);

        // First posedge after reset -- polarity toggles to 1
        @(posedge clk); #0.1;
        if (node00_polarity === 1'b1) begin
            $display("  PASS [TC1] polarity=1 at first posedge after reset");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC1] polarity=%0b at first posedge (expected 1)",
                     node00_polarity);
            fail_count = fail_count + 1;
        end

        // Second posedge -- polarity toggles back to 0
        @(posedge clk); #0.1;
        if (node00_polarity === 1'b0) begin
            $display("  PASS [TC1] polarity=0 at second posedge (toggles)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC1] polarity=%0b at second posedge (expected 0)",
                     node00_polarity);
            fail_count = fail_count + 1;
        end

        // peri still 1 after reset release
        if (node00_peri & node11_peri & node22_peri & node33_peri) begin
            $display("  PASS [TC1] peri=1 after reset release");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC1] peri not 1 after reset release");
            fail_count = fail_count + 1;
        end

        drain(2);

        // =========================================================
        // TC2 -- SINGLE HOP EAST: node00(0,0) -> node10(1,0)
        // Header: vc=0, dirX=0(E), dirY=0, hopX=4'h1, hopY=4'h0
        // Hop right-shift: 4'h1 -> 4'h0 at node10
        // =========================================================
        $display("\n=== TC2: Single Hop East  node00->node10 ===");
        inject_pkt(0, 0, 1, 0, 32'h00_00_00_02);

        wait_pkt(1, 0, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 0, 0, 32'h00_00_00_02, 2);
        drain(4);

        // =========================================================
        // TC3 -- SINGLE HOP NORTH: node00(0,0) -> node01(0,1)
        // Header: vc=0, dirX=0, dirY=1(N), hopX=4'h0, hopY=4'h1
        // =========================================================
        $display("\n=== TC3: Single Hop North node00->node01 ===");
        inject_pkt(0, 0, 0, 1, 32'h00_00_00_03);
        wait_pkt(0, 1, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 0, 0, 32'h00_00_00_03, 3);
        drain(4);

        // =========================================================
        // TC4 -- SINGLE HOP WEST: node30(3,0) -> node20(2,0)
        // Header: vc=0, dirX=1(W), dirY=0, hopX=4'h1, hopY=4'h0
        // =========================================================
        $display("\n=== TC4: Single Hop West  node30->node20 ===");
        inject_pkt(3, 0, 2, 0, 32'h00_00_00_04);
        wait_pkt(2, 0, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 3, 0, 32'h00_00_00_04, 4);
        drain(4);

        // =========================================================
        // TC5 -- SINGLE HOP SOUTH: node03(0,3) -> node02(0,2)
        // Header: vc=0, dirX=0, dirY=0(S), hopX=4'h0, hopY=4'h1
        // =========================================================
        $display("\n=== TC5: Single Hop South node03->node02 ===");
        inject_pkt(0, 3, 0, 2, 32'h00_00_00_05);
        wait_pkt(0, 2, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 0, 3, 32'h00_00_00_05, 5);
        drain(4);

        // =========================================================
        // TC6 -- 3-HOP EAST: node00(0,0) -> node30(3,0)
        // Header: dirX=0(E), hopX=4'h7(3 hops), hopY=4'h0
        // Hop shift trace: 4'h7 -> 4'h3 -> 4'h1 -> 4'h0 [OK]
        // =========================================================
        $display("\n=== TC6: 3-Hop East  node00->node30 ===");
        inject_pkt(0, 0, 3, 0, 32'h00_00_00_06);
        wait_pkt(3, 0, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 0, 0, 32'h00_00_00_06, 6);
        drain(4);

        // =========================================================
        // TC7 -- 3-HOP NORTH: node00(0,0) -> node03(0,3)
        // Header: dirY=1(N), hopX=4'h0, hopY=4'h7(3 hops)
        // Hop shift trace: 4'h7 -> 4'h3 -> 4'h1 -> 4'h0 [OK]
        // =========================================================
        $display("\n=== TC7: 3-Hop North node00->node03 ===");
        inject_pkt(0, 0, 0, 3, 32'h00_00_00_07);
        wait_pkt(0, 3, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 0, 0, 32'h00_00_00_07, 7);
        drain(4);

        // =========================================================
        // TC8 -- DIAGONAL NE: node00(0,0) -> node33(3,3)
        // XY order: X first -> 3 East hops, then 3 North hops
        // Header: dirX=0(E), dirY=1(N), hopX=4'h7, hopY=4'h7
        // Path: 00->10->20->30->31->32->33  (6 total hops)
        // =========================================================
        $display("\n=== TC8: Diagonal NE  node00->node33 ===");
        inject_pkt(0, 0, 3, 3, 32'h00_00_00_08);
        wait_pkt(3, 3, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 0, 0, 32'h00_00_00_08, 8);
        drain(4);

        // =========================================================
        // TC9 -- DIAGONAL SW: node33(3,3) -> node00(0,0)
        // XY order: X first -> 3 West hops, then 3 South hops
        // Header: dirX=1(W), dirY=0(S), hopX=4'h7, hopY=4'h7
        // Path: 33->23->13->03->02->01->00  (6 total hops)
        // =========================================================
        $display("\n=== TC9: Diagonal SW  node33->node00 ===");
        inject_pkt(3, 3, 0, 0, 32'h00_00_00_09);
        wait_pkt(0, 0, rx);
        $display("  Received: %h", rx);
        check_pkt(rx, 3, 3, 32'h00_00_00_09, 9);
        drain(4);

        // =========================================================
        // TC10 -- HANDSHAKE, NO BLOCKING
        // Three back-to-back packets: node00 -> node10
        // pero=1 always -- router can drain immediately
        // All three must arrive in order with no lost packets
        // =========================================================
        $display("\n=== TC10: Handshake No Blocking -- back-to-back ===");
        current_phase = 10; // Enable monitor to count arrivals
        clear_scoreboard;
        pkt_expected[1] = 3; // node10 flat id=1

        inject_pkt(0, 0, 1, 0, 32'hBB_00_00_01);
        inject_pkt(0, 0, 1, 0, 32'hBB_00_00_02);
        inject_pkt(0, 0, 1, 0, 32'hBB_00_00_03);

        wait_phase_done(1);
        if (pkt_received[1] === 3) begin
            $display("  PASS [TC10] All 3 back-to-back packets arrived");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC10] Only %0d/3 packets arrived",
                     pkt_received[1]);
            fail_count = fail_count + 1;
        end
        current_phase = -1;
        drain(4);

        // =========================================================
        // TC11 -- HANDSHAKE WITH BLOCKING
        // Inject packet from node20(2,0) -> node30(3,0)
        // Deassert node30_pero so packet stalls in output buffer
        // Verify peso stays LOW while pero=0 (packet held)
        // Re-assert pero -- verify packet flushed within a few cycles
        // =========================================================
        $display("\n=== TC11: Handshake With Blocking ===");

        // Deassert pero at destination BEFORE injecting
        @(negedge clk);
        node30_pero = 1'b0;
        $display("  node30 pero=0 (blocking output)");

        inject_pkt(2, 0, 3, 0, 32'hCC_00_00_01);

        // Confirm packet is stalled -- peso should stay 0 for several cycles
        begin : stall_check
            integer stall_cyc, seen_stall;
            seen_stall = 1;
            for (stall_cyc = 0; stall_cyc < 10; stall_cyc = stall_cyc + 1) begin
                @(posedge clk); #0.1;
                if (node30_peso === 1'b1) begin
                    seen_stall = 0;
                    $display("  FAIL [TC11] peso=1 while pero=0 at cycle %0d!",
                             stall_cyc);
                    fail_count = fail_count + 1;
                end
            end
            if (seen_stall) begin
                $display("  PASS [TC11] Packet held (peso=0) while pero=0");
                pass_count = pass_count + 1;
            end
        end

        // Unblock -- re-assert pero at negedge
        @(negedge clk);
        node30_pero = 1'b1;
        $display("  node30 pero=1 (unblocked)");

        // Packet should flush within a few cycles
        begin : unblock_check
            integer ucnt;
            ucnt = 0;
            @(posedge clk);
            while (!node30_peso) begin
                @(posedge clk);
                ucnt = ucnt + 1;
                if (ucnt > 10) begin
                    $display("  FAIL [TC11] Packet never flushed after pero=1!");
                    fail_count = fail_count + 1;
                    disable unblock_check;
                end
            end
            $display("  PASS [TC11] Packet flushed after pero reasserted (pkt=%h)", node30_pedo);

            pass_count = pass_count + 1;
        end
        drain(4);

        // =========================================================
        // TC12 -- CONTENTION: 4 sources -> node22(2,2)
        // Simultaneous injections via sequential issue
        // (within a few cycles so buffers overlap in the network)
        //   node02(0,2) -> node22: 2E, 0N  hopX=4'h3
        //   node32(3,2) -> node22: 1W, 0N  hopX=4'h1 dirX=1
        //   node21(2,1) -> node22: 0E, 1N  hopY=4'h1
        //   node23(2,3) -> node22: 0E, 1S  hopY=4'h1 dirY=0
        // All four must arrive -- arbiter must grant all eventually
        // =========================================================
        $display("\n=== TC12: Contention -- 4 sources -> node22(2,2) ===");
        current_phase = 12;
        clear_scoreboard;
        pkt_expected[10] = 4; // node22 flat id = 2*4+2 = 10

        // Issue all four as fast as possible (negedge-driven, back-to-back)
        inject_pkt(0, 2, 2, 2, 32'hDD_00_00_00); // from node02
        inject_pkt(3, 2, 2, 2, 32'hDD_00_00_03); // from node32
        inject_pkt(2, 1, 2, 2, 32'hDD_00_02_01); // from node21
        inject_pkt(2, 3, 2, 2, 32'hDD_00_02_03); // from node23

        wait_phase_done(10);
        if (pkt_received[10] === 4) begin
            $display("  PASS [TC12] All 4 contention packets arrived at node22");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC12] Only %0d/4 packets arrived",
                     pkt_received[10]);
            fail_count = fail_count + 1;
        end
        current_phase = -1;
        drain(6);

        // =========================================================
        // TC13 -- ARBITER PRIORITY ROTATION
        // Send 4 sequential contention bursts to node11(1,1) PE output
        // Competing inputs: N(node01), S(node10->via south path),
        //   E(node21), W(node01)... use direct single-hop sources:
        //   node01(0,1)->node11: E,  hopX=4'h1
        //   node21(2,1)->node11: W,  hopX=4'h1 dirX=1
        //   node10(1,0)->node11: N,  hopY=4'h1
        //   node12(1,2)->node11: S,  hopY=4'h1 dirY=0
        //
        // Run contention TWICE -- priority pointer must advance after
        // each grant when contention occurred. Verify node11 receives
        // all 8 packets (4 per round x 2 rounds).
        // =========================================================
        $display("\n=== TC13: Arbiter Priority Rotation ===");
        current_phase = 13;
        clear_scoreboard;
        pkt_expected[5] = 8; // node11 flat id=5

        $display("  Round 1: 4 simultaneous -> node11");
        inject_pkt(0, 1, 1, 1, 32'hEE_00_00_01); // from node01 (West input)
        inject_pkt(2, 1, 1, 1, 32'hEE_00_02_01); // from node21 (East input)
        inject_pkt(1, 0, 1, 1, 32'hEE_00_01_00); // from node10 (South input)
        inject_pkt(1, 2, 1, 1, 32'hEE_00_01_02); // from node12 (North input)

        // Wait for round 1 to drain
        begin : arb_r1
            integer w;
            w = 0;
            while (pkt_received[5] < 4) begin
                @(posedge clk);
                w = w + 1;
                if (w > MAX_WAIT*2) disable arb_r1;
            end
        end
        $display("  Round 1 done: %0d packets -- priority pointer advanced",
                 pkt_received[5]);

        $display("  Round 2: same 4 sources -> node11 again");
        inject_pkt(0, 1, 1, 1, 32'hEE_00_00_11); // from node01 (round 2)
        inject_pkt(2, 1, 1, 1, 32'hEE_00_02_11); // from node21 (round 2)
        inject_pkt(1, 0, 1, 1, 32'hEE_00_01_10); // from node10 (round 2)
        inject_pkt(1, 2, 1, 1, 32'hEE_00_01_12); // from node12 (round 2)

        wait_phase_done(5);
        if (pkt_received[5] === 8) begin
            $display("  PASS [TC13] All 8 arbitration packets arrived (rotation verified)");

            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [TC13] Only %0d/8 packets arrived",
                     pkt_received[5]);
            fail_count = fail_count + 1;
        end
        current_phase = -1;
        drain(8);

        // =========================================================
        // TC14 -- FULL 16-PHASE GATHER
        //
        // Phase p (p = 0..15):
        //   All 15 nodes EXCEPT node_p inject one packet -> node_p
        //   Payload = flat sender id (so destination can identify source)
        //   Phase completes when node_p receives all 15 packets
        //
        // Generates gather_phaseN.res and start_end_time.out
        // =========================================================
        $display("\n=== TC14: Full 16-Phase Gather ===");

        for (p = 0; p < NUM_NODES; p = p + 1) begin
            clear_scoreboard;
            pkt_expected[p] = NUM_NODES - 1; // 15 senders
            current_phase   = p;

            $display("\n  --- Gather Phase %0d: all -> node(%0d,%0d) ---",

                     p, NODE_X[p], NODE_Y[p]);

            // Log start time
            $fdisplay(fh_time, "Phase %0d Start: %0t ns (dest=node(%0d,%0d))",
                      p, $time, NODE_X[p], NODE_Y[p]);

            // Inject from all nodes except p, one per cycle (sequential)
            for (i = 0; i < NUM_NODES; i = i + 1) begin
                if (i !== p) begin
                    inject_pkt(NODE_X[i], NODE_Y[i],
                               NODE_X[p], NODE_Y[p],
                               32'd0 + i);     // payload = sender flat id
                end
            end

            // Wait for all 15 to arrive
            wait_phase_done(p);

            // Log end time
            $fdisplay(fh_time,
                      "Phase %0d End:   %0t ns (%0d/%0d received)",
                      p, $time,
                      pkt_received[p], pkt_expected[p]);

            // Completeness check -- every sender should appear exactly once
            for (j = 0; j < NUM_NODES; j = j + 1) begin
                if (j !== p) begin
                    if (seen[p][j] !== 1) begin
                        $display("  FAIL [Phase %0d] Missing pkt from node(%0d,%0d)!",

                                 p, NODE_X[j], NODE_Y[j]);
                        fail_count = fail_count + 1;
                    end
                end
            end

            if (pkt_received[p] === pkt_expected[p]) begin
                $display("  PASS [Phase %0d] All %0d packets received at node(%0d,%0d)",

                         p, pkt_expected[p], NODE_X[p], NODE_Y[p]);
                pass_count = pass_count + 1;
            end

            current_phase = -1;
            drain(8);    // Give network time to drain before next phase
        end

        // =========================================================
        // FINAL REPORT
        // =========================================================
        $display("\n");
        $display("+==========================================+");
        $display("|   Cardinal 4x4 Mesh Verification Done   |");
        $display("+==========================================+");
        $display("|  PASS: %-5d  FAIL: %-5d               |",
                 pass_count, fail_count);
        if (fail_count === 0)
            $display("|         *** ALL TESTS PASSED ***         |");
        else
            $display("|       *** %0d FAILURE(S) DETECTED ***      |",
                     fail_count);
        $display("+==========================================+");

        $fdisplay(fh_time, "\n// === FINAL RESULT ===");
        $fdisplay(fh_time, "// Sim end:  %0t", $time);
        $fdisplay(fh_time, "// PASS: %0d  FAIL: %0d", pass_count, fail_count);
        if (fail_count === 0)
            $fdisplay(fh_time, "// ALL TESTS PASSED");
        else
            $fdisplay(fh_time, "// %0d FAILURE(S)", fail_count);

        for (i = 0; i < NUM_NODES; i = i + 1)
            $fclose(fh_phase[i]);
        $fclose(fh_time);

        $finish;
    end

    // ----------------------------------------------------------
    // Global watchdog -- prevents infinite hangs
    // ----------------------------------------------------------
    initial begin
        #2_000_000; // 2ms limit
        $display("FATAL: Watchdog timeout -- simulation hung!");
        $fdisplay(fh_time, "FATAL: Watchdog timeout at %0t", $time);
        $finish;
    end

endmodule
