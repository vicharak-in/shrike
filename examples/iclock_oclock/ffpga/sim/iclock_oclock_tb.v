`timescale 1ns/1ps

module iclock_oclock_tb;
  // 26 MHz period = 38.461538 ns.
  reg iclock = 1'b0;
  always #19.230769 iclock = ~iclock;

  wire        PLL_REF_CLK_SELECTION;
  wire        PLL_CTRL_BYPASS;
  wire        PLL_CTRL_EN;
  wire [5:0]  PLL_CTRL_REFDIV;
  wire [11:0] PLL_CTRL_FBDIV;
  wire [2:0]  PLL_CTRL_POSTDIV1;
  wire [2:0]  PLL_CTRL_POSTDIV2;
  wire        OSC_CTRL_EN;
  wire        oclock;
  wire        oclock_oe;
  wire        led;
  wire        led_oe;

  integer input_edges = 0;
  integer last_output_edge = 0;
  integer output_edges = 0;
  integer last_led_edge = 0;
  integer led_edges = 0;

  iclock_oclock #(
    .LED_HALF_PERIOD_COUNT(24'd15)
  ) dut (
    .iclock(iclock),
    .PLL_REF_CLK_SELECTION(PLL_REF_CLK_SELECTION),
    .PLL_CTRL_BYPASS(PLL_CTRL_BYPASS),
    .PLL_CTRL_EN(PLL_CTRL_EN),
    .PLL_CTRL_REFDIV(PLL_CTRL_REFDIV),
    .PLL_CTRL_FBDIV(PLL_CTRL_FBDIV),
    .PLL_CTRL_POSTDIV1(PLL_CTRL_POSTDIV1),
    .PLL_CTRL_POSTDIV2(PLL_CTRL_POSTDIV2),
    .OSC_CTRL_EN(OSC_CTRL_EN),
    .oclock(oclock),
    .oclock_oe(oclock_oe),
    .led(led),
    .led_oe(led_oe)
  );

  always @(posedge iclock)
    input_edges = input_edges + 1;

  always @(oclock) begin
    if ($time != 0) begin
      if ((input_edges - last_output_edge) != 400) begin
        $display("FAIL: output edge after %0d input clocks", input_edges - last_output_edge);
        $finish;
      end
      last_output_edge = input_edges;
      output_edges = output_edges + 1;

      if (output_edges == 4 && led_edges >= 4) begin
        $display("PASS: oclock divide-by-800 and iclock-driven LED heartbeat verified");
        $finish;
      end
    end
  end


  always @(led) begin
    if ($time != 0) begin
      if ((input_edges - last_led_edge) != 16) begin
        $display("FAIL: LED edge after %0d input clocks", input_edges - last_led_edge);
        $finish;
      end
      last_led_edge = input_edges;
      led_edges = led_edges + 1;
    end
  end

  initial begin
    #1;
    if (PLL_REF_CLK_SELECTION !== 1'b1 ||
        PLL_CTRL_BYPASS       !== 1'b1 ||
        PLL_CTRL_EN           !== 1'b1 ||
        PLL_CTRL_REFDIV       !== 6'd1 ||
        PLL_CTRL_FBDIV        !== 12'd49 ||
        PLL_CTRL_POSTDIV1     !== 3'd7 ||
        PLL_CTRL_POSTDIV2     !== 3'd7 ||
        OSC_CTRL_EN           !== 1'b0 ||
        oclock_oe             !== 1'b1 ||
        led_oe                !== 1'b1) begin
      $display("FAIL: invalid clock-routing or output-enable controls");
      $finish;
    end
  end

  initial begin
    #100000;
    $display("FAIL: simulation timeout");
    $finish;
  end
endmodule
