`timescale 1ns/1ps
//======================================================
// Bridge Controller
//
// Reads bytes from the RX FIFO and forwards them
// to the SPI master.
//
// FIFO -> SPI Transaction
//======================================================
module bridge_controller_sync_fifo(
    input wire clk,
    input wire rst,

    input wire fifo_empty,
    input wire [7:0] fifo_data,
    output reg fifo_rd,

    input wire spi_done,
    output reg spi_start,
    output reg [7:0] spi_data
);

localparam IDLE       = 3'd0;
localparam FIFO_RD    = 3'd1;
localparam FIFO_WAIT1 = 3'd2;
localparam FIFO_WAIT2 = 3'd3;
localparam SPI_START  = 3'd4;
localparam SPI_WAIT   = 3'd5;

reg [2:0] state;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        state <= IDLE;
        fifo_rd <= 1'b0;
        spi_start <= 1'b0;
        spi_data <= 8'h00;
    end
    else begin
        fifo_rd <= 1'b0;
        spi_start <= 1'b0;
        case(state)
        IDLE: begin
            if(!fifo_empty)
                state <= FIFO_RD;
            end
        FIFO_RD: begin
            fifo_rd <= 1'b1;
            state <= FIFO_WAIT1;
        end
        FIFO_WAIT1: begin
            state <= FIFO_WAIT2;
        end
        FIFO_WAIT2:begin
            spi_data <= fifo_data;
            state <= SPI_START;
        end
        SPI_START:begin
            spi_start <= 1'b1;
            state <= SPI_WAIT;
        end
        SPI_WAIT:begin
            if(spi_done)
                state <= IDLE;
            end
        default:
            state <= IDLE;
        endcase
    end
end
endmodule