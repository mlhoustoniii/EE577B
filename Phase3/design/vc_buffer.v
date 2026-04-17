`timescale 1ns/1ps
// ============================================================
// vc_buffer.v
// Cardinal Router -- Virtual Channel Buffer
//
// Purpose:
//   A simple 64-bit synchronous write register.
//   Holds exactly ONE 64-bit packet.
//
//      write register will be enabled by si."
//
// Behavior:
//   reset=1:     do <= 0   (at posedge)
//   write_en=1:  do <= di  (at posedge)
//   write_en=0:  do holds  (no change)
//
// ============================================================

module vc_buffer (
    input  wire        clk,
    input  wire        reset,

    input  wire        write_en,    
    input  wire [63:0] di,          // 64-bit packet data in

    output reg  [63:0] do           // 64-bit packet data out
);

    always @(posedge clk) begin
        if (reset)
            do <= 64'h0;
        else if (write_en)  // Write enable: latch di on posedge
            do <= di;
    end

endmodule
