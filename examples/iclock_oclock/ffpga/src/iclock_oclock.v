`timescale 1ns/1ps

// Divide the external 26 MHz clock on GPIO2 down to 32.5 kHz on GPIO7.
//
// GPIO2 is the SLG47910's dedicated external PLL-reference input. The PLL is
// put in bypass mode so the external clock reaches the FPGA global clock tree
// without frequency synthesis. The fabric then divides the clock by 800.

(* top *) module iclock_oclock #(
  // Toggle the debug LED every 0.5 seconds at 26 MHz. The testbench
  // overrides this terminal count to keep simulation fast.
  parameter [23:0] LED_HALF_PERIOD_COUNT = 24'd12_999_999
) (
  // PLL_CLK after the external-reference bypass path from GPIO2.
  (* iopad_external_pin, clkbuf_inhibit *) input iclock,

  // Dedicated PLL controls.
  (* iopad_external_pin *) output        PLL_REF_CLK_SELECTION,
  (* iopad_external_pin *) output        PLL_CTRL_BYPASS,
  (* iopad_external_pin *) output        PLL_CTRL_EN,
  (* iopad_external_pin *) output [5:0]  PLL_CTRL_REFDIV,
  (* iopad_external_pin *) output [11:0] PLL_CTRL_FBDIV,
  (* iopad_external_pin *) output [2:0]  PLL_CTRL_POSTDIV1,
  (* iopad_external_pin *) output [2:0]  PLL_CTRL_POSTDIV2,
  (* iopad_external_pin *) output        OSC_CTRL_EN,

  // 32.5 kHz LVCMOS output on GPIO7 and its I/O-buffer enable.
  (* iopad_external_pin *) output reg oclock = 1'b0,
  (* iopad_external_pin *) output     oclock_oe,

  // Active-high on-board FPGA debug LED on GPIO16.
  (* iopad_external_pin *) output reg led = 1'b0,
  (* iopad_external_pin *) output     led_oe
);

  // Select GPIO2 as the reference and bypass the PLL frequency synthesizer.
  assign PLL_REF_CLK_SELECTION = 1'b1;
  assign PLL_CTRL_BYPASS       = 1'b1;
  assign PLL_CTRL_EN           = 1'b1;

  // These values are ignored in bypass mode, but keep every PLL control at a
  // valid, deterministic setting.
  assign PLL_CTRL_REFDIV   = 6'd1;
  assign PLL_CTRL_FBDIV    = 12'd49;
  assign PLL_CTRL_POSTDIV1 = 3'd7;
  assign PLL_CTRL_POSTDIV2 = 3'd7;

  // The on-chip oscillator is not used. GPIO7 is always an output in user
  // mode.
  assign OSC_CTRL_EN = 1'b0;
  assign oclock_oe   = 1'b1;
  assign led_oe      = 1'b1;

  // 26,000,000 / (2 * 400) = 32,500 Hz with a 50% duty cycle.
  reg [8:0] half_period_count = 9'd0;

  always @(posedge iclock) begin
    if (half_period_count == 9'd399) begin
      half_period_count <= 9'd0;
      oclock            <= ~oclock;
    end else begin
      half_period_count <= half_period_count + 1'b1;
    end
  end

  // A visible heartbeat proves that GPIO2 -> PLL bypass -> PLL_CLK -> fabric
  // is alive, independently of observing the 32.5 kHz output on a scope.
  reg [23:0] led_half_period_count = 24'd0;

  always @(posedge iclock) begin
    if (led_half_period_count == LED_HALF_PERIOD_COUNT) begin
      led_half_period_count <= 24'd0;
      led                   <= ~led;
    end else begin
      led_half_period_count <= led_half_period_count + 1'b1;
    end
  end

endmodule
