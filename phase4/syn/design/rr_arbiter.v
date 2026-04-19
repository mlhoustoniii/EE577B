`timescale 1ns/1ps
// ============================================================
// rr_arbiter.v
//
// Purpose:
//   Arbitrates between up to 4 simultaneous input_ctrl requests
//   for a single output port. Uses round-robin to ensure fairness.
//
// Key Design Decisions:
//
//   1. Combinational (Mealy) grant output:
//      grant responds within the same cycle as request.
//
//   2. Separate priority pointers per VC type (even/odd):
//
//   3. Pointer only advances on contention:
//
// Port Description:
//   polarity         -- 0=even cycle, 1=odd cycle (from router)
//   request[3:0]     -- one-hot request from 4 input slots
//   output_available -- output buffer free this cycle (signal asserted by output controller)
//   grant[3:0]       -- one-hot grant (combinational Mealy output)
//
// ============================================================

module rr_arbiter (
    input  wire        clk,
    input  wire        reset,

    input  wire        polarity,          // 0=even cycle, 1=odd cycle
    input  wire [3:0]  request,           // One-hot requests from 4 inputs
    input  wire        output_available,  // Output buffer free this cycle

    output wire [3:0]  grant             // One-hot grant (Mealy -- same cycle)
);

    // ----------------------------------------------------------
    // Priority pointers -- one per VC type
    //
    // 2-bit encoding:
    //   2'b00 = slot 0 has highest priority
    //   2'b01 = slot 1 has highest priority
    //   2'b10 = slot 2 has highest priority
    //   2'b11 = slot 3 has highest priority
    //
    // Selected based on current polarity:
    //   polarity=0 (even cycle) -> use priority_ptr_even
    //   polarity=1 (odd  cycle) -> use priority_ptr_odd
    // ----------------------------------------------------------
    reg [1:0] priority_ptr_even;
    reg [1:0] priority_ptr_odd;

    wire [1:0] current_ptr;
    assign current_ptr = (polarity == 1'b0) ? priority_ptr_even
                                             : priority_ptr_odd;

    // ----------------------------------------------------------
    // Contention detection
    //
    // Pointer only advances when contention occurs.
    // ----------------------------------------------------------
    wire contention;
    assign contention = (request[0] & request[1]) |
                        (request[0] & request[2]) |
                        (request[0] & request[3]) |
                        (request[1] & request[2]) |
                        (request[1] & request[3]) |
                        (request[2] & request[3]);

    // ----------------------------------------------------------
    // Combinational grant logic (Mealy)
    // ----------------------------------------------------------
    reg [3:0] grant_comb;

    always @(*) begin
        grant_comb = 4'b0000; // Default: no grant

        if ((|request) && output_available) begin
            case (current_ptr)
                2'd0: begin
                    // Priority order: 0 > 1 > 2 > 3
                    if      (request[0]) grant_comb = 4'b0001;
                    else if (request[1]) grant_comb = 4'b0010;
                    else if (request[2]) grant_comb = 4'b0100;
                    else                 grant_comb = 4'b1000;
                end
                2'd1: begin
                    // Priority order: 1 > 2 > 3 > 0
                    if      (request[1]) grant_comb = 4'b0010;
                    else if (request[2]) grant_comb = 4'b0100;
                    else if (request[3]) grant_comb = 4'b1000;
                    else                 grant_comb = 4'b0001;
                end
                2'd2: begin
                    // Priority order: 2 > 3 > 0 > 1
                    if      (request[2]) grant_comb = 4'b0100;
                    else if (request[3]) grant_comb = 4'b1000;
                    else if (request[0]) grant_comb = 4'b0001;
                    else                 grant_comb = 4'b0010;
                end
                2'd3: begin
                    // Priority order: 3 > 0 > 1 > 2
                    if      (request[3]) grant_comb = 4'b1000;
                    else if (request[0]) grant_comb = 4'b0001;
                    else if (request[1]) grant_comb = 4'b0010;
                    else                 grant_comb = 4'b0100;
                end
                default: grant_comb = 4'b0000;
            endcase
        end
    end

    // Grant is purely combinational -- Mealy output
    assign grant = grant_comb;

    // ----------------------------------------------------------
    // Priority pointer update -- sequential
    // Rule: pointer advances ONLY when contention occurred AND
    //       output was available AND at least one request was active
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            priority_ptr_even <= 2'd0;
            priority_ptr_odd  <= 2'd0;
        end
        else if (contention && output_available && (|request)) begin
            if (polarity == 1'b0) begin
                // Even cycle: update even VC priority pointer
                case (grant_comb)
                    4'b0001: priority_ptr_even <= 2'd1; // granted 0 -> next is 1
                    4'b0010: priority_ptr_even <= 2'd2; // granted 1 -> next is 2
                    4'b0100: priority_ptr_even <= 2'd3; // granted 2 -> next is 3
                    4'b1000: priority_ptr_even <= 2'd0; // granted 3 -> wrap to 0
                    default:  priority_ptr_even <= priority_ptr_even;
                endcase
            end
            else begin
                // Odd cycle: update odd VC priority pointer
                case (grant_comb)
                    4'b0001: priority_ptr_odd <= 2'd1;  // If request[0] had priority, now give to request[1]
                    4'b0010: priority_ptr_odd <= 2'd2;
                    4'b0100: priority_ptr_odd <= 2'd3;
                    4'b1000: priority_ptr_odd <= 2'd0;
                    default:  priority_ptr_odd <= priority_ptr_odd;
                endcase
            end
            // No contention = pointer unchanged (spec requirement)
        end
    end

endmodule
