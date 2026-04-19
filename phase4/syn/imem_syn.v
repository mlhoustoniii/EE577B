///////////////////////////////////////////////////////////////////
// imem_syn.v -- TRUE BLACK BOX for synthesis (Phase 4 FINAL)
// EE 577B Spring 2026
//
// No internal logic = DC cannot propagate constants through this.
// DC treats all outputs as completely unknown/non-constant.
// This is what the Phase 4 README means by "blackbox imem/dmem".
///////////////////////////////////////////////////////////////////
`timescale 1ns/10ps

module imem (memAddr, dataOut);
    input  [0:7]  memAddr;
    output [0:31] dataOut;
    // No logic -- true black box
    // DC will treat dataOut as completely unknown
endmodule
