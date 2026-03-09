`timescale 1ns/1ps

module rr_arbiter (
    input  wire        clk,
    input  wire        rst,
    input  wire        polarity,          // 0=even cycle, 1=odd cycle
    input  wire [3:0]  request,           // One-hot requests from 4 input controllers (only 4 because a PE cannot request itself)
    input  wire        buffer_free,  // Output buffer free? Driven by output_ctrl
    output wire [3:0]  grant              // One-hot grant: combinational (Mealy)
);

    // Priority pointers — one per VC type per spec:
    // 2-bit: 00=input0 has priority, 01=input1, 10=input2, 11=input3
    // ------------------------------------------------------------------
    reg [1:0] priority_ptr_even;
    reg [1:0] priority_ptr_odd;

    // Select active pointer based on current clock cycle polarity
    wire [1:0] current_ptr;
    assign current_ptr = (polarity == 1'b0) ? priority_ptr_even : priority_ptr_odd; // Assigns bits 0-3 to the even VC or the odd VC

    // Contention detection: 2 or more inputs requesting simultaneously
    // ------------------------------------------------------------------
    wire contention;
    assign contention = (request[0] & request[1]) |
                        (request[0] & request[2]) |
                        (request[0] & request[3]) |
                        (request[1] & request[2]) |
                        (request[1] & request[3]) |
                        (request[2] & request[3]);

    // ------------------------------------------------------------------
    // Combinational grant logic (Mealy)
    // Only grant if buffer is available and at least one request is active
    // ------------------------------------------------------------------
    reg [3:0] grant_comb;

    always @(*) begin
        grant_comb = 4'b0000; // Default: no grant

        if ((|request) && buffer_free) begin // checks if there are any requests at all (any of the bits high)

            if (!contention) begin
                // No contention: grant whoever is requesting
                // Priority pointer is completely bypassed and unchanged
                grant_comb = request;

            end else begin
                // Contention: walk priority chain from current pointer
                case (current_ptr) // Checks which inputs0 - inputs 3 (00, 01, 10, 11) is given arbiter priority
                    2'd0: begin
                        // Priority order: 0 > 1 > 2 > 3
                        if      (request[0]) grant_comb = 4'b0001; // 0th requester has highest priority
                        else if (request[1]) grant_comb = 4'b0010;
                        else if (request[2]) grant_comb = 4'b0100;
                        else                 grant_comb = 4'b1000; // 3rd requester has lowest priority
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
    end

    // Grant is purely combinational — Mealy output
    assign grant = grant_comb;

    // Priority pointer update — sequential
    // ONLY advance pointer when contention occurred, per spec:
    always @(posedge clk) begin
        if (rst) begin
            priority_ptr_even <= 2'd0;
            priority_ptr_odd  <= 2'd0;
        end
        else if (contention && buffer_free) begin
            if (polarity == 1'b0) begin
                // Update even VC pointer
                case (grant_comb)
                    4'b0001: priority_ptr_even <= 2'd1; // granted 0, next priority is 1
                    4'b0010: priority_ptr_even <= 2'd2; // granted 1, next priority is 2
                    4'b0100: priority_ptr_even <= 2'd3; // granted 2, next priority is 3
                    4'b1000: priority_ptr_even <= 2'd0; // granted 3, wrap to 0
                    default:  priority_ptr_even <= priority_ptr_even;
                endcase
            end
            else begin
                // Update odd VC pointer
                case (grant_comb)
                    4'b0001: priority_ptr_odd <= 2'd1; // granted 0, next priority is 1
                    4'b0010: priority_ptr_odd <= 2'd2; // granted 1, next priority is 2
                    4'b0100: priority_ptr_odd <= 2'd3; // granted 2, next priority is 3
                    4'b1000: priority_ptr_odd <= 2'd0; // granted 3, wrap to 0
                    default:  priority_ptr_odd <= priority_ptr_odd;
                endcase
            end
        end
        // No contention = pointer unchanged (spec requirement)
    end

endmodule