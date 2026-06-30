`timescale 1ns/1ps
//------------------------------------------------------------
// Module : spi_slave
//
// Description:
// SPI slave module.
//
// Receives SPI data and provides transmit data
// for the SPI master.
//
// SPI Mode:
// CPOL = 0
// CPHA = 0
// MSB First
//
//------------------------------------------------------------

module spi_slave(
input wire clk,
input wire spi_sck,
input wire spi_cs,
input wire spi_mosi,
input wire [7:0] tx_data,

output wire spi_miso,
output reg [7:0] rx_data = 8'h00,
output reg rx_done = 1'b0,
output reg tx_request = 1'b0	
);

reg sck_ff1 = 0;
reg sck_ff2 = 0;
reg cs_ff1 = 1;
reg cs_ff2 = 1;

reg [7:0] rx_shift = 8'h00;
reg [7:0] tx_shift = 8'h00;
reg [2:0] bit_count = 3'd0;

wire sck_rise;
wire sck_fall;
wire cs_fall;
assign sck_rise = ( sck_ff1 && !sck_ff2 );
assign sck_fall = (!sck_ff1 && sck_ff2 );
assign cs_fall = (!cs_ff1 && cs_ff2 );
assign spi_miso = tx_shift[7];

// SPI slave logic
always @(posedge clk) begin
	rx_done <= 1'b0;
	tx_request <= 1'b0;

	sck_ff1 <= spi_sck;
	sck_ff2 <= sck_ff1;
	cs_ff1 <= spi_cs;
	cs_ff2 <= cs_ff1;

		if (cs_fall) begin
			tx_shift <= tx_data;
			bit_count <= 3'd0;
			tx_request <= 1'b1;
		end
		else if (!spi_cs) begin
			if (sck_rise) begin
        		rx_shift <= {rx_shift[6:0], spi_mosi};
				if (bit_count == 3'd7) begin
					rx_data <= {rx_shift[6:0], spi_mosi};
					rx_done <= 1'b1;
					tx_request <= 1'b1;
					bit_count <= 3'd0;
				end
				else begin
					bit_count <= bit_count + 1'b1;
				end
		    end
			if (sck_fall) begin
				tx_shift <= {tx_shift[6:0], 1'b0};
			end
		end
	end
	
endmodule
