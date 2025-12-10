(* top *) module top #(
       parameter CLK = 50_000_000,
       parameter BAUD_RATE = 115200
    )( 
	  (* iopad_external_pin, clkbuf_inhibit *)input      clk,
 	  (* iopad_external_pin *) output     clk_en,
	  (* iopad_external_pin *) input      rst,
	  (* iopad_external_pin *) input      rx,
	  (* iopad_external_pin *) output     tx,
	  (* iopad_external_pin *) output     tx_en 
);

  assign clk_en = 1'b1;
  assign tx_en = 1'b1;
  
  reg [7:0] num1, num2, sum;
  reg flag = 1'b0;
  
 /* uart_rx module instantiation */
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
    
 /* uart_tx module instantiation */
  uart_tx # ( .IN_CLK_HZ(CLK), 
  			  .DATA_FRAME(8),          
  			  .BAUD_RATE(BAUD_RATE),    
  			  .OVERSAMPLING_MODE(16),        
  			  .STOP_BIT(1),          
  			  .LSB(1'b0) ) 
  U_uart_tx
  	(
	.i_clk(clk),
  	.i_rst(rst),
  	.o_tx(tx),
  	.i_tx_data(sum),    // sum = num1 + num2
  	.i_tx_start(flag),  // transmit sum when flag is HIGH
  	.o_tx_done() 
	);

  localparam S1  = 2'b00;
  localparam S2  = 2'b01;
  localparam S3  = 2'b10;
  localparam S4  = 2'b11;
	
  reg [1:0] state = S1;	
  always @(posedge clk) begin
  	 if (rst) begin
  	 	state <= S1;
  	 end else begin
  	 	if (state == S1 && data_valid) begin
  	 		num1 <= data;
  			state <= S2;
  	 	end else if (state == S2 && data_valid) begin
  	 		num2 <= data;
  	 		state <= S3;
  	 	end else if (state == S3) begin
  	 		sum <= num1 + num2;
  	 		flag <= 1'b1;
  	 		state <= S4;
  	 	end else if (state == S4) begin
  	 	  	flag <= 1'b0;
  	 		state <= S1;
  	 	end
  	 end
  end

endmodule