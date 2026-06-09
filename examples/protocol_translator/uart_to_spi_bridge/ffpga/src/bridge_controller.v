`timescale 1ns/1ps
//------------------------------------------------------------
// Module Name : bridge_controller
//
// Description:
// Controls the complete UART to SPI protocol
// conversion process.
//
// Responsibilities:
// - Read data from RX FIFO
// - Start SPI transaction
// - Wait for SPI completion
// - Store SPI response in TX FIFO
//
// Data Flow:
//
// RX FIFO --> SPI Master --> TX FIFO
//
//------------------------------------------------------------

module bridge_controller
(
    input  wire       clk,
    input  wire       rst,

    //--------------------------------------------------
    // RX FIFO Interface
    //--------------------------------------------------
    input  wire       rx_fifo_empty,
    output reg        rx_fifo_rd,
    input  wire [7:0] rx_fifo_data,

    //--------------------------------------------------
    // SPI Interface
    //--------------------------------------------------
    output reg        spi_start,
    output reg [7:0]  spi_tx_data,

    input  wire       spi_done,
    input  wire [7:0] spi_rx_data,

    //--------------------------------------------------
    // TX FIFO Interface
    //--------------------------------------------------
    input  wire       tx_fifo_full,
    output reg        tx_fifo_wr,
    output reg [7:0]  tx_fifo_data
);

    //--------------------------------------------------
    // Bridge Controller States
    //
    // IDLE         : Wait for RX FIFO data
    // ASSERT_RD    : Assert FIFO read
    // CAPTURE_DATA : Capture FIFO output
    // START_SPI    : Start SPI transaction
    // WAIT_SPI     : Wait for SPI completion
    // WRITE_TX     : Store SPI response
    //--------------------------------------------------
    localparam IDLE         = 3'd0;
    localparam ASSERT_RD    = 3'd1;
    localparam CAPTURE_DATA = 3'd2;
    localparam START_SPI    = 3'd3;
    localparam WAIT_SPI     = 3'd4;
    localparam WRITE_TX     = 3'd5;

    reg [2:0] state;

    // Stores the UART byte during SPI transaction
    reg [7:0] current_byte;

    always @(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            state <= IDLE;

            rx_fifo_rd <= 0;
            spi_start  <= 0;
            tx_fifo_wr <= 0;

            spi_tx_data <= 8'd0;
            tx_fifo_data <= 8'd0;
            current_byte <= 8'd0;
        end
        else
        begin

            // Default outputs
            rx_fifo_rd <= 0;
            spi_start  <= 0;
            tx_fifo_wr <= 0;

            case(state)

            //----------------------------------
            // WAIT FOR UART DATA
            //----------------------------------
            IDLE:
            begin
                if(!rx_fifo_empty)
                begin
                    rx_fifo_rd <= 1'b1;
                    state <= ASSERT_RD;
                end
            end

            //----------------------------------
            // WAIT ONE CLOCK FOR FIFO OUTPUT
            //----------------------------------
            ASSERT_RD:
            begin
                state <= CAPTURE_DATA;
            end

            //----------------------------------
            // STORE FIFO DATA
            //----------------------------------
            CAPTURE_DATA:
            begin
                current_byte <= rx_fifo_data;
                state <= START_SPI;
            end

            //----------------------------------
            // START SPI TRANSACTION
            //----------------------------------
            START_SPI:
            begin
                spi_tx_data <= current_byte;
                spi_start   <= 1'b1;
                state <= WAIT_SPI;
            end

            //----------------------------------
            // WAIT FOR SPI TO COMPLETE
            //----------------------------------
            WAIT_SPI:
            begin
                if(spi_done)
                    state <= WRITE_TX;
            end

            //----------------------------------
            // STORE SPI RESPONSE
            //----------------------------------
            WRITE_TX:
            begin
                if(!tx_fifo_full)
                begin
                    tx_fifo_data <= spi_rx_data;
                    tx_fifo_wr   <= 1'b1;
                    state <= IDLE;
                end
            end

            //----------------------------------
            // DEFAULT
            //----------------------------------
            default:
                state <= IDLE;

            endcase
        end
    end

endmodule