// Breathing Demo (Improved)

// DemoSequentialBreathing.v

(* top *)
module DemoSequentialBreathing #(
  parameter IN_CLK_HZ = 44500000,
  parameter DEPTH = 8
) (
  (* iopad_external_pin *) input  nreset,
  (* iopad_external_pin, clkbuf_inhibit *) input clk,
  (* iopad_external_pin *) output osc_en,
  (* iopad_external_pin *) output led_0,
  (* iopad_external_pin *) output led0_oe,
  (* iopad_external_pin *) output led_1,
  (* iopad_external_pin *) output led1_oe,
  (* iopad_external_pin *) output led_2,
  (* iopad_external_pin *) output led2_oe,
  (* iopad_external_pin *) output led_3,
  (* iopad_external_pin *) output led3_oe,
  (* iopad_external_pin *) output reg led_4,
  (* iopad_external_pin *) output led4_oe,
  (* iopad_external_pin *) output reg led_5,
  (* iopad_external_pin *) output led5_oe,
  (* iopad_external_pin *) output reg led_6,
  (* iopad_external_pin *) output led6_oe,
  (* iopad_external_pin *) output reg led_7,
  (* iopad_external_pin *) output led7_oe
);

  // Enable internal oscillator
  assign osc_en = 1'b1;

  // LED output enables
  assign led0_oe = 1;
  assign led1_oe = 1;
  assign led2_oe = 1;
  assign led3_oe = 1;
  assign led4_oe = 1;
  assign led5_oe = 1;
  assign led6_oe = 1;
  assign led7_oe = 1;

  localparam BLINK_1HZ = 25_000_000;
  localparam BLINK_2HZ = 12_500_000;
  localparam BLINK_4HZ = 6_250_000;
  localparam BLINK_8HZ = 3_125_000;

  reg [2:0] seq_counter;
  reg [26:0] blink_counter;
  reg [3:0] blink_count;
  reg [2:0] state;
  reg r_led;

  wire [7:0] done;  // ✅ must be wire, because driven by submodules

  wire next = |done;

  // Enable signal for each LED in sequence
  wire [7:0] en;
  assign en = 8'b1 << seq_counter;

  // Sequence counter
  always @(posedge clk) begin
    if (!nreset) begin
      seq_counter <= 0;
    end else if (next) begin
      seq_counter <= seq_counter + 1;
    end
  end

  // Sequential blinking state machine
  always @(posedge clk) begin
    if (!nreset) begin
      state <= 3'b000;
      blink_counter <= 0;
      blink_count <= 0;
      r_led <= 0;
      led_4 <= 0;
      led_5 <= 0;
      led_6 <= 0;
      led_7 <= 0;
    end else begin
      case (state)
        3'b000: begin
          blink_counter <= 0;
          blink_count <= 0;
          r_led <= 0;
          led_4 <= 0;
          led_5 <= 0;
          led_6 <= 0;
          led_7 <= 0;
          if (en[4]) state <= 3'b001;
        end

        3'b001: begin
          if (blink_counter == BLINK_1HZ) begin
            blink_counter <= 0;
            r_led <= ~r_led;
            if (blink_count == 9) begin
              state <= 3'b010;
              r_led <= 0;
              blink_count <= 0;
            end else begin
              blink_count <= blink_count + 1;
            end
          end else begin
            blink_counter <= blink_counter + 1;
          end
          led_4 <= r_led;
        end

        3'b010: begin
          if (blink_counter == BLINK_2HZ) begin
            blink_counter <= 0;
            r_led <= ~r_led;
            if (blink_count == 9) begin
              state <= 3'b011;
              r_led <= 0;
              blink_count <= 0;
            end else begin
              blink_count <= blink_count + 1;
            end
          end else begin
            blink_counter <= blink_counter + 1;
          end
          led_5 <= r_led;
        end

        3'b011: begin
          if (blink_counter == BLINK_4HZ) begin
            blink_counter <= 0;
            r_led <= ~r_led;
            if (blink_count == 9) begin
              state <= 3'b100;
              r_led <= 0;
              blink_count <= 0;
            end else begin
              blink_count <= blink_count + 1;
            end
          end else begin
            blink_counter <= blink_counter + 1;
          end
          led_6 <= r_led;
        end

        3'b100: begin
          if (blink_counter == BLINK_8HZ) begin
            blink_counter <= 0;
            r_led <= ~r_led;
            if (blink_count == 9) begin
              state <= 3'b000;
              r_led <= 0;
              blink_count <= 0;
            end else begin
              blink_count <= blink_count + 1;
            end
          end else begin
            blink_counter <= blink_counter + 1;
          end
          led_7 <= r_led;
        end

        default: state <= 3'b000;
      endcase
    end
  end

  // Breathing LED instances
  breathing #(
    .IN_CLK_HZ(IN_CLK_HZ),
    .DEPTH(DEPTH),
    .PWM_FREQ_HZ(50),
    .RAMP_MULT(1)
  ) breathing_led0 (
    .clk(clk), .nreset(nreset), .en(en[0]), .out(led_0), .done(done[0])
  );

  breathing #(
    .IN_CLK_HZ(IN_CLK_HZ),
    .DEPTH(DEPTH),
    .PWM_FREQ_HZ(100),
    .RAMP_MULT(1)
  ) breathing_led1 (
    .clk(clk), .nreset(nreset), .en(en[1]), .out(led_1), .done(done[1])
  );

  breathing #(
    .IN_CLK_HZ(IN_CLK_HZ),
    .DEPTH(DEPTH),
    .PWM_FREQ_HZ(500),
    .RAMP_MULT(2)
  ) breathing_led2 (
    .clk(clk), .nreset(nreset), .en(en[2]), .out(led_2), .done(done[2])
  );

  breathing #(
    .IN_CLK_HZ(IN_CLK_HZ),
    .DEPTH(DEPTH),
    .PWM_FREQ_HZ(1000),
    .RAMP_MULT(2)
  ) breathing_led3 (
    .clk(clk), .nreset(nreset), .en(en[3]), .out(led_3), .done(done[3])
  );

endmodule


`timescale 1ns / 1ps

module breathing #(
  parameter IN_CLK_HZ = 49000000,
  parameter DEPTH = 8,
  parameter PWM_FREQ_HZ = 400,
  parameter RAMP_MULT = 1
) (
  input clk,
  input nreset,
  input en,
  output reg out,
  output done // custom code
);

  localparam CNT_SLOW = IN_CLK_HZ / PWM_FREQ_HZ / (2**DEPTH);
  localparam CNT_SLOW_WIDTH = $clog2(CNT_SLOW);
  localparam CNT_RAMP_WIDTH = $clog2(RAMP_MULT);

  reg clk_en = 1'b0;
  reg [CNT_SLOW_WIDTH-1:0] cnt_slow_reg = 'h0;
  reg [DEPTH-1:0] cnt_pwm_reg = 'h0;
  reg [DEPTH-1:0] cnt_duty_reg = 'h0;
  reg [CNT_RAMP_WIDTH:0] cnt_ramp_reg = 'h0;
  reg dir_reg = 1'b0;

  always @(posedge clk) begin
    if (!nreset) begin
      cnt_slow_reg <= 'h0;
      clk_en <= 1'b0;
    end else begin
      if (en) begin
        clk_en <= 1'b0;
        if (cnt_slow_reg < CNT_SLOW) begin
          cnt_slow_reg <= cnt_slow_reg + 1;
        end else begin
          cnt_slow_reg <= 'h0;
          clk_en <= 1'b1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!nreset) begin
      cnt_pwm_reg <= 'h0;
      cnt_ramp_reg <= 'h0;
      cnt_duty_reg <= 'h0;
      dir_reg <= 1'b0;
    end else begin
      if (en) begin
        if (clk_en) begin
          cnt_pwm_reg <= cnt_pwm_reg + 1;
          if (&cnt_pwm_reg) begin
            cnt_pwm_reg <= 'h0;
            cnt_ramp_reg <= cnt_ramp_reg + 1;
            if (cnt_ramp_reg >= (RAMP_MULT-1)) begin
              cnt_ramp_reg <= 'h0;
              cnt_duty_reg <= cnt_duty_reg + 1;
              if (&cnt_duty_reg) begin
                cnt_duty_reg <= 'h0;
                dir_reg <= ~dir_reg;
              end
            end
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    if (!nreset) begin
      out <= 1'b0;
    end else begin
      if (en) begin
        out <= (dir_reg==0) ? ((cnt_pwm_reg<cnt_duty_reg) ? 1:0) : ((cnt_pwm_reg<cnt_duty_reg) ? 0:1);
      end else begin
        out <= 1'b0;
      end
    end
  end

// Begin of the custom code part
  reg [1:0] dir_fedge;

  always @(posedge clk) begin
    if (!nreset) dir_fedge <= 'h0;
    else begin
      dir_fedge[0] <= dir_reg;
      dir_fedge[1] <= dir_fedge[0];
    end
  end
  
  assign done = ~dir_fedge[0] & dir_fedge[1];
// End of the custom code part

endmodule
