(* top *) module blink(
  (* iopad_external_pin, clkbuf_inhibit *) input clk,
  (* iopad_external_pin *) output LED,
  (* iopad_external_pin *) output LED_en,
  (* iopad_external_pin *) output clk_en
  );

  reg [31:0] counter;
  reg LED_status;

  assign LED_en = 1'b1;
  assign clk_en = 1'b1;
  
  always @ (posedge clk) begin
    counter <= counter + 1'b1;
    if (counter == 50_000_000) begin
      LED_status <= !LED_status;
      counter <= 32'b0;
    end
  end

  assign LED = LED_status;

endmodule 