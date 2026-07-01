`timescale 1ns/1ps
//------------------------------------------------------------
// Module : uart_tx
//
// Description:
// UART transmitter module.
//
// Converts 8-bit parallel data into serial UART data.
//
// UART Frame:
// Start Bit + 8 Data Bits + Stop Bit
//
//------------------------------------------------------------

// UART transmitter state machine
module uart_tx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] data_in,

    output reg tx,
    output reg busy
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

reg [15:0] clk_count;
reg [3:0] bit_index;
reg [7:0] tx_shift;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        tx <= 1'b1;
        busy <= 1'b0;
        clk_count <= 16'd0;
        bit_index <= 4'd0;
        tx_shift <= 8'h00;
    end
    else begin
        if (start && !busy) begin
            busy <= 1'b1;
            tx_shift <= data_in;
            bit_index <= 4'd0;
            clk_count <= 16'd0;
            tx <= 1'b0;
        end

        else if (busy) begin
            if (clk_count == CLKS_PER_BIT - 1) begin
                clk_count <= 16'd0;
                if (bit_index < 8) begin
                    tx <= tx_shift[bit_index];
                    bit_index <= bit_index + 1'b1;
                end
                else if (bit_index == 8) begin
                    tx <= 1'b1;
                    bit_index <= bit_index + 1'b1;
                end
                else begin
                    busy <= 1'b0;
                    tx <= 1'b1;
                end
            end
            else begin
                clk_count <= clk_count + 1'b1;
            end
        end
    end
end

endmodule