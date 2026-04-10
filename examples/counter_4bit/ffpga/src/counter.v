(* top *) module counter(
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) input nreset,
    (* iopad_external_pin *) input up_down,
    (* iopad_external_pin *) output [3:0] out_oe,
    (* iopad_external_pin *) output osc_en,
    (* iopad_external_pin *) output [3:0] count
);

 reg [3:0] counter_reg;
 reg [25:0] time_steps;
 
 assign out_oe = 4'b1111; 
 assign osc_en = 1'b1;
 assign count  = counter_reg;

 always @(posedge clk or negedge nreset) begin
    if (!nreset) begin
        counter_reg <= 4'h0;
        time_steps  <= 26'd0;
    end else begin
        if (time_steps >= 26'd49_999_999) begin 
            time_steps <= 26'd0;
            if (up_down)
                counter_reg <= counter_reg + 4'd1;
            else
                counter_reg <= counter_reg - 4'd1;
        end else begin
            time_steps <= time_steps + 26'd1;
        end
    end
 end
endmodule