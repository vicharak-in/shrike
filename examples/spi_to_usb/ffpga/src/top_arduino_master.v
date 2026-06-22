// top_arduino_master -- FPGA top level for Arduino-as-SPI-master example.
//
// Data path: Arduino Uno (SPI master) -> FPGA external SPI target (GPIO 0,1,7,8)
//            -> internal latch -> FPGA RP2040 SPI target (GPIO 3,4,5,6) -> RP2040.
//
// The FPGA hosts two independent spi_target instances:
//   1. ext_target  : receives bytes from the Arduino on the external GPIO pins.
//   2. rp2040_target: receives dummy bytes from the RP2040 and returns the last
//                     byte received from the Arduino.
//
// When the Arduino sends a byte, it is latched into `arduino_byte` and the low
// bit is mirrored on the on-board LED. The RP2040 can read this byte at any
// time by performing an SPI transfer (the sent byte is ignored).
//
// FPGA pin map (Shrike FPGA GPIO numbers):
//   External (Arduino):  ext_sck=0(in) ext_mosi=1(in) ext_ss_n=7(in) ext_miso=8(out)
//   RP2040 (fixed link): spi_sck=3(in) spi_ss_n=4(in) spi_mosi=5(in) spi_miso=6(out)
//   Indicator:           led=16(out)
(* top *) module top (
    // System clock.
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,

    // RP2040 SPI link (FPGA is target).
    (* iopad_external_pin *) input spi_ss_n,
    (* iopad_external_pin *) input spi_sck,
    (* iopad_external_pin *) input spi_mosi,
    (* iopad_external_pin *) output spi_miso,
    (* iopad_external_pin *) output spi_miso_en,

    // External SPI link — Arduino is master, FPGA is target.
    (* iopad_external_pin *) input ext_ss_n,
    (* iopad_external_pin *) input ext_sck,
    (* iopad_external_pin *) input ext_mosi,
    (* iopad_external_pin *) output ext_miso,
    (* iopad_external_pin *) output ext_miso_en,

    // On-board LED.
    (* iopad_external_pin *) output reg led,
    (* iopad_external_pin *) output led_en
  );

  // -------------------------------------------------------------------------
  // Constant output enables.
  // -------------------------------------------------------------------------
  assign clk_en = 1'b1;
  assign led_en = 1'b1;

  // -------------------------------------------------------------------------
  // Power-on reset (internal, no external pin needed).
  // -------------------------------------------------------------------------
  reg [3:0] por_cnt = 4'd0;
  reg rst_n = 1'b0;

  always @(posedge clk)
  begin
    if (por_cnt != 4'hF)
      por_cnt <= por_cnt + 1'b1;
    rst_n <= (por_cnt == 4'hF);
  end

  // -------------------------------------------------------------------------
  // Latch for the last byte received from the Arduino.
  // -------------------------------------------------------------------------
  reg [7:0] arduino_byte;

  // -------------------------------------------------------------------------
  // External SPI target — receives bytes from the Arduino.
  // -------------------------------------------------------------------------
  wire [7:0] ext_rx_data;
  wire ext_rx_valid;

  spi_target #(
               .CPOL (1'b0),
               .CPHA (1'b0),
               .WIDTH (8),
               .LSB (1'b0)
             ) u_ext_target (
               .i_clk (clk),
               .i_rst_n (rst_n),
               .i_enable (1'b1),
               .i_ss_n (ext_ss_n),
               .i_sck (ext_sck),
               .i_mosi (ext_mosi),
               .o_miso (ext_miso),
               .o_miso_oe (ext_miso_en),
               .o_rx_data (ext_rx_data),
               .o_rx_data_valid (ext_rx_valid),
               .i_tx_data (arduino_byte),   // Echo back the previous byte.
               .o_tx_data_hold  ()
             );

  // Latch the Arduino byte and update the LED on each valid reception.
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      arduino_byte <= 8'h00;
      led <= 1'b0;
    end
    else if (ext_rx_valid)
    begin
      arduino_byte <= ext_rx_data;
      led <= ext_rx_data[0];
    end
  end

  // -------------------------------------------------------------------------
  // RP2040 SPI target — returns the last Arduino byte to the MCU.
  // -------------------------------------------------------------------------
  wire [7:0] rp_rx_data;   // Data from RP2040 (ignored).
  wire rp_rx_valid;

  spi_target #(
               .CPOL (1'b0),
               .CPHA (1'b0),
               .WIDTH (8),
               .LSB (1'b0)
             ) u_rp2040_target (
               .i_clk (clk),
               .i_rst_n (rst_n),
               .i_enable (1'b1),
               .i_ss_n (spi_ss_n),
               .i_sck (spi_sck),
               .i_mosi (spi_mosi),
               .o_miso (spi_miso),
               .o_miso_oe (spi_miso_en),
               .o_rx_data (rp_rx_data),
               .o_rx_data_valid (rp_rx_valid),
               .i_tx_data (arduino_byte),   // Return last Arduino byte.
               .o_tx_data_hold ()
             );

endmodule
