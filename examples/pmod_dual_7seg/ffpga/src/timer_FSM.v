`timescale 1ns/1ps

module timer_FSM (
  input rst,
  input clk,
  input tick,
  output [7:0] timer_count
);

 reg [3:0] sec_count;
 reg [3:0] dec_sec_count;
 reg [2:0] state, next;
 
 localparam IDLE          = 3'b001;
 localparam SEC_COUNT     = 3'b010;
 localparam DEC_SEC_COUNT = 3'b100;

 always @(posedge clk) begin
   if(rst)
     state <= IDLE;
   else if (tick)
     state <= next;
 end

 always @* begin
    case(state)
        IDLE:           next = SEC_COUNT;

        SEC_COUNT:      if (dec_sec_count == 9 && sec_count == 8)  next = IDLE;
                        else if(sec_count == 8)                    next = DEC_SEC_COUNT;
                        else                                       next = SEC_COUNT;
        
        DEC_SEC_COUNT:                                             next = SEC_COUNT;
        
        default:                                                   next = IDLE;
    endcase
 end

 always @(posedge clk) begin
  if (rst) begin
    sec_count     <= 4'b0000;
    dec_sec_count <= 4'b0000;
  end else if(tick) begin
    case(state)
      IDLE: begin
        sec_count     <= 4'b0000;
        dec_sec_count <= 4'b0000;
      end

      SEC_COUNT: begin
        sec_count <= sec_count + 1;
      end

      DEC_SEC_COUNT: begin
        sec_count <= 4'b0000;
        dec_sec_count <= dec_sec_count + 1;
      end
    endcase
  end
 end

 assign timer_count = {sec_count,dec_sec_count};

endmodule


