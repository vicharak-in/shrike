module spi_target (
    input clk,
    input sck,
    input mosi,
    input ss,
    output reg wr_en,
    output reg [10:0] wr_addr,
    output reg [7:0] wr_data
  );
  // Synchronizers
  reg [2:0] sck_sync;
  reg [1:0] mosi_sync;
  reg [1:0] ss_sync;

  always @(posedge clk)
  begin
    sck_sync <= {sck_sync[1:0], sck};
    mosi_sync <= {mosi_sync[0], mosi};
    ss_sync <= {ss_sync[0], ss};
  end

  wire sck_rise = (sck_sync[2:1] == 2'b01);
  wire ss_active = ~ss_sync[1];
  wire ss_fall = (ss_sync[1:0] == 2'b10);

  reg [2:0] bit_cnt;
  reg [7:0] shift_reg;

  always @(posedge clk)
  begin
    wr_en <= 1'b0; // Default: no write

    if (ss_fall)
    begin
      // Reset state on new SPI transaction
      bit_cnt <= 3'd0;
      wr_addr <= 11'h7FF; // Will wrap to 0 on first byte
    end
    else if (ss_active)
    begin
      if (sck_rise)
      begin
        shift_reg <= {shift_reg[6:0], mosi_sync[1]};
        bit_cnt <= bit_cnt + 1;

        if (bit_cnt == 3'd7)
        begin
          // Full byte received
          wr_data <= {shift_reg[6:0], mosi_sync[1]};
          wr_addr <= wr_addr + 1;
          wr_en <= 1'b1;
        end
      end
    end
  end

endmodule
