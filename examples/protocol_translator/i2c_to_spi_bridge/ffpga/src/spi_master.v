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
module spi_master (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] tx_data,

    input wire miso,
    output reg sclk,
    output reg mosi,
    output reg cs,

    output reg busy,
    output reg done,
    output reg [7:0] rx_data,
    output reg rx_done
);

reg [7:0] shift_reg_tx;
reg [7:0] shift_reg_rx;
reg [2:0] bit_count;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        sclk <= 0;
        cs <= 1;
        busy <= 0;
        done <= 0;
        rx_done <= 0;
        bit_count <= 0;
        shift_reg_tx <= 0;
        shift_reg_rx <= 0;
        rx_data <= 0;
        mosi <= 0;
    end
    else begin
        done <= 0;
        rx_done <= 0;
        if(start && !busy) begin
            busy <= 1;
            cs <= 0;
            shift_reg_tx <= tx_data;
            shift_reg_rx <= 8'h00;
            bit_count <= 3'd7;
            sclk <= 0;
            mosi <= tx_data[7];
        end
        else if(busy) begin
            sclk <= ~sclk;
            if(sclk == 1'b0) begin
                shift_reg_rx <= {shift_reg_rx[6:0],miso};
                if(bit_count == 0) begin
                    busy <= 0;
                    done <= 1;
                    rx_done <= 1;
                    rx_data <= {shift_reg_rx[6:0],miso};
                    cs <= 1;
                    sclk <= 0;
                end
                else begin
                    shift_reg_tx <= {shift_reg_tx[6:0],1'b0};
                    bit_count <= bit_count - 1'b1;
                    mosi <= shift_reg_tx[6];
                end
            end
        end
    end
end
endmodule