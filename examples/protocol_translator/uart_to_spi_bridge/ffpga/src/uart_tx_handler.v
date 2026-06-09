`timescale 1ns/1ps
//------------------------------------------------------------
// Module Name : uart_tx_handler
//
// Description:
// Controls UART transmission by reading data from
// the TX FIFO and starting the UART transmitter.
//
// Responsibilities:
// - Monitor TX FIFO
// - Read available data
// - Start UART transmission
// - Wait for transmission completion
//
// Data Flow:
//
// TX FIFO --> UART Transmitter
//
//------------------------------------------------------------

module uart_tx_handler
(
    input  wire       clk,
    input  wire       rst,

    //--------------------------------------------------
    // TX FIFO Interface
    //--------------------------------------------------
    input  wire       tx_fifo_empty,
    output reg        tx_fifo_rd,
    input  wire [7:0] tx_fifo_data,

    //--------------------------------------------------
    // UART Transmitter Interface
    //--------------------------------------------------
    output reg [7:0]  uart_tx_data,
    output reg        uart_tx_start,

    input  wire       uart_tx_done
);

    //--------------------------------------------------
    // UART TX Handler States
    //
    // IDLE         : Wait for TX FIFO data
    // ASSERT_RD    : Assert FIFO read
    // CAPTURE_DATA : Capture FIFO output
    // START_TX     : Start UART transmission
    // WAIT_TX      : Wait for transmission complete
    //--------------------------------------------------
    localparam IDLE         = 3'd0;
    localparam ASSERT_RD    = 3'd1;
    localparam CAPTURE_DATA = 3'd2;
    localparam START_TX     = 3'd3;
    localparam WAIT_TX      = 3'd4;

    reg [2:0] state;

    always @(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            state <= IDLE;

            tx_fifo_rd    <= 0;
            uart_tx_start <= 0;
            uart_tx_data  <= 8'd0;
        end
        else
        begin

            // Default outputs
            tx_fifo_rd    <= 0;
            uart_tx_start <= 0;

            case(state)

            //----------------------------------
            // WAIT FOR DATA IN TX FIFO
            //----------------------------------
            IDLE:
            begin
                if(!tx_fifo_empty)
                begin
                    tx_fifo_rd <= 1'b1;
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
                uart_tx_data <= tx_fifo_data;
                state <= START_TX;
            end

            //----------------------------------
            // START UART TRANSMISSION
            //----------------------------------
            START_TX:
            begin
                uart_tx_start <= 1'b1;
                state <= WAIT_TX;
            end

            //----------------------------------
            // WAIT FOR UART TO COMPLETE
            //----------------------------------
            WAIT_TX:
            begin
                if(uart_tx_done)
                    state <= IDLE;
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