`timescale 1ns/1ps
//======================================================
// Top Module
//
// Bidirectional I2C to SPI Protocol Bridge
//
// I2C Write  -> RX FIFO -> SPI Master
// SPI MISO   -> TX FIFO -> I2C Read
//======================================================
(* top *) module top #(
    parameter I2C_SLAVE_ADR = 7'h32
) (
    (* iopad_external_pin, clkbuf_inhibit *) input i_clk,
    (* iopad_external_pin *) input i_scl,
    (* iopad_external_pin *) input i_sda,
    (* iopad_external_pin *) output o_sda,
    (* iopad_external_pin *) output o_sda_oe,

    (* iopad_external_pin *) output o_led,
    (* iopad_external_pin *) output o_led_en,

    (* iopad_external_pin *) output o_clk_en,
    (* iopad_external_pin *) output o_spi_sclk,
    (* iopad_external_pin *) output o_spi_sclk_oe,
    (* iopad_external_pin *) output o_spi_ss,
    (* iopad_external_pin *) output o_spi_ss_oe,
    (* iopad_external_pin *) output o_spi_mosi,
    (* iopad_external_pin *) output o_spi_mosi_oe,
    (* iopad_external_pin *) input i_spi_miso
);

    assign o_clk_en = 1'b1;
    assign o_led_en = 1'b1;

    assign o_spi_sclk_oe = 1'b1;
    assign o_spi_ss_oe   = 1'b1;
    assign o_spi_mosi_oe = 1'b1;

    wire w_busy;
    wire w_int_tx;
    wire w_int_rx;
    wire w_read_req;

    wire [7:0] w_data_rx;
    reg [7:0] r_data_tx;
    reg fifo_wr;
    wire [7:0] spi_rx_data;
    wire spi_rx_done;
    reg response_valid;
    wire [7:0] i2c_response;
    assign i2c_response = response_valid ? r_data_tx : 8'hFF;
    wire fifo_rd;
    reg tx_fifo_read_pending;
    wire [7:0] fifo_out;
    wire fifo_full;
    wire fifo_empty;
    wire [3:0] fifo_count;

    wire spi_start;
    wire [7:0] spi_data;
    wire spi_done;
    wire spi_busy;
    wire spi_sclk;
    wire spi_mosi;
    wire spi_cs;

    reg [15:0] reset_cnt = 16'd0;
    wire rst;
    assign rst = (reset_cnt != 16'hFFFF);
    always @(posedge i_clk)
    begin
        if(reset_cnt != 16'hFFFF)
            reset_cnt <= reset_cnt + 1'b1;
    end

i2c_slave #(
    .I2C_SLAVE_ADR(I2C_SLAVE_ADR)
) u_i2c_slave (
    .i_clk(i_clk),
    .i_rst(rst),
    .i_en(1'b1),
    .o_busy(w_busy),

    .i_scl(i_scl),
    .i_sda(i_sda),
    .o_sda(o_sda),
    .o_sda_oe(o_sda_oe),

   	.i_data_tx(i2c_response),
    .o_data_rx(w_data_rx),
    .o_int_tx(w_int_tx),
    .o_int_rx(w_int_rx),
    .o_read_req(w_read_req)
);
fifo_8x8 RX_FIFO(
    .clk(i_clk),
    .rst(rst),
    .wr_en(fifo_wr),
    .rd_en(fifo_rd),
    .data_in(w_data_rx),
    .data_out(fifo_out),
    .full(fifo_full),
    .empty(fifo_empty),
    .count(fifo_count)
);

    wire tx_fifo_full;
    wire tx_fifo_empty;
    wire [7:0] tx_fifo_out;
    wire [3:0] tx_fifo_count;
    reg tx_fifo_wr;
    reg tx_fifo_rd;

fifo_8x8 TX_FIFO(
    .clk(i_clk),
    .rst(rst),
    .wr_en(tx_fifo_wr),
    .rd_en(tx_fifo_rd),
    .data_in(spi_rx_data),
    .data_out(tx_fifo_out),
    .full(tx_fifo_full),
    .empty(tx_fifo_empty),
    .count(tx_fifo_count)
);

    always @(posedge i_clk) begin
        fifo_wr <= 1'b0;
        if(w_int_rx && !fifo_full)
            fifo_wr <= 1'b1;
    end
    always @(posedge i_clk) begin
        if(rst) begin
            response_valid <= 1'b0;
            r_data_tx <= 8'h00;
        end
        else if(w_int_rx) begin
            response_valid <= 1'b0;
        end
        else if(spi_rx_done) begin
            r_data_tx <= spi_rx_data;
            response_valid <= 1'b1;
        end
    end

    bridge_controller_sync_fifo BRIDGE(
        .clk(i_clk),
        .rst(rst),
        .fifo_empty(fifo_empty),
        .fifo_data(fifo_out),
        .fifo_rd(fifo_rd),
        .spi_done(spi_done),
        .spi_start(spi_start),
        .spi_data(spi_data)
    );

    spi_master #( .CLK_DIV(SPI_CLK_DIV))
    SPI(
        .clk(i_clk),
        .rst(rst),
        .start(spi_start),
        .tx_data(spi_data),
        .miso(i_spi_miso),
        .sclk(spi_sclk),
        .mosi(spi_mosi),
        .cs(spi_cs),
        .busy(spi_busy),
        .done(spi_done),
        .rx_data(spi_rx_data),
        .rx_done(spi_rx_done)
    );

    always @(posedge i_clk) begin
        tx_fifo_wr <= 1'b0;
            if(spi_rx_done && !tx_fifo_full)
            tx_fifo_wr <= 1'b1;
        end

        assign o_spi_sclk = spi_sclk;
        assign o_spi_ss   = spi_cs;
        assign o_spi_mosi = spi_mosi;
        assign o_led = w_int_rx;

endmodule