`timescale 1ns/1ps

module tb_output_ctrl;

    // Clock and reset
    reg         clk;
    reg         reset;
    reg         polarity;

    // Requests
    reg  [3:0]  request_even;
    reg  [3:0]  request_odd;

    // Data inputs
    reg  [63:0] di_even_0;
    reg  [63:0] di_even_1;
    reg  [63:0] di_even_2;
    reg  [63:0] di_even_3;
    reg  [63:0] di_odd_0;
    reg  [63:0] di_odd_1;
    reg  [63:0] di_odd_2;
    reg  [63:0] di_odd_3;

    // Outputs
    wire [3:0]  grant_even;
    wire [3:0]  grant_odd;
    wire        so;
    wire [63:0] do_ext;

    // Downstream ready
    reg         ro;

    // Clock generation
    initial clk = 0;
    always #4 clk = ~clk;

    output_ctrl uut (
        .clk          (clk),
        .reset        (reset),
        .polarity     (polarity),
        .request_even (request_even),
        .request_odd  (request_odd),
        .di_even_0    (di_even_0),
        .di_even_1    (di_even_1),
        .di_even_2    (di_even_2),
        .di_even_3    (di_even_3),
        .di_odd_0     (di_odd_0),
        .di_odd_1     (di_odd_1),
        .di_odd_2     (di_odd_2),
        .di_odd_3     (di_odd_3),
        .grant_even   (grant_even),
        .grant_odd    (grant_odd),
        .so           (so),
        .ro           (ro),
        .do_ext       (do_ext)
    );

always @(posedge clk) begin
    if (reset)
        polarity <= 1'b0;
    else
        polarity <= ~polarity;  // make polarity half the frequency of the clock
end

initial begin
    reset = 1; polarity = 0; ro = 1; request_even = 4'b0000; request_odd = 4'b0000;
    #8
    reset = 0;
    #8
    request_even = 4'b0001; // Slot 0 input request into router
    di_even_0 = 64'hABCDABCD;
    #8

end

endmodule