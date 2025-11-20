(* top *) module pmod_led( 
		 (* iopad_external_pin, clkbuf_inhibit *)  input clk ,
		 (* iopad_external_pin *)  output [7:0] led_pmod ,
		 (* iopad_external_pin *)  output clk_en,
		 (* iopad_external_pin *)  output [7:0] led_en 
		 );
		 
	
	assign clk_en = 1'b1;
	assign led_en = 8'b11111111;
	
	reg [31:0] counter;
	reg [7:0] led;
	

  always @ (posedge clk) begin
    counter <= counter + 1'b1;
    if (counter == 50_000_000) begin
      led <= ~led;
      counter <= 32'b0;
    end
  end

  assign led_pmod = led;

endmodule 