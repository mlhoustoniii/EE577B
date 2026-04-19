`timescale 1ns/10ps
// ============================================================
//  IF STAGE - Instruction Fetch
// ============================================================
module instruction_fetch(
    input clk,
    input reset,
    input branch_taken,
    input [31:0] branch_target,
    input stall,
    output reg [31:0] PC
);

    // PC update logic
    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'h0000_0000;
        end else if (stall) begin
            PC <= PC; // Hold PC on stall
        end else if (branch_taken) begin
            PC <= branch_target;
        end else begin
            PC <= PC + 32'd4;
        end
    end

endmodule