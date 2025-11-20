(* top *) module top #(
       parameter CLK = 50_000_000,
       parameter BAUD_RATE = 115200
    )( 
	  (* iopad_external_pin *) input      rx,
	  (* iopad_external_pin *) input      rst,
	  (* iopad_external_pin, clkbuf_inhibit *)input      clk, 
	  (* iopad_external_pin *) output reg led,
 	  (* iopad_external_pin *) output     clk_en,
	  (* iopad_external_pin *) output     led_en );

  
 /* uart module instantiation */

  assign clk_en = 1'b1;
  assign led_en = 1'b1;
  wire [7:0] data;
  wire data_valid;
  uart_rx # ( .CLK(CLK),
  			 .BAUD_RATE(BAUD_RATE) )
  U_uart_rx

    ( 
    .i_Clock(clk),
    .i_RX_Serial(rx),
    .o_RX_DV(data_valid),
    .o_RX_Byte (data)
    );

// ----- logic to control the led based on uart ------ //
/* I wright comment's like this not gpt genrated */

  always @(posedge clk) begin 
    if(rst) begin
      led <= 1'b0;
    end 
      if(data ==  8'hAB)
	led <= 1'b1;
      else if (data == 8'hFF)
	led <= 1'b0;
      else led <= led;
  end

endmodule
