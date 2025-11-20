/* i2c based led controller module to demostrate how to use i2c with shrike fpga this usage the i2c slave provided by the go configure software itself however any othe i2c slave imp will work  */

// # Engineer - Deepak Sharda deepak.sharda@vicharak.in dshardan007@gmail.com


`timescale 1ns / 1ps

(* top *) module  i2c_blink #( parameter I2C_SLAVE_ADR = 7'h32
		  ) ( 
		(* iopad_external_pin, clkbuf_inhibit *) input i_clk,
		(* iopad_external_pin *) input i_rst,
		(* iopad_external_pin *) input i_scl,
		(* iopad_external_pin *) input i_sda,
		(* iopad_external_pin *) output o_sda,
		(* iopad_external_pin *) output o_led,
		  
		  // ouput enable signal 
		(* iopad_external_pin *) output o_sda_oe,
		(* iopad_external_pin *) output o_clk_en,
		(* iopad_external_pin *) output o_led_en );
		  
	assign o_clk_en = 1'b1;
	assign o_led_en = 1'b1;

	wire w_int_tx , w_int_rx , w_busy;
	wire [7:0]w_data_rx;
	reg  [7:0]r_data_tx;
	
 	i2c_slave #( .I2C_SLAVE_ADR(I2C_SLAVE_ADR)// Slave address, default value 7'h08 (Type - Hex, Default value = 7'h08, Min value = 7'h01, Max value = 7'h7F)
		) i2c_slave 
		(
    		// common port
    		.i_clk(i_clk),      //  input clock signal
    		.i_rst(i_rst),      //  input reset signal
    		.i_en(1),       //  input signal which start operation
    		.o_busy(w_busy),     //  output which indicates the operation state
    		// interface port
    		.i_scl(i_scl),      //  input serial clock signal
    		.i_sda(i_sda),      //  input serial data signal
    		.o_sda(o_sda),      //  output serial data signal
    		.o_sda_oe(o_sda_oe),   //  output enable signal for serial data output signal
    		// internal port
    		.i_data_tx(r_data_tx),  //  data inputs bus
    		.o_data_rx(w_data_rx),  //  data outputs bus
    		.o_int_tx(w_int_tx),   //  output signal which indicates that i_data_tx was sent
    		.o_int_rx(w_int_rx)    //  output signal which indicates that o_data_rx was updated
		);

	reg led_on;
	
	always @ (posedge i_clk) begin 
		if(i_rst)begin
			led_on <= 1'b0;
		end 
		if(w_int_rx) begin
			r_data_tx <= w_data_rx;
			if (w_data_rx == 8'hAA) begin 
				led_on <= 1'b1;
			end
			else if (w_data_rx == 8'hFF) begin
				led_on <= 1'b0;
			end 
			else led_on <=led_on;
		end
	end
	
	assign o_led = led_on;
	
endmodule 
