`timescale 1ns/1ps
//======================================================
// SPI Master
//
// Mode 0 SPI Master
//
// Transmits one byte on MOSI and simultaneously
// receives one byte on MISO.
//
// Generates:
//   done    - transmit complete
//   rx_done - receive byte available
//======================================================
module spi_master #(
    parameter CLK_DIV = 25
)(
    input  wire       clk,
    input  wire       rst,

    input  wire       start,
    input  wire [7:0] tx_data,

    input  wire       miso,
    output reg        sclk,
    output reg        mosi,
    output reg        cs,

    output reg        busy,
    output reg        done,
    output reg [7:0]  rx_data,
    output reg        rx_done
);

localparam IDLE   = 2'd0;
localparam SHIFT  = 2'd1;
localparam FINISH = 2'd2;

reg [1:0] state;
reg [7:0] tx_shift;
reg [7:0] rx_shift;
reg [2:0] bit_cnt;
reg [7:0] clk_cnt;

always @(posedge clk or posedge rst) begin
    if(rst)begin
        state    <= IDLE;
        sclk     <= 1'b0;
        cs       <= 1'b1;
        mosi     <= 1'b0;
        busy     <= 1'b0;
        done     <= 1'b0;
        rx_done  <= 1'b0;
        rx_data  <= 8'd0;
        tx_shift <= 8'd0;
        rx_shift <= 8'd0;
        bit_cnt  <= 3'd0;
        clk_cnt  <= 8'd0;
    end
    else begin
        done <= 1'b0;
        rx_done <= 1'b0;
        case(state)
        IDLE: begin
            busy <= 1'b0;
            sclk <= 1'b0;
            cs   <= 1'b1;
            if(start) begin
                busy <= 1'b1;
                cs <= 1'b0;
                tx_shift <= tx_data;
                rx_shift <= 8'd0;
                bit_cnt <= 3'd7;
                clk_cnt <= 8'd0;
                mosi <= tx_data[7];
                state <= SHIFT;
            end
        end
        SHIFT:begin
            if(clk_cnt == CLK_DIV-1) begin
                clk_cnt <= 8'd0;
                sclk <= ~sclk;
                if(sclk == 1'b0) begin
                    rx_shift[bit_cnt] <= miso;
                end
                else begin
                    if(bit_cnt == 0) begin
                        state <= FINISH;
                    end
                    else begin
                        bit_cnt <= bit_cnt - 1'b1;
                        tx_shift <= {tx_shift[6:0],1'b0};
                        mosi <= tx_shift[6];
                    end
                end
            end
            else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end
        FINISH:begin
            busy <= 1'b0;
            cs <= 1'b1;
            sclk <= 1'b0;
            rx_data <= rx_shift;
            done <= 1'b1;
            rx_done <= 1'b1;
            state <= IDLE;
        end
        default:
            state <= IDLE;
        endcase
    end
end
endmodule