`timescale 1ns/1ps
///------------------------------------------------------------
// Module : uart_rx
//
// Description:
// UART receiver module.
//
// Receives serial UART data and converts it into
// 8-bit parallel data.
//
// UART Frame:
// Start Bit + 8 Data Bits + Stop Bit
//
//------------------------------------------------------------

module uart_rx #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,

    output reg [7:0] data_out = 8'h00,
    output reg data_valid = 1'b0
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state = IDLE;
    reg [15:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] rx_shift = 0;

// UART receiver state machine
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state      <= IDLE;
        clk_count  <= 0;
        bit_index  <= 0;
        rx_shift   <= 0;
        data_out   <= 0;
        data_valid <= 0;
    end
    else begin
        data_valid <= 1'b0;
        case (state)
            IDLE: begin
                if (rx == 1'b0) begin
                    state <= START;
                    clk_count <= (CLKS_PER_BIT/2);
                end
            end
            START: begin
                if (clk_count > 0) begin
                    clk_count <= clk_count - 1;
                end
                else begin
                    if (rx == 1'b0) begin
                        state <= DATA;
                        bit_index <= 0;
                        clk_count <= CLKS_PER_BIT - 1;
                    end
                    else begin
                        state <= IDLE;
                    end
                end
            end
            DATA: begin
                if (clk_count > 0) begin
                    clk_count <= clk_count - 1;
                end
                else begin
                    rx_shift[bit_index] <= rx;
                    clk_count <= CLKS_PER_BIT - 1;
                    if (bit_index == 3'd7) begin
                        state <= STOP;
                    end
                    else begin
                        bit_index <= bit_index + 1'b1;
                    end
                end
            end
            STOP: begin
                if (clk_count > 0) begin
                    clk_count <= clk_count - 1;
                end
                else begin
                    if (rx == 1'b1) begin
                        data_out <= rx_shift;
                        data_valid <= 1'b1;
                    end
                    state <= IDLE;
                end
            end
        endcase
    end
end
endmodule