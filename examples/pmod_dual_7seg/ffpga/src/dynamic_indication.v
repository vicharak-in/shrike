// Custom Module

module dynamic_indication(
  input rst,
  input clk,
  output ref_tick
);

  reg [7:0] count;
  
  always @(posedge clk) begin
    if(rst)
      count <= 'h00;
    else 
      count <= count + 1;
  end
  
  assign ref_tick = &count;

endmodule
