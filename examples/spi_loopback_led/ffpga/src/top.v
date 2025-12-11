module top ( 
	(* iopad_external_pin, clkbuf_inhibit *) input clk, 	// System Clock (50MHz) 
	(* iopad_external_pin *) output clk_en, 
	(* iopad_external_pin *) input rst_n, 			   	// System Reset (Active Low) 
	
	// Physical SPI Pins (Connect these to FPGA I/O) 
	(* iopad_external_pin *) input spi_ss_n, 
	(* iopad_external_pin *) input spi_sck, 
	(* iopad_external_pin *) input spi_mosi, 
	(* iopad_external_pin *) output spi_miso, 
	(* iopad_external_pin *) output spi_miso_en,
	
	// Physical LED Pins 
	(* iopad_external_pin *) output reg led, 
	(* iopad_external_pin *) output led_en 
);

	assign led_en = 1'b1;
	assign clk_en = 1'b1;

    wire [7:0] rx_data_wire;
    wire       rx_valid_pulse;
    reg  [7:0] tx_data_reg;

    // The Echo Logic    
    always @(posedge clk or negedge rst_n) begin
    		if (!rst_n) begin
        		tx_data_reg <= 8'h00;
    		end else if (rx_valid_pulse) begin
        		tx_data_reg <= rx_data_wire;
    		end
	end

    
    // LED Logic
	always @(posedge clk or negedge rst_n) begin
    		if (!rst_n) begin
        		led <= 1'b0;
    		end else if (rx_valid_pulse) begin
        		if (rx_data_wire == 8'hAB)
            		led <= 1'b1;
        		else if (rx_data_wire == 8'hFF)
            		led <= 1'b0;
    		end
	end

	
    // SPI Target
    spi_target #(
        .CPOL(1'b0),   // Standard Mode 0 (Idle Low)
        .CPHA(1'b0),   // Standard Mode 0 (Sample Rising)
        .WIDTH(8),
        .LSB(1'b0)     // MSB First (Standard)
    ) u_spi_target (
        // System Common
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_enable(1'b1),        // Enable the module permanently

        // SPI Physical Interface
        .i_ss_n(spi_ss_n),
        .i_sck(spi_sck),
        .i_mosi(spi_mosi),
        .o_miso(spi_miso),
        .o_miso_oe(spi_miso_en),

        // RX Interface (Data FROM MCU)
        .o_rx_data(rx_data_wire),
        .o_rx_data_valid(rx_valid_pulse),

        // TX Interface (Data TO MCU)
        .i_tx_data(tx_data_reg), 
        .o_tx_data_hold()        // Not needed for simple echo
    );

endmodule