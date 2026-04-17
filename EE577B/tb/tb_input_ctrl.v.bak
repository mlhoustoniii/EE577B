`timescale 1ns/1ps

module tb_input_ctrl;

reg clk;
reg reset;
reg polarity;
reg si;                 
reg [63:0] din;        
reg grant_even;
reg grant_odd;

wire [4:0] request_even;
wire [4:0] request_odd;
wire ri;
wire [63:0] dout_even;
wire [63:0] dout_odd;

input_ctrl #(
    .ROUTER_X(1),   // Router under test is located at 1,1
    .ROUTER_Y(1)
) uut (
    .clk        (clk),
    .reset      (reset),
    .polarity   (polarity),
    .si         (si),
    .ri         (ri),
    .din        (din),
    .request_even(request_even),
    .request_odd (request_odd),
    .grant_even (grant_even),
    .grant_odd  (grant_odd),
    .dout_even  (dout_even),
    .dout_odd   (dout_odd)
);

initial begin
    clk = 0;
    polarity = 0;   // initialize to known state
end

always #2 clk = ~clk;

always @(posedge clk)
    polarity <= ~polarity;

// hang detection
initial begin
    #10000;
    $display("TIMEOUT");
    $finish;
end

// just drives din and si, no timing inside
task drive_packet;
    input [63:0] pkt;
    begin
        din = pkt;
        si  = 1;        // Announce that a packet is being sent, and treat it as valid
    end
endtask

task clear_si;
    begin
        si = 0;
    end
endtask

task apply_grant_even;
    begin
        grant_even = 1;
    end
endtask

task apply_grant_odd;
    begin
        grant_odd = 1;
    end
endtask

initial begin
    reset = 1; si = 0; din = 64'b0; grant_even = 0; grant_odd = 0;
    repeat(2) @(posedge clk);
    #1;
    reset = 0;
    repeat(2) @(posedge clk);  // let ri settle after reset
    #1;

    // East:  dest_x > ROUTER_X
    wait(ri == 1);

    // East:  dest_x > ROUTER_X
    wait(ri == 1);  // Only send when downstream router's buffer is free
    @(posedge clk);
    #1;
    drive_packet({1'b0, 2'd2, 2'd1, 2'd1, 2'd1, 23'b0, 32'hAAAA_AAAA});
    @(posedge clk);
    #1;
    clear_si;
    wait(polarity == 1'b0);     // even vc requests on even cycles
    @(posedge clk);
    if (request_even !== 5'b00100)
        $display("FAIL east: expected %b got %b", 5'b00100, request_even);
    else
        $display("PASS east: request_even=%b", request_even);
    #1;
    grant_even = 1;
    @(posedge clk);
    #1;
    grant_even = 0;

    // West:  dest_x < ROUTER_X
    wait(ri == 1);
    @(posedge clk);
    #1;
    drive_packet({1'b0, 2'd0, 2'd1, 2'd1, 2'd1, 23'b0, 32'hBBBB_BBBB});
    @(posedge clk);
    #1;
    clear_si;
    wait(polarity == 1'b0);
    @(posedge clk);
    if (request_even !== 5'b01000)
        $display("FAIL west: expected %b got %b", 5'b01000, request_even);
    else
        $display("PASS west: request_even=%b", request_even);
    #1;
    grant_even = 1;
    @(posedge clk);
    #1;
    grant_even = 0;

    // North: dest_x matches, dest_y > ROUTER_Y
    wait(ri == 1);
    @(posedge clk);
    #1;
    drive_packet({1'b0, 2'd1, 2'd2, 2'd1, 2'd1, 23'b0, 32'hCCCC_CCCC});
    @(posedge clk);
    #1;
    clear_si;
    wait(polarity == 1'b0);
    @(posedge clk);
    if (request_even !== 5'b00001)
        $display("FAIL north: expected %b got %b", 5'b00001, request_even);
    else
        $display("PASS north: request_even=%b", request_even);
    #1;
    grant_even = 1;
    @(posedge clk);
    #1;
    grant_even = 0;

    // South: dest_x matches, dest_y < ROUTER_Y
    wait(ri == 1);
    @(posedge clk);
    #1;
    drive_packet({1'b0, 2'd1, 2'd0, 2'd1, 2'd1, 23'b0, 32'hDDDD_DDDD});
    @(posedge clk);
    #1;
    clear_si;
    wait(polarity == 1'b0);
    @(posedge clk);
    if (request_even !== 5'b00010)
        $display("FAIL south: expected %b got %b", 5'b00010, request_even);
    else
        $display("PASS south: request_even=%b", request_even);
    #1;
    grant_even = 1;
    @(posedge clk);
    #1;
    grant_even = 0;

    // PE:    dest matches router coordinates exactly
    wait(ri == 1);
    @(posedge clk);
    #1;
    drive_packet({1'b0, 2'd1, 2'd1, 2'd1, 2'd1, 23'b0, 32'hEEEE_EEEE});
    @(posedge clk);
    #1;
    clear_si;
    wait(polarity == 1'b0);
    @(posedge clk);
    if (request_even !== 5'b10000)
        $display("FAIL pe: expected %b got %b", 5'b10000, request_even);
    else
        $display("PASS pe: request_even=%b", request_even);
    #1;
    grant_even = 1;
    @(posedge clk);
    #1;
    grant_even = 0;

    // wrong polarity test — odd vc packet sent on even cycle, should be dropped
    wait(polarity == 1'b0);
    @(posedge clk);
    #1;
    din = {1'b1, 2'd2, 2'd1, 2'd1, 2'd1, 23'b0, 32'hDEAD_BEEF};
    si  = 1;
    @(posedge clk);
    #1;
    si  = 0;
    @(posedge clk);
    if (request_odd !== 5'b0)
        $display("FAIL: wrong polarity packet was accepted");
    else
        $display("PASS: wrong polarity packet correctly dropped");

    $display("all tests done");
    $stop;
end

endmodule