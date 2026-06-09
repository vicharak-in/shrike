`timescale 1ns/1ps

//------------------------------------------------------------
// Module Name : top
//
// Description:
// Top level module for the UART to SPI Bridge.
//
// Data Flow:
//
// UART RX
//     ↓
// RX FIFO
//     ↓
// Bridge Controller
//     ↓
// SPI Master
//     ↓
// TX FIFO
//     ↓
// UART TX Handler
//     ↓
// UART TX
//
//------------------------------------------------------------

(* top *)
module top #(

    parameter CLK       = 50000000,
    parameter BAUD_RATE = 115200

)(

    //--------------------------------------------------
    // UART Interface
    //--------------------------------------------------
    (* iopad_external_pin *) input  rx,
    (* iopad_external_pin *) output tx,

    //--------------------------------------------------
    // Reset Input
    //--------------------------------------------------
    (* iopad_external_pin *) input rst,

    //--------------------------------------------------
    // System Clock
    //--------------------------------------------------
    (* iopad_external_pin *) output clk_en,

    (* iopad_external_pin, clkbuf_inhibit *)
    input clk,

    //--------------------------------------------------
    // SPI Interface
    //--------------------------------------------------
    (* iopad_external_pin *) output mosi,
    (* iopad_external_pin *) input  miso,
    (* iopad_external_pin *) output sclk,
    (* iopad_external_pin *) output cs,

    //--------------------------------------------------
    // FPGA Output Enables
    //--------------------------------------------------
    (* iopad_external_pin *) output mosi_en,
    (* iopad_external_pin *) output sclk_en,
    (* iopad_external_pin *) output cs_en,
    (* iopad_external_pin *) output tx_en

);

    //==================================================
    // OUTPUT ENABLES
    //==================================================

    assign clk_en  = 1'b1;

    assign mosi_en = 1'b1;
    assign sclk_en = 1'b1;
    assign cs_en   = 1'b1;
    assign tx_en   = 1'b1;

    //==================================================
    // INTERNAL SIGNALS
    //==================================================

    //---------------- UART RX ----------------

    wire [7:0] uart_rx_data;
    wire       uart_rx_done;

    //---------------- UART TX ----------------

    wire [7:0] uart_tx_data;
    wire       uart_tx_start;
    wire       uart_tx_done;

    //---------------- RX FIFO ----------------

    wire       rx_fifo_wr;
    wire       rx_fifo_rd;

    wire [7:0] rx_fifo_data_out;

    wire       rx_fifo_full;
    wire       rx_fifo_empty;

    wire [3:0] rx_fifo_count;

    //---------------- TX FIFO ----------------

    wire       tx_fifo_wr;
    wire       tx_fifo_rd;

    wire [7:0] tx_fifo_data_in;
    wire [7:0] tx_fifo_data_out;

    wire       tx_fifo_full;
    wire       tx_fifo_empty;

    wire [3:0] tx_fifo_count;

    //---------------- SPI ----------------

    wire       spi_start;
    wire       spi_done;

    wire [7:0] spi_tx_data;
    wire [7:0] spi_rx_data;

    wire       cs_n_internal;
    wire rst_int = 1'b0;

    //==================================================
    // UART RECEIVER
    //==================================================

    uart_rx #(
        .CLK_FREQ(CLK),
        .BAUD_RATE(BAUD_RATE)
    )
    uart_rx_inst
    (
        .clk(clk),
        .rst(rst),

        .rx(rx),

        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done)
    );

    //==================================================
    // RX FIFO WRITE LOGIC
    //
    // Store received UART data into RX FIFO
    //==================================================

    assign rx_fifo_wr =
            uart_rx_done &&
           !rx_fifo_full;

    //==================================================
    // RX FIFO
    //==================================================

    fifo_8x8 rx_fifo
    (
        .clk(clk),
        .rst(rst),

        .wr_en(rx_fifo_wr),
        .rd_en(rx_fifo_rd),

        .data_in(uart_rx_data),
        .data_out(rx_fifo_data_out),

        .full(rx_fifo_full),
        .empty(rx_fifo_empty),

        .count(rx_fifo_count)
    );

    //==================================================
    // BRIDGE CONTROLLER
    //
    // Controls:
    // RX FIFO -> SPI -> TX FIFO
    //==================================================

    bridge_controller bridge_inst
    (
        .clk(clk),
        .rst(rst),

        .rx_fifo_empty(rx_fifo_empty),
        .rx_fifo_rd(rx_fifo_rd),
        .rx_fifo_data(rx_fifo_data_out),

        .spi_start(spi_start),
        .spi_tx_data(spi_tx_data),

        .spi_done(spi_done),
        .spi_rx_data(spi_rx_data),

        .tx_fifo_full(tx_fifo_full),
        .tx_fifo_wr(tx_fifo_wr),
        .tx_fifo_data(tx_fifo_data_in)
    );

    //==================================================
    // SPI MASTER
    //==================================================

    spi_master #(
        .CLK_DIV(25)
    )
    spi_master_inst
    (
        .clk(clk),
        .rst(rst),

        .start(spi_start),
        .tx_data(spi_tx_data),

        .rx_data(spi_rx_data),
        .done(spi_done),

        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n_internal),

        .miso(miso)
    );

    // Connect internal chip select to output pin
    assign cs = cs_n_internal;

    //==================================================
    // TX FIFO
    //==================================================

    fifo_8x8 tx_fifo
    (
        .clk(clk),
        .rst(rst),

        .wr_en(tx_fifo_wr),
        .rd_en(tx_fifo_rd),

        .data_in(tx_fifo_data_in),
        .data_out(tx_fifo_data_out),

        .full(tx_fifo_full),
        .empty(tx_fifo_empty),

        .count(tx_fifo_count)
    );

    //==================================================
    // UART TX HANDLER
    //
    // Controls:
    // TX FIFO -> UART TX
    //==================================================

    uart_tx_handler uart_tx_handler_inst
    (
        .clk(clk),
        .rst(rst),

        .tx_fifo_empty(tx_fifo_empty),
        .tx_fifo_rd(tx_fifo_rd),
        .tx_fifo_data(tx_fifo_data_out),

        .uart_tx_data(uart_tx_data),
        .uart_tx_start(uart_tx_start),

        .uart_tx_done(uart_tx_done)
    );

    //==================================================
    // UART TRANSMITTER
    //==================================================

    uart_tx #(
        .CLK_FREQ(CLK),
        .BAUD_RATE(BAUD_RATE)
    )
    uart_tx_inst
    (
        .clk(clk),
        .rst(rst),

        .tx_data(uart_tx_data),
        .tx_start(uart_tx_start),

        .tx(tx),
        .tx_done(uart_tx_done)
    );

endmodule