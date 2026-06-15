// spi_target -- SPI slave (target) for the FPGA side of the RP2040 link.
//
// Receives bytes from an external SPI master on i_sck/i_ss_n/i_mosi and shifts
// out i_tx_data on o_miso, full-duplex, MSB- or LSB-first (LSB parameter).
// i_sck and i_ss_n are double-flopped into the system clock domain to avoid
// metastability, and edges are detected from the synchronized signals. The
// captured byte is presented on o_rx_data with a one-cycle o_rx_data_valid
// strobe. o_miso_oe drives the MISO pad output-enable so the line is only
// driven while the target is selected. Mode 0 (CPOL=0, CPHA=0) by default.
module spi_target #(
    parameter CPOL = 1'b0,
    parameter CPHA = 1'b0,
    parameter WIDTH = 8,
    parameter LSB = 1'b0
  ) (
    input i_clk,
    input i_rst_n,
    input i_enable,
    input i_ss_n,
    input i_sck,
    input i_mosi,
    output reg o_miso,
    output reg o_miso_oe,
    output reg [WIDTH-1:0] o_rx_data,
    output reg o_rx_data_valid,
    input [WIDTH-1:0] i_tx_data,
    output reg o_tx_data_hold
  );
  localparam [2:0] BIT_MAX = WIDTH[2:0] - 3'd1;

  reg [1:0] sck_sync;
  reg [1:0] ss_sync;
  reg [2:0] bit_cnt;
  reg [WIDTH-1:0] rx_shift;
  reg [WIDTH-1:0] tx_shift;

  wire sck_r = (sck_sync == 2'b01);   // rising edge of synchronized SCK
  wire sck_f = (sck_sync == 2'b10);   // falling edge of synchronized SCK
  wire ss_n = ss_sync[1];            // synchronized chip select

  // Synchronize the asynchronous SCK and SS_n inputs into the clk domain.
  always @(posedge i_clk or negedge i_rst_n)
  begin
    if (!i_rst_n)
    begin
      sck_sync <= 2'b00;
      ss_sync <= 2'b11;
    end
    else
    begin
      sck_sync <= {sck_sync[0], i_sck};
      ss_sync <= {ss_sync[0], i_ss_n};
    end
  end

  // Shift register: sample MOSI on rising SCK, update MISO on falling SCK.
  always @(posedge i_clk or negedge i_rst_n)
  begin
    if (!i_rst_n)
    begin
      bit_cnt <= 0;
      rx_shift <= 0;
      tx_shift <= 0;
      o_rx_data <= 0;
      o_rx_data_valid <= 0;
      o_miso <= 0;
      o_miso_oe <= 0;
      o_tx_data_hold <= 0;
    end
    else
    begin
      o_rx_data_valid <= 0;
      if (ss_n)
      begin
        // Deselected: reload transmit data and present its first bit.
        bit_cnt <= 0;
        tx_shift <= i_tx_data;
        o_miso <= (LSB) ? i_tx_data[0] : i_tx_data[WIDTH-1];
        o_miso_oe <= 0;
      end
      else if (i_enable)
      begin
        o_miso_oe <= 1;
        if (sck_r)
        begin
          if (LSB)
            rx_shift <= {i_mosi, rx_shift[WIDTH-1:1]};
          else
            rx_shift <= {rx_shift[WIDTH-2:0], i_mosi};

          bit_cnt <= bit_cnt + 1;

          if (bit_cnt == BIT_MAX)
          begin
            if (LSB)
              o_rx_data <= {i_mosi, rx_shift[WIDTH-1:1]};
            else
              o_rx_data <= {rx_shift[WIDTH-2:0], i_mosi};
            o_rx_data_valid <= 1;
          end
        end
        if (sck_f)
        begin
          if (LSB)
          begin
            tx_shift <= {1'b0, tx_shift[WIDTH-1:1]};
            o_miso <= tx_shift[1];
          end
          else
          begin
            tx_shift <= {tx_shift[WIDTH-2:0], 1'b0};
            o_miso <= tx_shift[WIDTH-2];
          end
        end
      end
    end
  end
endmodule
