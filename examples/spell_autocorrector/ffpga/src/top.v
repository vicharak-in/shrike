(* top *) module top ( 
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
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//











//  (* top *) module top ( 
// 	(* iopad_external_pin, clkbuf_inhibit *) input clk, 	// System Clock (50MHz) 
// 	(* iopad_external_pin *) output clk_en, 
// 	(* iopad_external_pin *) input rst_n, 			   	// System Reset (Active Low) 
// 	
// 	// Physical SPI Pins
// 	(* iopad_external_pin *) input spi_ss_n, 
// 	(* iopad_external_pin *) input spi_sck, 
// 	(* iopad_external_pin *) input spi_mosi, 
// 	(* iopad_external_pin *) output spi_miso, 
// 	(* iopad_external_pin *) output spi_miso_en,
// 	
// 	// Physical LED Pins 
// 	(* iopad_external_pin *) output reg led, 
// 	(* iopad_external_pin *) output led_en 
// );
//
// 	assign led_en = 1'b1;
// 	assign clk_en = 1'b1;
//
//     wire [7:0] rx_data_wire;
//     wire       rx_valid_pulse;
//     reg  [7:0] tx_data_reg;
//
//     // Control Characters
//     localparam FLAG = 8'h7E;
//     localparam ESC  = 8'h7D;
//     localparam MASK = 8'h20;
//
//     //---------------------------------------------------------
//     // 1. DESTUFFING LOGIC (From RP2040 to FPGA)
//     //---------------------------------------------------------
//     reg rx_escaped;
//     reg [7:0] clean_rx_data;
//     reg clean_rx_valid;
//
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             rx_escaped     <= 1'b0;
//             clean_rx_data  <= 8'h00;
//             clean_rx_valid <= 1'b0;
//         end else begin
//             clean_rx_valid <= 1'b0;
//             if (rx_valid_pulse) begin
//                 if (rx_data_wire == FLAG) begin
//                     rx_escaped <= 1'b0; // Reset escaping on Frame boundaries
//                 end else if (rx_data_wire == ESC) begin
//                     rx_escaped <= 1'b1;
//                 end else begin
//                     if (rx_escaped) begin
//                         clean_rx_data  <= rx_data_wire ^ MASK;
//                         rx_escaped     <= 1'b0;
//                         clean_rx_valid <= 1'b1;
//                     end else begin
//                         clean_rx_data  <= rx_data_wire;
//                         clean_rx_valid <= 1'b1;
//                     end
//                 end
//             end
//         end
//     end
//
//     //---------------------------------------------------------
//     // 2. STUFFING LOGIC (Loopback Loop from FPGA to RP2040)
//     //---------------------------------------------------------
//     reg [7:0] next_stuffed_byte;
//     reg       has_delayed_stuffed_byte;
//     reg [7:0] delayed_stuffed_byte;
//
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             tx_data_reg              <= 8'h00;
//             delayed_stuffed_byte     <= 8'h00;
//             has_delayed_stuffed_byte <= 1'b0;
//         end else if (rx_valid_pulse) begin
//             // If we have a residual stuffed byte waiting from a previous escaping operation
//             if (has_delayed_stuffed_byte) begin
//                 tx_data_reg              <= delayed_stuffed_byte;
//                 has_delayed_stuffed_byte <= 1'b0;
//             end 
//             // Frame transparent pass-through for Flag and Escape commands themselves
//             else if (rx_data_wire == FLAG || rx_data_wire == ESC) begin
//                 tx_data_reg <= rx_data_wire;
//             end 
//             // Process the loopback payload character
//             else if (clean_rx_valid) begin
//                 if (clean_rx_data == FLAG || clean_rx_data == ESC) begin
//                     tx_data_reg              <= ESC; 
//                     delayed_stuffed_byte     <= clean_rx_data ^ MASK;
//                     has_delayed_stuffed_byte <= 1'b1;
//                 end else begin
//                     tx_data_reg <= clean_rx_data;
//                 end
//             end else begin
//                 tx_data_reg <= rx_data_wire; // Default fallback to preserve stream sync
//             end
//         end
//     end
//
//     //---------------------------------------------------------
//     // LED Indicator Logic
//     //---------------------------------------------------------
// 	always @(posedge clk or negedge rst_n) begin
//     		if (!rst_n) begin
//         		led <= 1'b0;
//     		end else if (clean_rx_valid) begin
//         		if (clean_rx_data == 8'hAB)
//             		led <= 1'b1;
//         		else if (clean_rx_data == 8'hFF)
//             		led <= 1'b0;
//     		end
// 	end
//
//     // SPI Target Component
//     spi_target #(
//         .CPOL(1'b0),
//         .CPHA(1'b0),
//         .WIDTH(8),
//         .LSB(1'b0)
//     ) u_spi_target (
//         .i_clk(clk),
//         .i_rst_n(rst_n),
//         .i_enable(1'b1),
//         .i_ss_n(spi_ss_n),
//         .i_sck(spi_sck),
//         .i_mosi(spi_mosi),
//         .o_miso(spi_miso),
//         .o_miso_oe(spi_miso_en),
//         .o_rx_data(rx_data_wire),
//         .o_rx_data_valid(rx_valid_pulse),
//         .i_tx_data(tx_data_reg), 
//         .o_tx_data_hold()
//     );
//
// endmodule



































