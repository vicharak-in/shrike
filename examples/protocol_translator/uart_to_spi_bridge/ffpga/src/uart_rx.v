`timescale 1ns/1ps
//------------------------------------------------------------
// Module Name : uart_rx
//
// Description:
// Receives serial UART data and converts it into
// 8-bit parallel data.
//
// Features:
// - Configurable Clock Frequency
// - Configurable Baud Rate
// - Double Flip-Flop Input Synchronizr
// - FSM Based UART Receiver
//
// UART Frame Format:
// Start Bit + 8 Data Bits + Stop Bit
//
//------------------------------------------------------------

module uart_rx #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUD_RATE = 115200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,

    output reg [7:0]  rx_data,
    output reg        rx_done
);

    
    localparam [15:0] BAUD_DIV  = CLK_FREQ / BAUD_RATE;
    localparam [15:0] HALF_BAUD = BAUD_DIV / 2;

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state;
    reg [15:0] baud_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0] shift_reg;

    reg rx_sync1;
    reg rx_sync2;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end
        else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // UART Receiver FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            baud_cnt  <= 16'd0;
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_done   <= 1'b0;
        end
        else begin
            rx_done <= 1'b0;

            case(state)
                IDLE: begin
                    baud_cnt <= 16'd0;
                    bit_cnt  <= 3'd0;

                    if(rx_sync2 == 1'b0)  begin
                        state <= START;
                    end
                end

                START: begin
                    if(baud_cnt == HALF_BAUD-1) begin
                        baud_cnt <= 16'd0;

                        if(rx_sync2 == 1'b0)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                DATA: begin
                    if(baud_cnt == BAUD_DIV-1) begin
                        baud_cnt <= 16'd0;
                        // Sample incoming UART bit
                        shift_reg[bit_cnt] <= rx_sync2;

                        if(bit_cnt == 3'd7) begin
                            bit_cnt <= 3'd0;
                            state   <= STOP;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if(baud_cnt == BAUD_DIV-1) begin
                        baud_cnt <= 16'd0;
                        if(rx_sync2 == 1'b1) begin 
                            rx_data <= shift_reg;
                            rx_done <= 1'b1;
                        end
                        state <= IDLE;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule