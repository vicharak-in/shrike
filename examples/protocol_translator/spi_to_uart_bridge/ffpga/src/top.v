`timescale 1ns/1ps
//------------------------------------------------------------
// Module : top
//
// Description:
// Top level module for the SPI to UART and UART to SPI
// protocol bridge.
//
// Data Paths:
// - SPI -> FIFO -> UART
// - UART -> FIFO -> SPI
//
//------------------------------------------------------------

(* top *) module top #(
    parameter CLK = 50000000,
    parameter BAUD_RATE = 115200
)(
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) input spi_sck,
    (* iopad_external_pin *) input spi_cs,
    (* iopad_external_pin *) input spi_mosi,
    (* iopad_external_pin *) output spi_miso,
    (* iopad_external_pin *) output spi_miso_en,

    (* iopad_external_pin *) input uart_rx,
    (* iopad_external_pin *) output uart_tx,
    (* iopad_external_pin *) output uart_tx_en,

    (* iopad_external_pin *)output wire fpga_ready, 
    (* iopad_external_pin *) output fpga_ready_en,

    (* iopad_external_pin *) output clk_en
);

    assign clk_en = 1'b1;
    assign spi_miso_en = 1'b1;
    assign fpga_ready_en = 1'b1;
    assign uart_tx_en = 1'b1;
    assign fpga_ready = (fifo_count < 6);

// SPI Signals
    wire [7:0] spi_rx_data;
    wire spi_rx_done;

// UART Signals
    reg [7:0] uart_tx_data = 8'h00;
    reg uart_tx_start = 1'b0;
    wire uart_tx_busy;
    wire [7:0] uart_rx_data;
    wire uart_rx_valid;

//FIFO Signals
    wire fifo_full;
    wire fifo_empty;
    wire [3:0] fifo_count;
    wire [7:0] fifo_data_out;
    reg fifo_wr_en = 1'b0;
    reg fifo_rd_en = 1'b0;
    wire spi_fifo_full;
    wire spi_fifo_empty;
    wire [3:0] spi_fifo_count;
    wire [7:0] spi_fifo_data_out;
    reg spi_fifo_wr_en = 1'b0;
    reg spi_fifo_rd_en = 1'b0;
    wire tx_request;
    
    reg [7:0] spi_tx_reg = 8'hFF;
    reg [1:0] uart_state = UART_IDLE;
    reg [1:0] tx_state = TX_IDLE;

    localparam TX_IDLE = 2'd0;
    localparam TX_READ_FIFO = 2'd1;
    localparam TX_WAIT_FIFO = 2'd2;
    localparam TX_READY = 2'd3;
    localparam UART_IDLE = 2'd0;
    localparam UART_READ_FIFO = 2'd1;
    localparam UART_WAIT_FIFO = 2'd2;
    localparam UART_SEND = 2'd3;

    spi_slave spi_inst (
        .clk(clk),
        .spi_sck(spi_sck),
        .spi_cs(spi_cs),
        .spi_mosi(spi_mosi),
        .tx_data(spi_tx_reg),
        .spi_miso(spi_miso),
        .tx_request(tx_request),
        .rx_data(spi_rx_data),
        .rx_done(spi_rx_done)
    );

    uart_tx #(
        .CLK_FREQ(CLK),
        .BAUD_RATE(BAUD_RATE)
    ) uart_tx_inst (
        .clk(clk),
        .rst(1'b0),
        .start(uart_tx_start),
        .data_in(uart_tx_data),
        .tx(uart_tx),
        .busy(uart_tx_busy)
    );

    uart_rx #(
        .CLK_FREQ(CLK),
        .BAUD_RATE(BAUD_RATE)
    ) uart_rx_inst (
        .clk(clk),
        .rst(1'b0),
        .rx(uart_rx),
        .data_out(uart_rx_data),
        .data_valid(uart_rx_valid)
    );

    fifo_8x8 uart_rx_fifo (
        .clk(clk),
        .rst(1'b0),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .data_in(uart_rx_data),
        .data_out(fifo_data_out),
        .full(fifo_full),
        .empty(fifo_empty),
        .count(fifo_count)
    );

    fifo_8x8 spi_rx_fifo (
        .clk(clk),
        .rst(1'b0),
        .wr_en(spi_fifo_wr_en),
        .rd_en(spi_fifo_rd_en),
        .data_in(spi_rx_data),
        .data_out(spi_fifo_data_out),
        .full(spi_fifo_full),
        .empty(spi_fifo_empty),
        .count(spi_fifo_count)
    );

// Bridge Logic

always @(posedge clk) begin
    uart_tx_start <= 1'b0;
    fifo_wr_en <= 1'b0;
    fifo_rd_en <= 1'b0;
    spi_fifo_wr_en <= 1'b0;
    spi_fifo_rd_en <= 1'b0;
    
    if (spi_rx_done && !uart_tx_busy) begin
        uart_tx_data <= spi_rx_data;
        uart_tx_start <= 1'b1;
    end 
    if (spi_rx_done && !spi_fifo_full) begin
        spi_fifo_wr_en <= 1'b1;
    end
    if (uart_rx_valid && !fifo_full) begin
        fifo_wr_en <= 1'b1;
    end

    case(tx_state)
        TX_IDLE: begin
            if (!fifo_empty) begin
                fifo_rd_en <= 1'b1;
                tx_state <= TX_READ_FIFO;
            end
        end

        TX_READ_FIFO: begin
            tx_state <= TX_WAIT_FIFO;
        end

        TX_WAIT_FIFO: begin
            spi_tx_reg <= fifo_data_out;
            tx_state <= TX_READY;
        end

        TX_READY: begin
            if (tx_request) begin
                if (!fifo_empty) begin
                    fifo_rd_en <= 1'b1;
                    tx_state <= TX_READ_FIFO;
                end
                else begin
                    tx_state <= TX_IDLE;
                end
            end
        end
    endcase

    case(uart_state)
        UART_IDLE: begin
            if (!spi_fifo_empty) begin
                spi_fifo_rd_en <= 1'b1;
                uart_state <= UART_READ_FIFO;
            end
        end
            
        UART_READ_FIFO: begin
            uart_state <= UART_WAIT_FIFO;
        end

        UART_WAIT_FIFO: begin
            uart_tx_data <= spi_fifo_data_out;
            uart_state <= UART_SEND;
        end

        UART_SEND: begin
            if (!uart_tx_busy) begin
                uart_tx_start <= 1'b1;
                uart_state <= UART_IDLE;
            end
        end

    endcase
end
endmodule




