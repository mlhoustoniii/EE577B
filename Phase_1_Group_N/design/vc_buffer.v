`timescale 1ns/1ps
// ============================================================
// vc_buffer.v
// Cardinal Router -- Virtual Channel Buffer
//
// EE 577B -- Cardinal Router Project
//
// Purpose:
//   A simple 64-bit synchronous write register.
//   Holds exactly ONE 64-bit packet.
//
//   Per spec (slide 39):
//     "The buffer is as simple as a clocked synchronous
//      write register enabled by si."
//     "The output can be assumed to be available at all times."
//
//   All handshaking (ri, so, ro, full/empty flags) lives in
//   input_ctrl and output_ctrl -- NOT here.
//   This module is purely a storage element.
//
// Interface:
//   clk      -- clock (posedge active)
//   reset    -- synchronous active-high reset (clears buffer to 0)
//   write_en -- write enable (driven by input_ctrl or output_ctrl)
//   di[63:0] -- 64-bit data in
//   do[63:0] -- 64-bit data out (continuously driven, no read enable)
//
// Behavior:
//   reset=1:     do <= 0   (at posedge)
//   write_en=1:  do <= di  (at posedge)
//   write_en=0:  do holds  (no change)
//
// NOTE: No si/ri/so/ro ports -- those belong to the controllers.
// ============================================================

module vc_buffer (
    input  wire        clk,
    input  wire        reset,

    input  wire        write_en,    // Write enable: latch di on posedge
    input  wire [63:0] di,          // 64-bit packet data in

    output reg  [63:0] do           // 64-bit packet data out (always valid)
);

    // ----------------------------------------------------------
    // Synchronous write register
    //
    // On reset:     clear to zero
    // On write_en:  latch di into do
    // Otherwise:    hold current value
    //
    // do is continuously driven (output reg with no tri-state)
    // so the arbiter mux can read it any cycle without a read enable
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (reset)
            do <= 64'h0;
        else if (write_en)
            do <= di;
        // else: hold -- no assignment needed (reg retains value)
    end

endmodule
