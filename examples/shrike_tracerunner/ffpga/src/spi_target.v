`timescale 1ns / 1ps

// ============================================================================
// Module: spi_target.v
// Architecture: Renesas ForgeFPGA SLG47910 / Vicharak Shrike-Fi
// Purpose: Synchronous SPI Slave/Target interface (Mode 0: CPOL=0, CPHA=0)
// ============================================================================
//
// HOW SPI WORKS ON AN FPGA:
// In microcontrollers, SPI is usually handled by dedicated silicon hardware.
// In an FPGA, there is no hard-wired SPI controller: we build the shift registers,
// edge detectors, and state machines directly using digital logic gates!
//
// SPI Mode 0 Characteristics:
// - Clock is LOW when idle (CPOL = 0)
// - Data on MOSI is sampled on the RISING edge of SCK (CPHA = 0)
// - Data on MISO is driven on the FALLING edge of SCK
//
// Clock Domain Crossing (CDC):
// The SPI clock (i_sck) comes asynchronously from the ESP32-S3.
// To prevent metastability inside the FPGA, we use a 3-stage flip-flop
// synchronizer (r_sck_sync and r_ss_n_sync) clocked by the FPGA's internal 50MHz clock.
// ============================================================================

module spi_target #(
    parameter WIDTH = 8  // 8-bit SPI packet width
) (
    // Internal FPGA System Clock and Reset
    input  wire             i_clk,           // Internal 50 MHz oscillator
    input  wire             i_rst_n,         // Active-low reset
    input  wire             i_enable,        // Module enable (tied high)

    // Physical SPI Pins connected to ESP32-S3
    input  wire             i_ss_n,          // Slave Select (Active Low from ESP32 GPIO 10)
    input  wire             i_sck,           // SPI Clock (from ESP32 GPIO 12)
    input  wire             i_mosi,          // Master Out Slave In (from ESP32 GPIO 11)
    output wire             o_miso,          // Master In Slave Out (to ESP32 GPIO 13)
    output wire             o_miso_oe,       // Tristate Output Enable for MISO

    // Internal User Logic Interface
    output reg  [WIDTH-1:0] o_rx_data,       // Parallel byte received from ESP32
    output reg              o_rx_data_valid, // 1-clock-cycle pulse when a byte is ready
    input  wire [WIDTH-1:0] i_tx_data,       // Parallel byte to send back to ESP32
    output wire             o_tx_data_hold   // Strobe indicating when tx_data is latched
);

    // ------------------------------------------------------------------------
    // 1. Clock Domain Crossing (CDC) Synchronization Registers
    // ------------------------------------------------------------------------
    reg [2:0] r_ss_n_sync;
    reg [2:0] r_sck_sync;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_ss_n_sync <= 3'b111;
            r_sck_sync  <= 3'b000;
        end else if (i_enable) begin
            r_ss_n_sync <= {r_ss_n_sync[1:0], i_ss_n};
            r_sck_sync  <= {r_sck_sync[1:0], i_sck};
        end
    end

    // Detect SCK edges in the FPGA 50MHz clock domain
    wire w_sck_r_edge = (~r_sck_sync[2] & r_sck_sync[1]); // Rising edge
    wire w_sck_f_edge = (r_sck_sync[2] & ~r_sck_sync[1]); // Falling edge
    wire w_cs_active  = ~r_ss_n_sync[1];                   // CS is LOW

    // ------------------------------------------------------------------------
    // 2. Bit Counter (0 to 7)
    // ------------------------------------------------------------------------
    reg [2:0] r_bit_count;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_bit_count <= 3'd0;
        end else if (!w_cs_active) begin
            r_bit_count <= 3'd0;
        end else if (w_sck_r_edge) begin
            if (r_bit_count == 3'd7) begin
                r_bit_count <= 3'd0;
            end else begin
                r_bit_count <= r_bit_count + 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // 3. Receiver (MOSI -> Parallel Output)
    // ------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_rx_data       <= {WIDTH{1'b0}};
            o_rx_data_valid <= 1'b0;
        end else begin
            o_rx_data_valid <= 1'b0; // Default: pulse is 1 cycle long

            if (w_cs_active && w_sck_r_edge) begin
                // Shift in MSB first
                o_rx_data <= {o_rx_data[WIDTH-2:0], i_mosi};

                // When last bit arrives, assert valid strobe
                if (r_bit_count == 3'd7) begin
                    o_rx_data_valid <= 1'b1;
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // 4. Transmitter (Parallel Input -> MISO Shift Register)
    // ------------------------------------------------------------------------
    reg [WIDTH-1:0] r_miso_shift;

    // Strobe to reload TX data when CS goes active or byte completes
    assign o_tx_data_hold = (r_ss_n_sync[2] & ~r_ss_n_sync[1]) | 
                            (w_cs_active && (r_bit_count == 3'd0) && w_sck_f_edge);

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_miso_shift <= {WIDTH{1'b0}};
        end else if (o_tx_data_hold) begin
            r_miso_shift <= i_tx_data; // Latch fresh data to send
        end else if (w_cs_active && w_sck_f_edge) begin
            r_miso_shift <= {r_miso_shift[WIDTH-2:0], 1'b0}; // Shift left on falling edge
        end
    end

    // Drive MISO with MSB of shift register
    assign o_miso    = r_miso_shift[WIDTH-1];
    
    // Tristate control: Only drive MISO when Chip Select is asserted (LOW)
    assign o_miso_oe = w_cs_active;

endmodule
