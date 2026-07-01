// spi_target.v
module spi_target #(
    parameter CPOL  = 1'b0, // idle clock polarity: 0 = low, 1 = high
    parameter CPHA  = 1'b0, // clock phase: 0 = sample on leading edge, 1 = sample on trailing edge
    parameter WIDTH = 8,    // data bus width in bits
    parameter LSB   = 1'b0  // bit order: 0 = MSB first, 1 = LSB first
) (
    input                  i_clk,
    input                  i_rst_n,
    input                  i_enable,
    input                  i_ss_n,          // active-low target select
    input                  i_sck,           // SPI clock from controller
    input                  i_mosi,          // controller to target data
    output                 o_miso,          // target to controller data
    output                 o_miso_oe,       // MISO output enable
    output reg [WIDTH-1:0] o_rx_data,       // received data byte
    output reg             o_rx_data_valid, // pulses high when a full byte is received
    input      [WIDTH-1:0] i_tx_data,       // data to transmit
    output                 o_tx_data_hold   // signals controller to present next TX byte
);

    reg               [2:0] r_ss_n_sync;
    reg               [2:0] r_sck_sync;
    reg [$clog2(WIDTH-1):0] r_transmision_count;
    reg         [WIDTH-1:0] r_miso_data;

    wire w_sck_r_edge;
    wire w_sck_f_edge;
    wire w_sck_edge;
    wire w_sck_edge_op;

    // Synchronize SS and SCK into the system clock domain (3-stage)
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

    // Edge detection on synchronized SCK
    assign w_sck_r_edge  = ~r_sck_sync[2] &  r_sck_sync[1];
    assign w_sck_f_edge  =  r_sck_sync[2] & ~r_sck_sync[1];
    assign w_sck_edge    = (CPHA ^ CPOL) ? w_sck_f_edge : w_sck_r_edge;
    assign w_sck_edge_op = (CPHA ^ CPOL) ? w_sck_r_edge : w_sck_f_edge;

    // Bit counter: tracks position within the current byte transfer
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            r_transmision_count <= 'h0;
        end else if (!i_enable || r_ss_n_sync[1]) begin
            r_transmision_count <= 'h0;
        end else if (w_sck_edge) begin
            if (r_transmision_count == WIDTH - 1) begin
                r_transmision_count <= 'h0;
            end else begin
                r_transmision_count <= r_transmision_count + 1;
            end
        end
    end

    // Shift MOSI data into RX register on each sample edge
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

    // Assert rx_valid for one cycle after the last bit of a byte is received
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_rx_data_valid <= 1'b0;
        end else if (r_ss_n_sync[1] || (r_transmision_count == 0 && w_sck_edge)) begin
            o_rx_data_valid <= 1'b0;
        end else if (w_sck_edge && r_transmision_count == WIDTH - 1) begin
            o_rx_data_valid <= 1'b1;
        end
    end

    // TX data hold: signal to latch the next byte from the controller
    assign o_tx_data_hold = (~CPHA & r_ss_n_sync[2] & ~r_ss_n_sync[1]) |
                            (r_transmision_count == 0 & w_sck_edge_op);

    // MISO shift register: load on hold, shift on opposite edge
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

    assign o_miso    = LSB ? r_miso_data[0] : r_miso_data[WIDTH-1];
    assign o_miso_oe = ~r_ss_n_sync[2];

endmodule
