// AN-003 How to drive PLL from OSC

(* top *) module counter_4bit_pll (
  //CLK
  (* iopad_external_pin, clkbuf_inhibit *) input pll_clk,
  //POR
  (* iopad_external_pin *) input nreset,
  //OSC
  (* iopad_external_pin *) output OSC_CTRL_EN,
  //PLL
  (* iopad_external_pin *) input sel,//GPIO0
  (* iopad_external_pin *) input byp,//GPIO1
  // Selects the PLL Input Clock source between the internal 50MHz OSC and an external clock.
  (* iopad_external_pin *) output PLL_REF_CLK_SELECTION,
  // BYP is an active HI signal that asserts a direct path between the clock input and FOUT.
  (* iopad_external_pin *) output PLL_CTRL_BYPASS,PLL_CTRL_EN,
  // Sets the reference divide value from 1 to 63.
  (* iopad_external_pin *) output [5:0] PLL_CTRL_REFDIV,
  // Sets the PLL Feedback Divide value from 16 to 400.
  (* iopad_external_pin *) output [11:0] PLL_CTRL_FBDIV,
  // Sets the PLL Output Dividers values from 1 to 7.
  (* iopad_external_pin *) output [2:0] PLL_CTRL_POSTDIV1, PLL_CTRL_POSTDIV2,
  (* iopad_external_pin *) output reg [3:0] counter ,
  (* iopad_external_pin *) output counter_oe0,
  (* iopad_external_pin *) output counter_oe1,
  (* iopad_external_pin *) output counter_oe2,
  (* iopad_external_pin *) output counter_oe3
);

 //OE's settings 
 assign  counter_oe0 = 1'b1;
 assign  counter_oe1 = 1'b1;
 assign  counter_oe2 = 1'b1;
 assign  counter_oe3 = 1'b1;

 //OSC settings
 assign OSC_CTRL_EN = 1'b1; // Oscillator operates at 50MHz 
 
 //PLL settings
 assign PLL_CTRL_EN = 1;
 assign PLL_CTRL_BYPASS = byp;
 assign PLL_REF_CLK_SELECTION = sel;
 assign PLL_CTRL_REFDIV = 2;
 assign PLL_CTRL_FBDIV = 28;
 assign PLL_CTRL_POSTDIV1 = 7;
 assign PLL_CTRL_POSTDIV2 = 5;
 

 reg nrst;

 always @(posedge pll_clk) begin
   nrst <= nreset;
 end
 
 //Counter
 always @(posedge pll_clk) begin
   if (!nrst)
     counter <= 4'h0;
   else
     counter <= counter + 4'h1;
  end

endmodule
