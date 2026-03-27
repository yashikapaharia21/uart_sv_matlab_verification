// =============================================================================
// Project      : UART Transmitter Verification
// File         : uart_tx.sv
// Author       : Yashika Paharia
// Description  : Simple UART Transmitter (8N1 format)
//                8 data bits, No parity, 1 stop bit
//
// UART Protocol Recap:
//   - Line sits HIGH (idle) when not transmitting
//   - To send one byte: pull LOW (start bit), send 8 data bits LSB first,
//     then pull HIGH (stop bit)
//   - Bit timing is controlled by the baud rate clock divider (CLKS_PER_BIT)
//
// CLKS_PER_BIT = clock_frequency / baud_rate
// Example: 25 MHz clock, 115200 baud -> CLKS_PER_BIT = 217
// =============================================================================

`timescale 1ns/1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 217   // How many clock cycles each UART bit lasts
)(
    input  logic       clk,
    input  logic       rst_n,      // Active-low reset
    input  logic       tx_start,   // Pulse high for one cycle to begin sending
    input  logic [7:0] tx_data,    // The byte we want to transmit
    output logic       tx_serial,  // The actual UART TX line
    output logic       tx_busy,    // High while transmission is in progress
    output logic       tx_done     // Goes high for one cycle when done
);

    // -------------------------------------------------------------------------
    // State Machine Definition
    // A simple 4-state FSM to step through each part of the UART frame
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE  = 2'd0,   // Waiting for tx_start
        START = 2'd1,   // Sending the start bit (line LOW)
        DATA  = 2'd2,   // Sending the 8 data bits, LSB first
        STOP  = 2'd3    // Sending the stop bit (line HIGH)
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Internal Registers
    // -------------------------------------------------------------------------
    integer      clk_count;  // Counts clock cycles within each bit period
    logic [2:0]  bit_index;  // Which data bit we are currently sending (0 to 7)
    logic [7:0]  tx_data_r;  // Latch the input data when tx_start fires

    // -------------------------------------------------------------------------
    // FSM - Runs on every rising clock edge
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin

        // Reset everything to a known safe state
        if (!rst_n) begin
            state     <= IDLE;
            tx_serial <= 1'b1;   // Idle line is HIGH
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            clk_count <= 0;
            bit_index <= 3'd0;
            tx_data_r <= 8'h00;

        end else begin
            // Default: tx_done only pulses for one cycle
            tx_done <= 1'b0;

            case (state)

                // -------------------------------------------------------------
                // IDLE: Wait here until the user wants to send something
                // -------------------------------------------------------------
                IDLE: begin
                    tx_serial <= 1'b1;   // Keep line high
                    tx_busy   <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 3'd0;

                    if (tx_start) begin
                        tx_data_r <= tx_data;  // Latch the byte to send
                        tx_busy   <= 1'b1;
                        state     <= START;
                    end
                end

                // -------------------------------------------------------------
                // START: Pull line LOW for exactly one bit period
                // -------------------------------------------------------------
                START: begin
                    tx_serial <= 1'b0;   // Start bit is always LOW

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA;   // Move on to sending data bits
                    end
                end

                // -------------------------------------------------------------
                // DATA: Send each bit of the byte, LSB first
                //       Hold each bit for one full bit period
                // -------------------------------------------------------------
                DATA: begin
                    tx_serial <= tx_data_r[bit_index];   // Output current bit

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;

                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;  // Next bit
                        end else begin
                            bit_index <= 3'd0;
                            state     <= STOP;   // All 8 bits sent
                        end
                    end
                end

                // -------------------------------------------------------------
                // STOP: Hold line HIGH for one bit period, then signal done
                // -------------------------------------------------------------
                STOP: begin
                    tx_serial <= 1'b1;   // Stop bit is always HIGH

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        tx_done   <= 1'b1;   // Tell the outside world we finished
                        tx_busy   <= 1'b0;
                        state     <= IDLE;   // Ready for next byte
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule : uart_tx
