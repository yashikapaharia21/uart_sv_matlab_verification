// =============================================================================
// Project      : UART Transmitter Verification
// File         : uart_tx_tb.sv
// Author       : Yashika Paharia
// Description  : Simple directed testbench for the UART TX module.
//                Sends a handful of test bytes and checks that what comes out
//                on the TX line matches what went in.
//
// How it works:
//   1. Drive tx_start for one cycle with the byte we want to send
//   2. Wait for tx_busy to go high (transmission started)
//   3. Sample tx_serial at the mid-point of each bit period
//   4. Compare the sampled bits against the original byte
//   5. Report PASS or FAIL
// =============================================================================

`timescale 1ns/1ps

module uart_tx_tb;

    // -------------------------------------------------------------------------
    // Parameters - must match the DUT
    // -------------------------------------------------------------------------
    parameter CLK_PERIOD    = 40;                        // 25 MHz -> 40 ns per cycle
    parameter CLKS_PER_BIT  = 217;                       // 25 MHz / 115200 baud
    parameter BIT_PERIOD_NS = CLK_PERIOD * CLKS_PER_BIT; // ~8680 ns per UART bit

    // -------------------------------------------------------------------------
    // Signals connected to the DUT
    // -------------------------------------------------------------------------
    logic       clk;
    logic       rst_n;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_serial;
    logic       tx_busy;
    logic       tx_done;

    // -------------------------------------------------------------------------
    // Simple pass/fail counters
    // -------------------------------------------------------------------------
    integer tests_passed = 0;
    integer tests_failed = 0;
    integer test_num     = 0;

    // -------------------------------------------------------------------------
    // DUT Instantiation
    // -------------------------------------------------------------------------
    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    // -------------------------------------------------------------------------
    // Clock: toggles every half period to give 25 MHz
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Waveform dump (open in GTKWave to visualise)
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("sim/uart_tx_waves.vcd");
        $dumpvars(0, uart_tx_tb);
    end

    // -------------------------------------------------------------------------
    // MAIN TEST SEQUENCE
    // -------------------------------------------------------------------------
    initial begin
        $display("==============================================");
        $display("  UART TX Testbench");
        $display("  115200 baud | 25 MHz clock");
        $display("==============================================");

        // Release reset after a few cycles
        apply_reset();

        // --- Basic byte tests ---
        send_and_check(8'h41, "ASCII 'A'");         // 0100 0001
        send_and_check(8'h00, "All zeros");
        send_and_check(8'hFF, "All ones");
        send_and_check(8'hAA, "Alternating 10...");
        send_and_check(8'h55, "Alternating 01...");

        // --- Two bytes back-to-back ---
        $display("\n[INFO] Sending two bytes back-to-back...");
        send_and_check(8'h42, "Back-to-back byte 1 'B'");
        send_and_check(8'h43, "Back-to-back byte 2 'C'");

        // --- Print final summary ---
        $display("\n==============================================");
        $display("  RESULTS: %0d passed, %0d failed", tests_passed, tests_failed);
        if (tests_failed == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED - check output above");
        $display("==============================================\n");

        $finish;
    end

    // =========================================================================
    // TASKS
    // =========================================================================

    // -------------------------------------------------------------------------
    // apply_reset: hold reset low for 5 clock cycles then release
    // -------------------------------------------------------------------------
    task apply_reset();
        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_data  = 8'h00;
        repeat(5) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        $display("[RESET] Reset released at time %0t ns", $time);
    endtask

    // -------------------------------------------------------------------------
    // send_and_check: drive one UART byte and verify the output bit by bit
    // -------------------------------------------------------------------------
    task send_and_check(input logic [7:0] data, input string label);
        logic [7:0] received;
        logic       start_ok;
        logic       stop_ok;

        test_num++;

        // Kick off the transmission
        @(negedge clk);
        tx_data  = data;
        tx_start = 1'b1;
        @(negedge clk);
        tx_start = 1'b0;

        // Wait until the DUT starts driving (tx_busy goes high)
        @(posedge tx_busy);

        // Sample start bit at its midpoint - should be LOW
        #(BIT_PERIOD_NS / 2);
        start_ok = (tx_serial === 1'b0);

        // Sample each of the 8 data bits at mid-point
        for (int i = 0; i < 8; i++) begin
            #(BIT_PERIOD_NS);
            received[i] = tx_serial;   // UART sends LSB first
        end

        // Sample stop bit at midpoint - should be HIGH
        #(BIT_PERIOD_NS);
        stop_ok = (tx_serial === 1'b1);

        // Wait for the DUT to assert tx_done
        @(posedge tx_done);
        @(posedge clk);

        // ---- Report result ----
        if ((received === data) && start_ok && stop_ok) begin
            tests_passed++;
            $display("[PASS] Test %0d (%s): sent=0x%02h received=0x%02h",
                test_num, label, data, received);
        end else begin
            tests_failed++;
            $display("[FAIL] Test %0d (%s): sent=0x%02h received=0x%02h | start_ok=%b stop_ok=%b",
                test_num, label, data, received, start_ok, stop_ok);
        end

    endtask

    // -------------------------------------------------------------------------
    // Safety timeout - prevents the sim hanging forever if something goes wrong
    // -------------------------------------------------------------------------
    initial begin
        #20_000_000;  // 20 ms max
        $display("[TIMEOUT] Simulation took too long - check for a hang");
        $finish;
    end

endmodule : uart_tx_tb
