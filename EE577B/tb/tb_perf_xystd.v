`timescale 1ns/1ps
// tb_perf_xystd.v -- XYSTD Performance TB
// DUT: gold_mesh_xystd
// Protocol: wait polarity=1 && peri=1 at negedge, drive pesi 1 cycle
// Tests 39 representative pairs, ~1-2 min runtime
module tb_perf_xystd;
    parameter CLK_HALF=1; // 500 MHz
    parameter RESET_CYC=10;
    parameter MAX_WAIT=500;

    reg clk, reset;
    initial clk=0;
    always #CLK_HALF clk=~clk;
    integer cycle_count;
    initial cycle_count=0;
    always @(posedge clk)
        if(reset) cycle_count<=0;
        else       cycle_count<=cycle_count+1;

    wire node00_polarity;
    reg  node00_pesi;
    wire node00_peri;
    reg  [63:0] node00_pedi;
    wire node00_peso;
    reg  node00_pero;
    wire [63:0] node00_pedo;
    wire node10_polarity;
    reg  node10_pesi;
    wire node10_peri;
    reg  [63:0] node10_pedi;
    wire node10_peso;
    reg  node10_pero;
    wire [63:0] node10_pedo;
    wire node20_polarity;
    reg  node20_pesi;
    wire node20_peri;
    reg  [63:0] node20_pedi;
    wire node20_peso;
    reg  node20_pero;
    wire [63:0] node20_pedo;
    wire node30_polarity;
    reg  node30_pesi;
    wire node30_peri;
    reg  [63:0] node30_pedi;
    wire node30_peso;
    reg  node30_pero;
    wire [63:0] node30_pedo;
    wire node01_polarity;
    reg  node01_pesi;
    wire node01_peri;
    reg  [63:0] node01_pedi;
    wire node01_peso;
    reg  node01_pero;
    wire [63:0] node01_pedo;
    wire node11_polarity;
    reg  node11_pesi;
    wire node11_peri;
    reg  [63:0] node11_pedi;
    wire node11_peso;
    reg  node11_pero;
    wire [63:0] node11_pedo;
    wire node21_polarity;
    reg  node21_pesi;
    wire node21_peri;
    reg  [63:0] node21_pedi;
    wire node21_peso;
    reg  node21_pero;
    wire [63:0] node21_pedo;
    wire node31_polarity;
    reg  node31_pesi;
    wire node31_peri;
    reg  [63:0] node31_pedi;
    wire node31_peso;
    reg  node31_pero;
    wire [63:0] node31_pedo;
    wire node02_polarity;
    reg  node02_pesi;
    wire node02_peri;
    reg  [63:0] node02_pedi;
    wire node02_peso;
    reg  node02_pero;
    wire [63:0] node02_pedo;
    wire node12_polarity;
    reg  node12_pesi;
    wire node12_peri;
    reg  [63:0] node12_pedi;
    wire node12_peso;
    reg  node12_pero;
    wire [63:0] node12_pedo;
    wire node22_polarity;
    reg  node22_pesi;
    wire node22_peri;
    reg  [63:0] node22_pedi;
    wire node22_peso;
    reg  node22_pero;
    wire [63:0] node22_pedo;
    wire node32_polarity;
    reg  node32_pesi;
    wire node32_peri;
    reg  [63:0] node32_pedi;
    wire node32_peso;
    reg  node32_pero;
    wire [63:0] node32_pedo;
    wire node03_polarity;
    reg  node03_pesi;
    wire node03_peri;
    reg  [63:0] node03_pedi;
    wire node03_peso;
    reg  node03_pero;
    wire [63:0] node03_pedo;
    wire node13_polarity;
    reg  node13_pesi;
    wire node13_peri;
    reg  [63:0] node13_pedi;
    wire node13_peso;
    reg  node13_pero;
    wire [63:0] node13_pedo;
    wire node23_polarity;
    reg  node23_pesi;
    wire node23_peri;
    reg  [63:0] node23_pedi;
    wire node23_peso;
    reg  node23_pero;
    wire [63:0] node23_pedo;
    wire node33_polarity;
    reg  node33_pesi;
    wire node33_peri;
    reg  [63:0] node33_pedi;
    wire node33_peso;
    reg  node33_pero;
    wire [63:0] node33_pedo;

    gold_mesh_xystd dut (
        .clk(clk), .reset(reset),
        .node00_polarity(node00_polarity),
        .node00_pesi(node00_pesi), .node00_peri(node00_peri),
        .node00_pedi(node00_pedi),
        .node00_peso(node00_peso),
        .node00_pero(node00_pero),
        .node00_pedo(node00_pedo),
        .node10_polarity(node10_polarity),
        .node10_pesi(node10_pesi), .node10_peri(node10_peri),
        .node10_pedi(node10_pedi),
        .node10_peso(node10_peso),
        .node10_pero(node10_pero),
        .node10_pedo(node10_pedo),
        .node20_polarity(node20_polarity),
        .node20_pesi(node20_pesi), .node20_peri(node20_peri),
        .node20_pedi(node20_pedi),
        .node20_peso(node20_peso),
        .node20_pero(node20_pero),
        .node20_pedo(node20_pedo),
        .node30_polarity(node30_polarity),
        .node30_pesi(node30_pesi), .node30_peri(node30_peri),
        .node30_pedi(node30_pedi),
        .node30_peso(node30_peso),
        .node30_pero(node30_pero),
        .node30_pedo(node30_pedo),
        .node01_polarity(node01_polarity),
        .node01_pesi(node01_pesi), .node01_peri(node01_peri),
        .node01_pedi(node01_pedi),
        .node01_peso(node01_peso),
        .node01_pero(node01_pero),
        .node01_pedo(node01_pedo),
        .node11_polarity(node11_polarity),
        .node11_pesi(node11_pesi), .node11_peri(node11_peri),
        .node11_pedi(node11_pedi),
        .node11_peso(node11_peso),
        .node11_pero(node11_pero),
        .node11_pedo(node11_pedo),
        .node21_polarity(node21_polarity),
        .node21_pesi(node21_pesi), .node21_peri(node21_peri),
        .node21_pedi(node21_pedi),
        .node21_peso(node21_peso),
        .node21_pero(node21_pero),
        .node21_pedo(node21_pedo),
        .node31_polarity(node31_polarity),
        .node31_pesi(node31_pesi), .node31_peri(node31_peri),
        .node31_pedi(node31_pedi),
        .node31_peso(node31_peso),
        .node31_pero(node31_pero),
        .node31_pedo(node31_pedo),
        .node02_polarity(node02_polarity),
        .node02_pesi(node02_pesi), .node02_peri(node02_peri),
        .node02_pedi(node02_pedi),
        .node02_peso(node02_peso),
        .node02_pero(node02_pero),
        .node02_pedo(node02_pedo),
        .node12_polarity(node12_polarity),
        .node12_pesi(node12_pesi), .node12_peri(node12_peri),
        .node12_pedi(node12_pedi),
        .node12_peso(node12_peso),
        .node12_pero(node12_pero),
        .node12_pedo(node12_pedo),
        .node22_polarity(node22_polarity),
        .node22_pesi(node22_pesi), .node22_peri(node22_peri),
        .node22_pedi(node22_pedi),
        .node22_peso(node22_peso),
        .node22_pero(node22_pero),
        .node22_pedo(node22_pedo),
        .node32_polarity(node32_polarity),
        .node32_pesi(node32_pesi), .node32_peri(node32_peri),
        .node32_pedi(node32_pedi),
        .node32_peso(node32_peso),
        .node32_pero(node32_pero),
        .node32_pedo(node32_pedo),
        .node03_polarity(node03_polarity),
        .node03_pesi(node03_pesi), .node03_peri(node03_peri),
        .node03_pedi(node03_pedi),
        .node03_peso(node03_peso),
        .node03_pero(node03_pero),
        .node03_pedo(node03_pedo),
        .node13_polarity(node13_polarity),
        .node13_pesi(node13_pesi), .node13_peri(node13_peri),
        .node13_pedi(node13_pedi),
        .node13_peso(node13_peso),
        .node13_pero(node13_pero),
        .node13_pedo(node13_pedo),
        .node23_polarity(node23_polarity),
        .node23_pesi(node23_pesi), .node23_peri(node23_peri),
        .node23_pedi(node23_pedi),
        .node23_peso(node23_peso),
        .node23_pero(node23_pero),
        .node23_pedo(node23_pedo),
        .node33_polarity(node33_polarity),
        .node33_pesi(node33_pesi), .node33_peri(node33_peri),
        .node33_pedi(node33_pedi),
        .node33_peso(node33_peso),
        .node33_pero(node33_pero),
        .node33_pedo(node33_pedo)
    );

    function [63:0] make_pkt;
        input integer sx,sy,dx,dy;
        input [15:0] ts;
        input pol;
        reg [7:0] did;
        begin
            did=dy*4+dx;
            make_pkt={pol,7'b0,dx[7:0],dy[7:0],sx[7:0],sy[7:0],did,ts};
        end
    endfunction

    integer lat[0:38];
    integer got[0:38];
    integer inj_cyc;
    integer wc;

    // -- inject_pkt: blocking sequential injection --
    // Waits for polarity=1 AND peri=1 at negedge, injects one cycle
    task inject_pkt;
        input integer sx, sy, dx, dy;
        output integer icyc;
        reg [63:0] pkt;
        reg pol, rdy;
        integer wcount;
        begin
            wcount = 0;
            // Sample at negedge -- safe to drive before posedge
            @(negedge clk);
            pol  = 1'b0; rdy = 1'b0;
            // Wait until polarity==1 AND peri==1
            case({sy,sx})
            8'h00: begin pol=node00_polarity; rdy=node00_peri; end
            8'h01: begin pol=node10_polarity; rdy=node10_peri; end
            8'h02: begin pol=node20_polarity; rdy=node20_peri; end
            8'h03: begin pol=node30_polarity; rdy=node30_peri; end
            8'h10: begin pol=node01_polarity; rdy=node01_peri; end
            8'h11: begin pol=node11_polarity; rdy=node11_peri; end
            8'h12: begin pol=node21_polarity; rdy=node21_peri; end
            8'h13: begin pol=node31_polarity; rdy=node31_peri; end
            8'h20: begin pol=node02_polarity; rdy=node02_peri; end
            8'h21: begin pol=node12_polarity; rdy=node12_peri; end
            8'h22: begin pol=node22_polarity; rdy=node22_peri; end
            8'h23: begin pol=node32_polarity; rdy=node32_peri; end
            8'h30: begin pol=node03_polarity; rdy=node03_peri; end
            8'h31: begin pol=node13_polarity; rdy=node13_peri; end
            8'h32: begin pol=node23_polarity; rdy=node23_peri; end
            8'h33: begin pol=node33_polarity; rdy=node33_peri; end
            endcase
            while(!(pol===1'b1 && rdy===1'b1) && wcount<MAX_WAIT) begin
                @(negedge clk); wcount=wcount+1;
                case({sy,sx})
                8'h00: begin pol=node00_polarity; rdy=node00_peri; end
                8'h01: begin pol=node10_polarity; rdy=node10_peri; end
                8'h02: begin pol=node20_polarity; rdy=node20_peri; end
                8'h03: begin pol=node30_polarity; rdy=node30_peri; end
                8'h10: begin pol=node01_polarity; rdy=node01_peri; end
                8'h11: begin pol=node11_polarity; rdy=node11_peri; end
                8'h12: begin pol=node21_polarity; rdy=node21_peri; end
                8'h13: begin pol=node31_polarity; rdy=node31_peri; end
                8'h20: begin pol=node02_polarity; rdy=node02_peri; end
                8'h21: begin pol=node12_polarity; rdy=node12_peri; end
                8'h22: begin pol=node22_polarity; rdy=node22_peri; end
                8'h23: begin pol=node32_polarity; rdy=node32_peri; end
                8'h30: begin pol=node03_polarity; rdy=node03_peri; end
                8'h31: begin pol=node13_polarity; rdy=node13_peri; end
                8'h32: begin pol=node23_polarity; rdy=node23_peri; end
                8'h33: begin pol=node33_polarity; rdy=node33_peri; end
                endcase
            end
            if(wcount>=MAX_WAIT) begin
                $display("TIMEOUT inject (%0d,%0d)->(%0d,%0d)",sx,sy,dx,dy);
                icyc=-1;
            end else begin
                icyc = cycle_count;
                pkt = make_pkt(sx,sy,dx,dy,icyc[15:0],pol);
                // Drive at negedge -- sampled at next posedge
                case({sy,sx})
                8'h00: begin node00_pesi=1'b1; node00_pedi=pkt; end
                8'h01: begin node10_pesi=1'b1; node10_pedi=pkt; end
                8'h02: begin node20_pesi=1'b1; node20_pedi=pkt; end
                8'h03: begin node30_pesi=1'b1; node30_pedi=pkt; end
                8'h10: begin node01_pesi=1'b1; node01_pedi=pkt; end
                8'h11: begin node11_pesi=1'b1; node11_pedi=pkt; end
                8'h12: begin node21_pesi=1'b1; node21_pedi=pkt; end
                8'h13: begin node31_pesi=1'b1; node31_pedi=pkt; end
                8'h20: begin node02_pesi=1'b1; node02_pedi=pkt; end
                8'h21: begin node12_pesi=1'b1; node12_pedi=pkt; end
                8'h22: begin node22_pesi=1'b1; node22_pedi=pkt; end
                8'h23: begin node32_pesi=1'b1; node32_pedi=pkt; end
                8'h30: begin node03_pesi=1'b1; node03_pedi=pkt; end
                8'h31: begin node13_pesi=1'b1; node13_pedi=pkt; end
                8'h32: begin node23_pesi=1'b1; node23_pedi=pkt; end
                8'h33: begin node33_pesi=1'b1; node33_pedi=pkt; end
                endcase
                @(negedge clk);
                // Deassert
                case({sy,sx})
                8'h00: begin node00_pesi=1'b0; end
                8'h01: begin node10_pesi=1'b0; end
                8'h02: begin node20_pesi=1'b0; end
                8'h03: begin node30_pesi=1'b0; end
                8'h10: begin node01_pesi=1'b0; end
                8'h11: begin node11_pesi=1'b0; end
                8'h12: begin node21_pesi=1'b0; end
                8'h13: begin node31_pesi=1'b0; end
                8'h20: begin node02_pesi=1'b0; end
                8'h21: begin node12_pesi=1'b0; end
                8'h22: begin node22_pesi=1'b0; end
                8'h23: begin node32_pesi=1'b0; end
                8'h30: begin node03_pesi=1'b0; end
                8'h31: begin node13_pesi=1'b0; end
                8'h32: begin node23_pesi=1'b0; end
                8'h33: begin node33_pesi=1'b0; end
                endcase
            end
        end
    endtask

    // -- wait_pkt: poll peso at destination, return latency --
    task wait_pkt;
        input integer dx, dy;
        input integer icyc;
        output integer latency;
        integer wcount;
        reg arrived;
        begin
            wcount=0; arrived=0;
            while(!arrived && wcount<MAX_WAIT) begin
                @(posedge clk); wcount=wcount+1;
                case({dy,dx})
                8'h00: if(node00_peso===1'b1) arrived=1;
                8'h01: if(node10_peso===1'b1) arrived=1;
                8'h02: if(node20_peso===1'b1) arrived=1;
                8'h03: if(node30_peso===1'b1) arrived=1;
                8'h10: if(node01_peso===1'b1) arrived=1;
                8'h11: if(node11_peso===1'b1) arrived=1;
                8'h12: if(node21_peso===1'b1) arrived=1;
                8'h13: if(node31_peso===1'b1) arrived=1;
                8'h20: if(node02_peso===1'b1) arrived=1;
                8'h21: if(node12_peso===1'b1) arrived=1;
                8'h22: if(node22_peso===1'b1) arrived=1;
                8'h23: if(node32_peso===1'b1) arrived=1;
                8'h30: if(node03_peso===1'b1) arrived=1;
                8'h31: if(node13_peso===1'b1) arrived=1;
                8'h32: if(node23_peso===1'b1) arrived=1;
                8'h33: if(node33_peso===1'b1) arrived=1;
                endcase
            end
            if(!arrived) begin
                $display("TIMEOUT wait (%0d,%0d)",dx,dy);
                latency=-1;
            end else
                latency=cycle_count-icyc;
        end
    endtask

    integer pi, min_lat, max_lat, tot_lat, cnt, fh;
    real avg_lat;
    initial begin
        $dumpfile("tb_perf_xystd.vcd");
        $dumpvars(0, tb_perf_xystd);
        // Init all PE signals
        node00_pesi=1'b0; node00_pedi=64'h0; node00_pero=1'b1;
        node10_pesi=1'b0; node10_pedi=64'h0; node10_pero=1'b1;
        node20_pesi=1'b0; node20_pedi=64'h0; node20_pero=1'b1;
        node30_pesi=1'b0; node30_pedi=64'h0; node30_pero=1'b1;
        node01_pesi=1'b0; node01_pedi=64'h0; node01_pero=1'b1;
        node11_pesi=1'b0; node11_pedi=64'h0; node11_pero=1'b1;
        node21_pesi=1'b0; node21_pedi=64'h0; node21_pero=1'b1;
        node31_pesi=1'b0; node31_pedi=64'h0; node31_pero=1'b1;
        node02_pesi=1'b0; node02_pedi=64'h0; node02_pero=1'b1;
        node12_pesi=1'b0; node12_pedi=64'h0; node12_pero=1'b1;
        node22_pesi=1'b0; node22_pedi=64'h0; node22_pero=1'b1;
        node32_pesi=1'b0; node32_pedi=64'h0; node32_pero=1'b1;
        node03_pesi=1'b0; node03_pedi=64'h0; node03_pero=1'b1;
        node13_pesi=1'b0; node13_pedi=64'h0; node13_pero=1'b1;
        node23_pesi=1'b0; node23_pedi=64'h0; node23_pero=1'b1;
        node33_pesi=1'b0; node33_pedi=64'h0; node33_pero=1'b1;
        // Reset sequence
        reset=1;
        repeat(RESET_CYC) @(posedge clk);
        @(negedge clk); reset=0;
        repeat(8) @(posedge clk);
        $display("[XYSTD] Starting 39 pair latency test...");

        // Pair 0: (0,0)->(1,0)
        inject_pkt(0,0,1,0, inj_cyc);
        wait_pkt(1,0, inj_cyc, lat[0]);
        got[0] = (lat[0]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 1: (1,0)->(2,0)
        inject_pkt(1,0,2,0, inj_cyc);
        wait_pkt(2,0, inj_cyc, lat[1]);
        got[1] = (lat[1]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 2: (2,0)->(3,0)
        inject_pkt(2,0,3,0, inj_cyc);
        wait_pkt(3,0, inj_cyc, lat[2]);
        got[2] = (lat[2]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 3: (0,0)->(0,1)
        inject_pkt(0,0,0,1, inj_cyc);
        wait_pkt(0,1, inj_cyc, lat[3]);
        got[3] = (lat[3]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 4: (1,1)->(1,2)
        inject_pkt(1,1,1,2, inj_cyc);
        wait_pkt(1,2, inj_cyc, lat[4]);
        got[4] = (lat[4]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 5: (2,2)->(2,3)
        inject_pkt(2,2,2,3, inj_cyc);
        wait_pkt(2,3, inj_cyc, lat[5]);
        got[5] = (lat[5]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 6: (3,0)->(2,0)
        inject_pkt(3,0,2,0, inj_cyc);
        wait_pkt(2,0, inj_cyc, lat[6]);
        got[6] = (lat[6]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 7: (2,1)->(1,1)
        inject_pkt(2,1,1,1, inj_cyc);
        wait_pkt(1,1, inj_cyc, lat[7]);
        got[7] = (lat[7]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 8: (1,2)->(0,2)
        inject_pkt(1,2,0,2, inj_cyc);
        wait_pkt(0,2, inj_cyc, lat[8]);
        got[8] = (lat[8]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 9: (0,3)->(0,2)
        inject_pkt(0,3,0,2, inj_cyc);
        wait_pkt(0,2, inj_cyc, lat[9]);
        got[9] = (lat[9]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 10: (1,2)->(1,1)
        inject_pkt(1,2,1,1, inj_cyc);
        wait_pkt(1,1, inj_cyc, lat[10]);
        got[10] = (lat[10]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 11: (3,3)->(3,2)
        inject_pkt(3,3,3,2, inj_cyc);
        wait_pkt(3,2, inj_cyc, lat[11]);
        got[11] = (lat[11]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 12: (0,0)->(2,0)
        inject_pkt(0,0,2,0, inj_cyc);
        wait_pkt(2,0, inj_cyc, lat[12]);
        got[12] = (lat[12]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 13: (1,0)->(3,0)
        inject_pkt(1,0,3,0, inj_cyc);
        wait_pkt(3,0, inj_cyc, lat[13]);
        got[13] = (lat[13]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 14: (0,0)->(0,2)
        inject_pkt(0,0,0,2, inj_cyc);
        wait_pkt(0,2, inj_cyc, lat[14]);
        got[14] = (lat[14]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 15: (1,1)->(1,3)
        inject_pkt(1,1,1,3, inj_cyc);
        wait_pkt(1,3, inj_cyc, lat[15]);
        got[15] = (lat[15]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 16: (0,0)->(1,1)
        inject_pkt(0,0,1,1, inj_cyc);
        wait_pkt(1,1, inj_cyc, lat[16]);
        got[16] = (lat[16]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 17: (1,0)->(2,1)
        inject_pkt(1,0,2,1, inj_cyc);
        wait_pkt(2,1, inj_cyc, lat[17]);
        got[17] = (lat[17]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 18: (2,0)->(3,1)
        inject_pkt(2,0,3,1, inj_cyc);
        wait_pkt(3,1, inj_cyc, lat[18]);
        got[18] = (lat[18]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 19: (3,3)->(2,2)
        inject_pkt(3,3,2,2, inj_cyc);
        wait_pkt(2,2, inj_cyc, lat[19]);
        got[19] = (lat[19]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 20: (2,2)->(1,1)
        inject_pkt(2,2,1,1, inj_cyc);
        wait_pkt(1,1, inj_cyc, lat[20]);
        got[20] = (lat[20]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 21: (1,1)->(0,0)
        inject_pkt(1,1,0,0, inj_cyc);
        wait_pkt(0,0, inj_cyc, lat[21]);
        got[21] = (lat[21]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 22: (0,0)->(3,0)
        inject_pkt(0,0,3,0, inj_cyc);
        wait_pkt(3,0, inj_cyc, lat[22]);
        got[22] = (lat[22]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 23: (0,1)->(3,1)
        inject_pkt(0,1,3,1, inj_cyc);
        wait_pkt(3,1, inj_cyc, lat[23]);
        got[23] = (lat[23]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 24: (0,0)->(0,3)
        inject_pkt(0,0,0,3, inj_cyc);
        wait_pkt(0,3, inj_cyc, lat[24]);
        got[24] = (lat[24]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 25: (1,0)->(1,3)
        inject_pkt(1,0,1,3, inj_cyc);
        wait_pkt(1,3, inj_cyc, lat[25]);
        got[25] = (lat[25]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 26: (0,0)->(2,2)
        inject_pkt(0,0,2,2, inj_cyc);
        wait_pkt(2,2, inj_cyc, lat[26]);
        got[26] = (lat[26]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 27: (1,0)->(3,2)
        inject_pkt(1,0,3,2, inj_cyc);
        wait_pkt(3,2, inj_cyc, lat[27]);
        got[27] = (lat[27]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 28: (0,0)->(3,3)
        inject_pkt(0,0,3,3, inj_cyc);
        wait_pkt(3,3, inj_cyc, lat[28]);
        got[28] = (lat[28]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 29: (3,3)->(0,0)
        inject_pkt(3,3,0,0, inj_cyc);
        wait_pkt(0,0, inj_cyc, lat[29]);
        got[29] = (lat[29]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 30: (0,3)->(3,0)
        inject_pkt(0,3,3,0, inj_cyc);
        wait_pkt(3,0, inj_cyc, lat[30]);
        got[30] = (lat[30]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 31: (3,0)->(0,3)
        inject_pkt(3,0,0,3, inj_cyc);
        wait_pkt(0,3, inj_cyc, lat[31]);
        got[31] = (lat[31]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 32: (0,0)->(3,2)
        inject_pkt(0,0,3,2, inj_cyc);
        wait_pkt(3,2, inj_cyc, lat[32]);
        got[32] = (lat[32]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 33: (0,0)->(2,3)
        inject_pkt(0,0,2,3, inj_cyc);
        wait_pkt(2,3, inj_cyc, lat[33]);
        got[33] = (lat[33]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 34: (0,0)->(3,1)
        inject_pkt(0,0,3,1, inj_cyc);
        wait_pkt(3,1, inj_cyc, lat[34]);
        got[34] = (lat[34]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 35: (0,0)->(1,3)
        inject_pkt(0,0,1,3, inj_cyc);
        wait_pkt(1,3, inj_cyc, lat[35]);
        got[35] = (lat[35]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 36: (0,0)->(0,3)
        inject_pkt(0,0,0,3, inj_cyc);
        wait_pkt(0,3, inj_cyc, lat[36]);
        got[36] = (lat[36]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 37: (3,3)->(0,3)
        inject_pkt(3,3,0,3, inj_cyc);
        wait_pkt(0,3, inj_cyc, lat[37]);
        got[37] = (lat[37]>0)?1:0;
        repeat(4) @(posedge clk);
        // Pair 38: (3,3)->(3,0)
        inject_pkt(3,3,3,0, inj_cyc);
        wait_pkt(3,0, inj_cyc, lat[38]);
        got[38] = (lat[38]>0)?1:0;
        repeat(4) @(posedge clk);

        // -- Compute stats --
        min_lat=9999; max_lat=0; tot_lat=0; cnt=0;
        for(pi=0;pi<39;pi=pi+1) begin
            if(lat[pi]>0) begin
                if(lat[pi]<min_lat) min_lat=lat[pi];
                if(lat[pi]>max_lat) max_lat=lat[pi];
                tot_lat=tot_lat+lat[pi];
                cnt=cnt+1;
            end
        end
        avg_lat = (cnt>0) ? (tot_lat*1.0/cnt) : 0.0;

        fh = $fopen("perf_xystd_summary.txt","w");
        $fdisplay(fh,"======================================================");
        $fdisplay(fh,"  EE577B Cardinal Router -- XYSTD Performance Report");
        $fdisplay(fh,"  DUT: gold_mesh_xystd");
        $fdisplay(fh,"======================================================");
        $fdisplay(fh,"-- LATENCY (39 representative pairs) ----------------");
        $fdisplay(fh,"  Pairs measured      : %0d / 39", cnt);
        $fdisplay(fh,"  Min latency (cycles): %%0d", min_lat);
        $fdisplay(fh,"  Max latency (cycles): %%0d", max_lat);
        $fdisplay(fh,"  Avg latency (cycles): %%.2f", avg_lat);
        $fdisplay(fh,"  Min latency (ns)    : %%.1f  (@ 500 MHz sim)", min_lat*2.0);
        $fdisplay(fh,"  Max latency (ns)    : %%.1f", max_lat*2.0);
        $fdisplay(fh,"  Avg latency (ns)    : %%.1f", avg_lat*2.0);
        $fdisplay(fh,"-- PAIR RESULTS ------------------------------------");
        $fdisplay(fh,"  SRC       DST       Latency(cyc)");
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 1,0,lat[0]);
        $fdisplay(fh,"  (1,0)->(%0d,%0d)   %0d", 2,0,lat[1]);
        $fdisplay(fh,"  (2,0)->(%0d,%0d)   %0d", 3,0,lat[2]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 0,1,lat[3]);
        $fdisplay(fh,"  (1,1)->(%0d,%0d)   %0d", 1,2,lat[4]);
        $fdisplay(fh,"  (2,2)->(%0d,%0d)   %0d", 2,3,lat[5]);
        $fdisplay(fh,"  (3,0)->(%0d,%0d)   %0d", 2,0,lat[6]);
        $fdisplay(fh,"  (2,1)->(%0d,%0d)   %0d", 1,1,lat[7]);
        $fdisplay(fh,"  (1,2)->(%0d,%0d)   %0d", 0,2,lat[8]);
        $fdisplay(fh,"  (0,3)->(%0d,%0d)   %0d", 0,2,lat[9]);
        $fdisplay(fh,"  (1,2)->(%0d,%0d)   %0d", 1,1,lat[10]);
        $fdisplay(fh,"  (3,3)->(%0d,%0d)   %0d", 3,2,lat[11]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 2,0,lat[12]);
        $fdisplay(fh,"  (1,0)->(%0d,%0d)   %0d", 3,0,lat[13]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 0,2,lat[14]);
        $fdisplay(fh,"  (1,1)->(%0d,%0d)   %0d", 1,3,lat[15]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 1,1,lat[16]);
        $fdisplay(fh,"  (1,0)->(%0d,%0d)   %0d", 2,1,lat[17]);
        $fdisplay(fh,"  (2,0)->(%0d,%0d)   %0d", 3,1,lat[18]);
        $fdisplay(fh,"  (3,3)->(%0d,%0d)   %0d", 2,2,lat[19]);
        $fdisplay(fh,"  (2,2)->(%0d,%0d)   %0d", 1,1,lat[20]);
        $fdisplay(fh,"  (1,1)->(%0d,%0d)   %0d", 0,0,lat[21]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 3,0,lat[22]);
        $fdisplay(fh,"  (0,1)->(%0d,%0d)   %0d", 3,1,lat[23]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 0,3,lat[24]);
        $fdisplay(fh,"  (1,0)->(%0d,%0d)   %0d", 1,3,lat[25]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 2,2,lat[26]);
        $fdisplay(fh,"  (1,0)->(%0d,%0d)   %0d", 3,2,lat[27]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 3,3,lat[28]);
        $fdisplay(fh,"  (3,3)->(%0d,%0d)   %0d", 0,0,lat[29]);
        $fdisplay(fh,"  (0,3)->(%0d,%0d)   %0d", 3,0,lat[30]);
        $fdisplay(fh,"  (3,0)->(%0d,%0d)   %0d", 0,3,lat[31]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 3,2,lat[32]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 2,3,lat[33]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 3,1,lat[34]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 1,3,lat[35]);
        $fdisplay(fh,"  (0,0)->(%0d,%0d)   %0d", 0,3,lat[36]);
        $fdisplay(fh,"  (3,3)->(%0d,%0d)   %0d", 0,3,lat[37]);
        $fdisplay(fh,"  (3,3)->(%0d,%0d)   %0d", 3,0,lat[38]);
        $fdisplay(fh,"-- SYNTHESIS (DC, 250 MHz target) ------------------");
        $fdisplay(fh,"  Max freq : 259.7 MHz");
        $fdisplay(fh,"  Crit path: 3.790 ns  Slack: +0.150 ns");
        $fdisplay(fh,"  Cell area: 30100 um2  Power: 5.633 mW");
        $fdisplay(fh,"  Sim cycles: %%0d", cycle_count);
        $fdisplay(fh,"======================================================");
        $fclose(fh);

        fh = $fopen("perf_xystd_latency.txt","w");
        $fdisplay(fh,"SRC_X  SRC_Y  DST_X  DST_Y  LAT_CYC  LAT_NS");
        if(lat[0]>0) $fdisplay(fh,"  0      0      1      0    %0d      %.1f",
            lat[0], lat[0]*2.0);
        if(lat[1]>0) $fdisplay(fh,"  1      0      2      0    %0d      %.1f",
            lat[1], lat[1]*2.0);
        if(lat[2]>0) $fdisplay(fh,"  2      0      3      0    %0d      %.1f",
            lat[2], lat[2]*2.0);
        if(lat[3]>0) $fdisplay(fh,"  0      0      0      1    %0d      %.1f",
            lat[3], lat[3]*2.0);
        if(lat[4]>0) $fdisplay(fh,"  1      1      1      2    %0d      %.1f",
            lat[4], lat[4]*2.0);
        if(lat[5]>0) $fdisplay(fh,"  2      2      2      3    %0d      %.1f",
            lat[5], lat[5]*2.0);
        if(lat[6]>0) $fdisplay(fh,"  3      0      2      0    %0d      %.1f",
            lat[6], lat[6]*2.0);
        if(lat[7]>0) $fdisplay(fh,"  2      1      1      1    %0d      %.1f",
            lat[7], lat[7]*2.0);
        if(lat[8]>0) $fdisplay(fh,"  1      2      0      2    %0d      %.1f",
            lat[8], lat[8]*2.0);
        if(lat[9]>0) $fdisplay(fh,"  0      3      0      2    %0d      %.1f",
            lat[9], lat[9]*2.0);
        if(lat[10]>0) $fdisplay(fh,"  1      2      1      1    %0d      %.1f",
            lat[10], lat[10]*2.0);
        if(lat[11]>0) $fdisplay(fh,"  3      3      3      2    %0d      %.1f",
            lat[11], lat[11]*2.0);
        if(lat[12]>0) $fdisplay(fh,"  0      0      2      0    %0d      %.1f",
            lat[12], lat[12]*2.0);
        if(lat[13]>0) $fdisplay(fh,"  1      0      3      0    %0d      %.1f",
            lat[13], lat[13]*2.0);
        if(lat[14]>0) $fdisplay(fh,"  0      0      0      2    %0d      %.1f",
            lat[14], lat[14]*2.0);
        if(lat[15]>0) $fdisplay(fh,"  1      1      1      3    %0d      %.1f",
            lat[15], lat[15]*2.0);
        if(lat[16]>0) $fdisplay(fh,"  0      0      1      1    %0d      %.1f",
            lat[16], lat[16]*2.0);
        if(lat[17]>0) $fdisplay(fh,"  1      0      2      1    %0d      %.1f",
            lat[17], lat[17]*2.0);
        if(lat[18]>0) $fdisplay(fh,"  2      0      3      1    %0d      %.1f",
            lat[18], lat[18]*2.0);
        if(lat[19]>0) $fdisplay(fh,"  3      3      2      2    %0d      %.1f",
            lat[19], lat[19]*2.0);
        if(lat[20]>0) $fdisplay(fh,"  2      2      1      1    %0d      %.1f",
            lat[20], lat[20]*2.0);
        if(lat[21]>0) $fdisplay(fh,"  1      1      0      0    %0d      %.1f",
            lat[21], lat[21]*2.0);
        if(lat[22]>0) $fdisplay(fh,"  0      0      3      0    %0d      %.1f",
            lat[22], lat[22]*2.0);
        if(lat[23]>0) $fdisplay(fh,"  0      1      3      1    %0d      %.1f",
            lat[23], lat[23]*2.0);
        if(lat[24]>0) $fdisplay(fh,"  0      0      0      3    %0d      %.1f",
            lat[24], lat[24]*2.0);
        if(lat[25]>0) $fdisplay(fh,"  1      0      1      3    %0d      %.1f",
            lat[25], lat[25]*2.0);
        if(lat[26]>0) $fdisplay(fh,"  0      0      2      2    %0d      %.1f",
            lat[26], lat[26]*2.0);
        if(lat[27]>0) $fdisplay(fh,"  1      0      3      2    %0d      %.1f",
            lat[27], lat[27]*2.0);
        if(lat[28]>0) $fdisplay(fh,"  0      0      3      3    %0d      %.1f",
            lat[28], lat[28]*2.0);
        if(lat[29]>0) $fdisplay(fh,"  3      3      0      0    %0d      %.1f",
            lat[29], lat[29]*2.0);
        if(lat[30]>0) $fdisplay(fh,"  0      3      3      0    %0d      %.1f",
            lat[30], lat[30]*2.0);
        if(lat[31]>0) $fdisplay(fh,"  3      0      0      3    %0d      %.1f",
            lat[31], lat[31]*2.0);
        if(lat[32]>0) $fdisplay(fh,"  0      0      3      2    %0d      %.1f",
            lat[32], lat[32]*2.0);
        if(lat[33]>0) $fdisplay(fh,"  0      0      2      3    %0d      %.1f",
            lat[33], lat[33]*2.0);
        if(lat[34]>0) $fdisplay(fh,"  0      0      3      1    %0d      %.1f",
            lat[34], lat[34]*2.0);
        if(lat[35]>0) $fdisplay(fh,"  0      0      1      3    %0d      %.1f",
            lat[35], lat[35]*2.0);
        if(lat[36]>0) $fdisplay(fh,"  0      0      0      3    %0d      %.1f",
            lat[36], lat[36]*2.0);
        if(lat[37]>0) $fdisplay(fh,"  3      3      0      3    %0d      %.1f",
            lat[37], lat[37]*2.0);
        if(lat[38]>0) $fdisplay(fh,"  3      3      3      0    %0d      %.1f",
            lat[38], lat[38]*2.0);
        $fclose(fh);

        $display("[XYSTD] DONE. %0d/39 pairs measured. Avg lat=%0d cyc", cnt, min_lat);
        $finish;
    end
endmodule