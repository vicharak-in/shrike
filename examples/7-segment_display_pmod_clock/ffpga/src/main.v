(*top*) module top_sevenseg_pmod_clock (
  (* iopad_external_pin *) input rst_n, 
  (* iopad_external_pin, clkbuf_inhibit *) input clk,
  (* iopad_external_pin *) output clk_en,
  (* iopad_external_pin *) output out_CA,
  (* iopad_external_pin *) output out_CB,
  (* iopad_external_pin *) output out_CC,
  (* iopad_external_pin *) output out_CD,
  (* iopad_external_pin *) output out_CE,
  (* iopad_external_pin *) output out_CF,
  (* iopad_external_pin *) output out_CG,
  (* iopad_external_pin *) output active_num,
  (* iopad_external_pin *) output out_CA_oe,
  (* iopad_external_pin *) output out_CB_oe,
  (* iopad_external_pin *) output out_CC_oe,
  (* iopad_external_pin *) output out_CD_oe,
  (* iopad_external_pin *) output out_CE_oe,
  (* iopad_external_pin *) output out_CF_oe,
  (* iopad_external_pin *) output out_CG_oe,
  (* iopad_external_pin *) output active_num_oe  
  );
  
  wire [7:0] counter_val;
  wire tick_195KHz;
  wire tick_1Hz;
  wire rst;
  
 // active-low external reset is wired to GPIO7
 // alternatively could also be set to FPGA_CORE_READY signal
 // regardless convert to active-high internally
  assign rst = !rst_n;
  assign clk_en = 1'b1;
 
 //pad-level output enable for PMOD pins on shrike-lite i.e. pulling them out of tristate condition  
 assign out_CA_oe = 1; 
 assign out_CB_oe = 1;
 assign out_CC_oe = 1; 
 assign out_CD_oe = 1;
 assign out_CE_oe = 1; 
 assign out_CF_oe = 1;
 assign out_CG_oe = 1; 
 assign active_num_oe = 1;


 // Take 50MHz system clock, use clock-divider to generate 1Hz clock
  gen_1Hz_tick gen_1Hz_clock(
   .clk (clk),
   .rst (rst),
   .tick (tick_1Hz)
  );

// We have tens and ones digits but only one set of segment pins.
// So a fast clock to switch between ones and tens nibble.
// Every ~5 μs the active digit switches.
// In a nutshell its a refresh rate of ~200 kHz.
// So that both digits appear fully bright at all times.
  time_multiplexing_clock time_mux_clock(
   .rst (rst),
   .clk (clk),
   .time_mux_tick (tick_195KHz)
  );
  
// Use previously generated 1Hz clock to drive the state machine
// This state machine simulates a counter with 1 second tick
  bcd_two_digit_counter bcd_two_digit_FSM(
   .clk (clk),
   .rst (rst),
   .tick (tick_1Hz),
   .counter_val (counter_val)
  );

// Use previously generated time_multiplexing_clock
// We have two digits, but only one set of segment pins.
// Show digit 0 via seven segment pins i.e. ones pattern ith AN pin = LOW
// After 5 µs, show digit 1 via seven segment pins i.e. tens pattern with AN pin = HIGH.
// After 5 µs → back to digit 0 i.e. ones pattern with AN pin = LOW
// Repeat FOREVER
 seven_segment_decoder_driver #(
  .select_cathode_anode (0) 
  // based on type of seven-segment display
  // use 0 for common-cathode
  // use 1 for common-anode
 )seven_segment_decoder_driver_instance (
  .clk (clk),
  .buffer_in (tick_1Hz),
  .enable (1'b1),
  .rst(rst),
  .update_clock(tick_195KHz),
  .data ({2'b00,counter_val}),
  .active_num(active_num),
  .out_CA(out_CA),
  .out_CB(out_CB),
  .out_CC(out_CC),
  .out_CD(out_CD),
  .out_CE(out_CE),
  .out_CF(out_CF),
  .out_CG(out_CG)
  );

endmodule

module bcd_two_digit_counter (
  input  wire       clk,
  input  wire       rst,        // active-high reset
  input  wire       tick,       // one-pulse-per-step strobe
  output reg  [7:0] counter_val // {ones_digit, tens_digit}
);

  // low digit (seconds units) and high digit (tens of seconds)
  reg [3:0] ones_digit;
  reg [3:0] tens_digit;

  // simple three-state FSM
  reg [1:0] state, state_next;

  localparam S_IDLE     = 2'd0;
  localparam S_COUNT    = 2'd1;
  localparam S_ROLLOVER = 2'd2;

  // state register, only advances on tick
  always @(posedge clk) begin
    if (rst)
      state <= S_IDLE;
    else if (tick)
      state <= state_next;
  end

  // next-state logic
  always @* begin
    state_next = state; // default stay
    case (state)
      S_IDLE: begin
        state_next = S_COUNT;
      end

      S_COUNT: begin
        // reached 98 -> go back to idle
        if (tens_digit == 4'd9 && ones_digit == 4'd8)
          state_next = S_IDLE;
        // 8 on ones digit -> prepare to bump tens digit
        else if (ones_digit == 4'd8)
          state_next = S_ROLLOVER;
        // otherwise just keep counting
        else
          state_next = S_COUNT;
      end

      S_ROLLOVER: begin
        // after tens increment, go back to normal counting
        state_next = S_COUNT;
      end

      default: begin
        state_next = S_IDLE;
      end
    endcase
  end

  // digit counters, updated on tick
  always @(posedge clk) begin
    if (rst) begin
      ones_digit <= 4'd0;
      tens_digit <= 4'd0;
    end else if (tick) begin
      case (state)
        S_IDLE: begin
          ones_digit <= 4'd0;
          tens_digit <= 4'd0;
        end

        S_COUNT: begin
          ones_digit <= ones_digit + 4'd1;
        end

        S_ROLLOVER: begin
          ones_digit <= 4'd0;
          tens_digit <= tens_digit + 4'd1;
        end

        default: begin
          ones_digit <= 4'd0;
          tens_digit <= 4'd0;
        end
      endcase
    end
  end

  // always pack into single bus; matches original nibble order {sec_count, dec_sec_count}
  always @* begin
    counter_val = {ones_digit, tens_digit};
  end

endmodule


module seven_segment_decoder_driver #(
  parameter select_cathode_anode = 0
  // based on type of seven-segment display
  // use 0 for common-cathode
  // use 1 for common-anode
) (
  input clk,
  input buffer_in,
  input enable,
  input rst,
  input update_clock,
  input [9:0] data,
  output reg [1:0] active_num,
  output out_CA,
  output out_CB,
  output out_CC,
  output out_CD,
  output out_CE,
  output out_CF,
  output out_CG,
  output reg out_decimal_point
  );

// common-cathode means “active high” on digit pin.
// common-anode means "active low" on digit pin.
  localparam digit_0 = (select_cathode_anode) ? 2'b01 : 2'b10; 
  localparam digit_1 = (select_cathode_anode) ? 2'b10 : 2'b01;

// data is 10 bits:{first_decimal_point, second_decimal_point, tens[3:0], ones[3:0]}
  reg [9:0] data_buffer = 0;
  
// digit is 5 bits: [4] = decimal_point bit, [3:0] = BCD digit
  reg [4:0] digit = 0;
  reg [6:0] digit_out = 0;

// On every update_clock pulse, it flips which digit is active.
// The driver alternates between digit 0, digit 1, digit 0 and so on.
// active_num toggles b/w 10 and 01.
// Recall that update clock is generated from time_multiplexing_clock
//
// This is how time multiplexing works
// | Time     | active digit | BCD sent    | Segments        |
// | -------- | ------------ | ----------- | --------------- |
// | 0–5 µs   | digit 0      | ones nibble | show ones digit |
// | 5–10 µs  | digit 1      | tens nibble | show tens digit |
// | 10–15 µs | digit 0      | ones nibble | show ones digit |
// And so on..
//
// This switching is so fast that both ones and tens digits appear fully bright at all times.

  always @(posedge clk) begin
    if (rst) begin
      active_num <= digit_0;
    end else if (update_clock) begin
      active_num <= active_num << 1;
      active_num[0] <= active_num[1];
    end
  end

// Buffer the data 
  always @(posedge clk) begin
    if (rst)
      data_buffer <= 0;
  else if (buffer_in)
    data_buffer <= data;
  end

// If digit 0 is active then show ones digit.
// If digit 1 is active then show tens digit.
  always @(posedge clk) begin
    if (rst)
      digit <= 'h0;
    else case (active_num) //Should be one of 01 and 10 at a time 
      digit_0: digit <= {data_buffer[8], data_buffer[3:0]};
      digit_1: digit <= {data_buffer[9], data_buffer[7:4]};
      default: digit <= {data_buffer[8], data_buffer[3:0]};
    endcase
  end

// Standard serven segment truth table
  always @(posedge clk) begin
    if (rst)
      digit_out <= (select_cathode_anode) ? 7'b0000000 : 7'b1111111;
    else if (enable)
      case (digit[3:0])
        4'b0000 : digit_out <= (select_cathode_anode) ? 7'b1111110 : 7'b0000001; // "0" 
        4'b0001 : digit_out <= (select_cathode_anode) ? 7'b0110000 : 7'b1001111; // "1" 
        4'b0010 : digit_out <= (select_cathode_anode) ? 7'b1101101 : 7'b0010010; // "2" 
        4'b0011 : digit_out <= (select_cathode_anode) ? 7'b1111001 : 7'b0000110; // "3" 
        4'b0100 : digit_out <= (select_cathode_anode) ? 7'b0110011 : 7'b1001100; // "4" 
        4'b0101 : digit_out <= (select_cathode_anode) ? 7'b1011011 : 7'b0100100; // "5" 
        4'b0110 : digit_out <= (select_cathode_anode) ? 7'b1011111 : 7'b0100000; // "6" 
        4'b0111 : digit_out <= (select_cathode_anode) ? 7'b1110000 : 7'b0001111; // "7" 
        4'b1000 : digit_out <= (select_cathode_anode) ? 7'b1111111 : 7'b0000000; // "8" 
        4'b1001 : digit_out <= (select_cathode_anode) ? 7'b1111011 : 7'b0000100; // "9" 
        4'b1010 : digit_out <= (select_cathode_anode) ? 7'b1110111 : 7'b0001000; // "A" 
        4'b1011 : digit_out <= (select_cathode_anode) ? 7'b0011111 : 7'b1100000; // "b" 
        4'b1100 : digit_out <= (select_cathode_anode) ? 7'b1001110 : 7'b0110001; // "C" 
        4'b1101 : digit_out <= (select_cathode_anode) ? 7'b0111101 : 7'b1000010; // "d" 
        4'b1110 : digit_out <= (select_cathode_anode) ? 7'b1001111 : 7'b0110000; // "E" 
        4'b1111 : digit_out <= (select_cathode_anode) ? 7'b1000111 : 7'b0111000; // "F" 
        default : digit_out <= (select_cathode_anode) ? 7'b0000000 : 7'b1111111; // none
      endcase
    else
      digit_out <= (select_cathode_anode) ? 7'b0000000 : 7'b1111111;
  end

// Uses digit[4] as the decimal_point bit.
// Again, inverted depending on common anode or common cathode.
  always @(posedge clk) begin
    if (rst)
      out_decimal_point <= (select_cathode_anode) ? 1'b0 : 2'b1;
    else if (enable)
      out_decimal_point <= (select_cathode_anode) ? digit[4] : ~digit[4];
    else
      out_decimal_point <= (select_cathode_anode) ? 1'b0 : 1'b1;
  end

assign out_CA = digit_out[6];
assign out_CB = digit_out[5];
assign out_CC = digit_out[4];
assign out_CD = digit_out[3];
assign out_CE = digit_out[2];
assign out_CF = digit_out[1];
assign out_CG = digit_out[0];

endmodule

// time_mux_tick freq = 50MHz / 256 = 195300 Hz
// time_mux_tick period ≈ 5.12 μs
module time_multiplexing_clock(
  input rst,
  input clk,
  output time_mux_tick
);

  reg [7:0] count;
  
  always @(posedge clk) begin
    if(rst)
      count <= 'h00;
    else 
      count <= count + 1;
  end
  
// Logical AND of all 8 bits true only when count is 0xFF or 255
// So time_mux_tick pulses once every 256 clocks 
  assign time_mux_tick = &count;

endmodule

module gen_1Hz_tick(
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
      tick <= 1'b1; // tick pulses high only once every second cause it remains low on 49999999 instances out of total 50000000 instances in one second.
    end
  end

endmodule