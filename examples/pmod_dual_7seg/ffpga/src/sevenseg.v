`timescale 1ns/1ps

(*top*) module sevenseg (
  (* iopad_external_pin *) input nreset, 
  (* iopad_external_pin, clkbuf_inhibit *) input clk,
  (* iopad_external_pin *) output osc_en,
  (* iopad_external_pin *) output out_a,
  (* iopad_external_pin *) output out_b,
  (* iopad_external_pin *) output out_c,
  (* iopad_external_pin *) output out_d,
  (* iopad_external_pin *) output out_e,
  (* iopad_external_pin *) output out_f,
  (* iopad_external_pin *) output out_g,
  (* iopad_external_pin *) output active_digit,
  (* iopad_external_pin *) output out_a_oe,
  (* iopad_external_pin *) output out_b_oe,
  (* iopad_external_pin *) output out_c_oe,
  (* iopad_external_pin *) output out_d_oe,
  (* iopad_external_pin *) output out_e_oe,
  (* iopad_external_pin *) output out_f_oe,
  (* iopad_external_pin *) output out_g_oe,
  (* iopad_external_pin *) output active_digit_oe  
  );
  
  wire [7:0] w_timer_count;
  wire w_ref_tick;
  wire w_tick;
  wire rst;
  
  assign rst = !nreset;
  assign osc_en = 1'b1;
 
//oe 
	assign out_a_oe = 1; assign out_b_oe = 1;
	assign out_c_oe = 1; assign out_d_oe = 1;
	assign out_e_oe = 1; assign out_f_oe = 1;
	assign out_g_oe = 1; assign active_digit_oe = 1;

  counter_1s counter_1s_wrapp(
   .clk (clk),
   .rst (rst),
   .tick (w_tick)
  );

  dynamic_indication dyn_ind_wrapp(
   .rst (rst),
   .clk (clk),
   .ref_tick (w_ref_tick)
  );
  
  timer_FSM timer_FSM_wrapp (
   .clk (clk),
   .rst (rst),
   .tick (w_tick),
   .timer_count (w_timer_count)
  );

 seven_segment_disp #(
  .SEL_CA (1)
 )seven_segment_disp_wrapp (
  .clk (clk),
  .load (w_tick),
  .en (1'b1),
  .rst(rst),
  .refresh_clock(w_ref_tick),
  .data ({2'b00,w_timer_count}),
  .active_digit(active_digit),
  .out_a(out_a),
  .out_b(out_b),
  .out_c(out_c),
  .out_d(out_d),
  .out_e(out_e),
  .out_f(out_f),
  .out_g(out_g)
  );
  
  

endmodule