module spi #(
  parameter CPOL   = 1'b0,  
  parameter CPHA   = 1'b0,  
  parameter WIDTH  = 8,     
  parameter LSB    = 1'b0   
) (
// common ports
  input                  i_clk,          
  input                  i_rst_n,         
// control signal
  input                  i_enable,        
// SPI interface ports
  input                  i_ss_n,        
  input                  i_sck,           
  input                  i_mosi,         
  output                 o_miso,          
  output                 o_miso_oe,       
//RX internal ports
  output reg [WIDTH-1:0] o_rx_data,       
  output reg             o_rx_data_valid, 
//TX internal ports
  input      [WIDTH-1:0] i_tx_data,       
  output                 o_tx_data_hold   
);

// Signal declaration
  reg               [2:0] r_ss_n_sync, r_sck_sync;
  reg [$clog2(WIDTH-1):0] r_transmision_count;
  reg         [WIDTH-1:0] r_miso_data;
  wire                    w_sck_r_edge, w_sck_f_edge, w_sck_edge, w_sck_edge_op;

// SPI input signals synchronization
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_ss_n_sync <= 'b111;
    end else if (i_enable) begin
      r_ss_n_sync <= {r_ss_n_sync[1:0], i_ss_n};
    end else begin
      r_ss_n_sync <= 'b111;
    end
  end

  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_sck_sync <= 'h0;
    end else if (i_enable) begin
      r_sck_sync <= {r_sck_sync[1:0], i_sck};
    end else begin
      r_sck_sync <= 'h0;
    end
  end

  assign w_sck_r_edge  = ~r_sck_sync[2] & r_sck_sync[1];
  assign w_sck_f_edge  = r_sck_sync[2] & ~r_sck_sync[1];
  assign w_sck_edge    = (CPHA^CPOL) ? w_sck_f_edge : w_sck_r_edge;
  assign w_sck_edge_op = (CPHA^CPOL) ? w_sck_r_edge : w_sck_f_edge;

// Create transmission bit counter
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_transmision_count <= 'h0;
    end else if (!i_enable || r_ss_n_sync[1]) begin
      r_transmision_count <= 'h0;
    end else if (w_sck_edge) begin
      if (r_transmision_count == WIDTH-1) begin
        r_transmision_count <= 'h0;
      end else begin
        r_transmision_count <= r_transmision_count + 1;
      end
    end
  end

// Create o_rx_data bus and valid signals
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      o_rx_data <= 'h0;
    end else if (w_sck_edge) begin
      if (LSB) begin
        o_rx_data <= {i_mosi, o_rx_data[WIDTH-1:1]};
      end else begin
        o_rx_data <= {o_rx_data[WIDTH-2:0], i_mosi};
      end
    end
  end

  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      o_rx_data_valid <= 1'b0;
    end else if (r_ss_n_sync[1] || (r_transmision_count == 0 && w_sck_edge)) begin
      o_rx_data_valid <= 1'b0;
    end else if (w_sck_edge && r_transmision_count == WIDTH-1) begin
      o_rx_data_valid <= 1'b1;
    end
  end

  assign o_tx_data_hold = (~CPHA & r_ss_n_sync[2] & ~r_ss_n_sync[1]) | (r_transmision_count == 0 & w_sck_edge_op);

// Create o_miso and OE signals
  always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
      r_miso_data <= 'h0;
    end else if (o_tx_data_hold) begin
      r_miso_data <= i_tx_data;
    end else if (w_sck_edge_op) begin
      if (LSB) begin
        r_miso_data <= r_miso_data >> 1;
      end else begin
        r_miso_data <= r_miso_data << 1;
      end
    end
  end

  assign o_miso    = (LSB) ? r_miso_data[0] : r_miso_data[WIDTH-1];
  assign o_miso_oe = ~r_ss_n_sync[2];

endmodule