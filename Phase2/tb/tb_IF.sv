`timescale 1ns / 1ps

module tb_IF;

    logic clk, reset, branch_taken, stall;
    logic [31:0] branch_target, PC;

    // DUT
    instruction_fetch IF_unit (
        .clk(clk),
        .reset(reset),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .stall(stall),
        .PC(PC)
    );

    // Clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Drive safe default inputs
    task automatic drive_defaults();
        begin
            branch_taken  = 1'b0;
            branch_target = 32'h0000_0000;
            stall         = 1'b0;
        end
    endtask

    // Synchronous reset, released away from active clock edge
    task automatic apply_reset();
        begin
            drive_defaults();
            reset = 1'b1;

            // Hold reset across a couple of rising edges
            repeat (2) @(posedge clk);

            // Deassert on a falling edge to avoid race with DUT sampling
            @(negedge clk);
            reset = 1'b0;

            // Let NBA updates settle
            #1;
        end
    endtask

    // Wait n cycles and let NBA updates settle
    task automatic step_cycles(input int n);
        begin
            repeat (n) @(posedge clk);
            #1;
        end
    endtask

    task automatic check_pc(input logic [31:0] expected);
        begin
            if (PC !== expected) begin
                $fatal(1, "PC mismatch: expected %h, got %h", expected, PC);
            end
            else begin
                $display("[%0t] PC correct: %h", $time, PC);
            end
        end
    endtask

    initial begin
        // Initialize signals
        reset = 1'b0;
        drive_defaults();

        // --------------------------------------------------
        // Test 1: Reset behavior
        // --------------------------------------------------
        apply_reset();
        check_pc(32'h0000_0000);
        $display("Reset test passed");

        // --------------------------------------------------
        // Test 2: Normal increment behavior
        // PC should increment by 4 every cycle
        // --------------------------------------------------
        step_cycles(1);
        check_pc(32'h0000_0004);

        step_cycles(1);
        check_pc(32'h0000_0008);

        step_cycles(1);
        check_pc(32'h0000_000C);
        $display("Increment test passed");

        // --------------------------------------------------
        // Test 3: Stall behavior
        // PC should hold when stall=1
        // --------------------------------------------------
        stall = 1'b1;
        step_cycles(1);
        check_pc(32'h0000_000C);

        step_cycles(1);
        check_pc(32'h0000_000C);

        stall = 1'b0;
        step_cycles(1);
        check_pc(32'h0000_0010);
        $display("Stall test passed");

        // --------------------------------------------------
        // Test 4: Branch behavior
        // branch_taken has priority over normal increment
        // --------------------------------------------------
        branch_target = 32'h0000_0040;
        branch_taken  = 1'b1;
        step_cycles(1);
        check_pc(32'h0000_0040);

        branch_taken = 1'b0;
        step_cycles(1);
        check_pc(32'h0000_0044);
        $display("Branch test passed");

        // --------------------------------------------------
        // Test 5: Priority test (stall should hold PC even if branch_taken=1)
        // Your DUT currently checks stall before branch_taken.
        // --------------------------------------------------
        stall         = 1'b1;
        branch_taken  = 1'b1;
        branch_target = 32'h0000_0100;

        step_cycles(1);
        check_pc(32'h0000_0044);

        stall        = 1'b0;
        branch_taken = 1'b0;
        step_cycles(1);
        check_pc(32'h0000_0048);
        $display("Priority test passed");

        // --------------------------------------------------
        // Test 6: Reset overrides everything
        // --------------------------------------------------
        branch_taken  = 1'b1;
        branch_target = 32'h0000_0200;
        stall         = 1'b1;

        reset = 1'b1;
        step_cycles(1);
        check_pc(32'h0000_0000);

        reset = 1'b0;
        drive_defaults();
        step_cycles(1);
        check_pc(32'h0000_0004);
        $display("Reset override test passed");

        $display("All IF tests passed");
        $stop;
    end

endmodule