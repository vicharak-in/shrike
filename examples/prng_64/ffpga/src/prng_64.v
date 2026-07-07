// prng_64.v
// 64-bit hardware PRNG
// Runs a small chi + rotate avalanche loop in pure combinational logic.

(* top *) module prng_64 (
  (* iopad_external_pin, clkbuf_inhibit *) input wire clk,
  (* iopad_external_pin *) output wire clk_en,

  // SPI interface
  (* iopad_external_pin *) input wire spi_sck,
  (* iopad_external_pin *) input wire spi_ss_n,
  (* iopad_external_pin *) input wire spi_mosi,
  (* iopad_external_pin *) output wire spi_miso,
  (* iopad_external_pin *) output wire spi_miso_oe
);

assign clk_en = 1'b1;

// power on reset, counts down for a few cycles then releases
reg [3:0] rst_ctr = 4'hF;
always @(posedge clk) if (rst_ctr != 4'h0) rst_ctr <= rst_ctr - 4'h1;
wire por_resetn = (rst_ctr == 4'h0);

// spi target 
wire [7:0] spi_rx_data;
wire spi_rx_valid;
reg [7:0] spi_tx_data;
wire spi_tx_hold;
wire miso_oe_sig;
assign spi_miso_oe = miso_oe_sig;

spi #(.CPOL(1'b0), .CPHA(1'b0), .WIDTH(8), .LSB(1'b0)) u_spi (
  .i_clk(clk), .i_rst_n(por_resetn), .i_enable(1'b1),
  .i_ss_n(spi_ss_n), .i_sck(spi_sck), .i_mosi(spi_mosi),
  .o_miso(spi_miso), .o_miso_oe(miso_oe_sig),
  .o_rx_data(spi_rx_data), .o_rx_data_valid(spi_rx_valid),
  .i_tx_data(spi_tx_data), .o_tx_data_hold(spi_tx_hold)
);

// 64 bit state register, fixed starting value on reset
reg [63:0] state = 64'h61707865_3320646E;

// three rounds of chi (nonlinear mix) followed by two rotate xors (diffusion)
wire [63:0] r1_chi = state ^ (~{state[62:0], state[63]} & {state[61:0], state[63:62]});
wire [63:0] r1_out = r1_chi ^ {r1_chi[56:0], r1_chi[63:57]} ^ {r1_chi[45:0], r1_chi[63:46]};

wire [63:0] r2_chi = r1_out ^ (~{r1_out[62:0], r1_out[63]} & {r1_out[61:0], r1_out[63:62]});
wire [63:0] r2_out = r2_chi ^ {r2_chi[56:0], r2_chi[63:57]} ^ {r2_chi[45:0], r2_chi[63:46]};

wire [63:0] r3_chi = r2_out ^ (~{r2_out[62:0], r2_out[63]} & {r2_out[61:0], r2_out[63:62]});
wire [63:0] r3_out = r3_chi ^ {r3_chi[56:0], r3_chi[63:57]} ^ {r3_chi[45:0], r3_chi[63:46]};

// spi output byte, latched when the mcu asks for data
reg [7:0] spi_out_buffer;

always @(posedge clk or negedge por_resetn) begin
  if (!por_resetn) begin
    state <= 64'h61707865_3320646E;
    spi_out_buffer <= 8'd0;
  end else begin

    if (spi_rx_valid) begin
      if (spi_rx_data == 8'hA1) begin
        // 0xA1 means the mcu wants a random byte
        spi_out_buffer <= state[7:0] ^ state[31:24] ^ state[63:56];
        state <= r3_out ^ {state[60:0], state[63:61]};
      end else begin
        // any other byte is treated as a seed and xored straight into the state
        state <= r3_out ^ {state[60:0], state[63:61]} ^ {56'd0, spi_rx_data};
      end
    end else begin
      // no spi activity
      state <= r3_out ^ {state[60:0], state[63:61]};
    end

  end
end

// stage the output byte for the spi core
always @(posedge clk) begin
  if (spi_tx_hold) begin
    spi_tx_data <= spi_out_buffer;
  end
end

endmodule