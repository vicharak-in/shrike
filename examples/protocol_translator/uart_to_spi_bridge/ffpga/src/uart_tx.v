`timescale 1ns/1ps
//------------------------------------------------------------
// Module Name : uart_tx
//
// Description:
// Transmits 8-bit parallel data as serial UART data.
//
// Features:
// - Configurable Clock Frequency
// - Configurable Baud Rate
// - FSM Based UART Transmitter
//
// UART Frame Format:
// Start Bit + 8 Data Bits + Stop Bit
//
//------------------------------------------------------------

module uart_tx #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] tx_data,
    input  wire       tx_start,

    output reg        tx,
    output reg        tx_done
);

    localparam [15:0] BAUD_DIV = CLK_FREQ / BAUD_RATE;

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] baud_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0]  shift_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1;
            tx_done   <= 1'b0;
            baud_cnt  <= 16'd0;
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
        end
        else begin
            tx_done <= 1'b0;
            case (state)
                IDLE: begin
                    tx <= 1'b1;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        baud_cnt  <= 16'd0;
                        bit_cnt   <= 3'd0;
                        state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;

                    if (baud_cnt == BAUD_DIV-1) begin
                        baud_cnt <= 16'd0;
                        state    <= DATA;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                DATA: begin 
                    tx <= shift_reg[0];

                    if (baud_cnt == BAUD_DIV-1) begin
                        baud_cnt  <= 16'd0;
                        shift_reg <= shift_reg >> 1;

                        if (bit_cnt == 3'd7) begin
                            state <= STOP;
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
                    tx <= 1'b1;
                    if (baud_cnt == BAUD_DIV-1) begin
                        baud_cnt <= 16'd0;
                        tx_done  <= 1'b1;
                        state    <= IDLE;
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