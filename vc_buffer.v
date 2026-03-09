module vc_buffer (
    input clk,
    input rst,
    input ri,                 // send-in signal
    input [63:0] din,
    output reg [63:0] dout
);

always@(posedge clk) begin
    if (rst) begin
        dout <= 64'b0;
    end
    else if (ri) begin
        dout <= din;
    end
end

endmodule