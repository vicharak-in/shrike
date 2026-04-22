
module counter_1s(
  input clk,
  input rst,
  output reg tick
);

  reg [25:0] count;
  
  always @(posedge clk) begin
    if(rst) begin
      count <= 26'h00;
      tick <= 1'b1;
    end else if(count <= 49999999) begin
      count <= count + 1;
      tick <= 1'b0;
    end else begin
      count <= 26'h00;
      tick <= 1'b1;
    end
  end

endmodule