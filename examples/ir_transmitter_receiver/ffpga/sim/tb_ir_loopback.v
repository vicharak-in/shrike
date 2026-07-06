// ============================================================
//  Testbench: full IR NEC loopback for ir_top (modulator.v)
//
//  Flow exercised:
//    MCU bit-bang (data_in/clk_in)  -> NEC encoder -> 38kHz carrier
//    -> ir_out  --(loopback model)--> tsop_in -> NEC decoder
//    -> dec_valid / dec_addr / dec_cmd  -> return path (data_out)
//
//  The TSOP1738 is modelled as an active-LOW demodulator:
//  while the 38kHz carrier is bursting, tsop_in = 0 (mark);
//  during gaps (no carrier) tsop_in = 1 (space).
//
//  Run:
//    iverilog -o sim/tb_ir_loopback.vvp sim/tb_ir_loopback.v
//    vvp sim/tb_ir_loopback.vvp
//  View:
//    gtkwave sim/tb_ir_loopback.vcd
// ============================================================
`timescale 1ns / 1ps

`include "../src/carrier_generator.v"
`include "../src/nec_encoder.v"
`include "../src/nec_decoder.v"
`include "../src/modulator.v"

module tb_ir_loopback;

  // ---- DUT I/O ----
  reg  clk = 1'b0;
  reg  data_in = 1'b0;
  reg  clk_in = 1'b0;
  wire data_out, data_out_en;
  wire ir_out, ir_out_en;
  wire fpga_led, fpga_led_en;
  wire clk_en;

  // ---- TSOP loopback model (active-low carrier detector) ----
  // Holds tsop_in LOW for ~28us after each carrier pulse so a
  // continuous 38kHz burst reads as one solid mark, and gaps read high.
  reg [11:0] carrier_hold = 12'd0;
  always @(posedge clk)
  begin
    if (ir_out)
      carrier_hold <= 12'd1400;          // ~28us at 50MHz
    else if (carrier_hold != 0)
      carrier_hold <= carrier_hold - 12'd1;
  end
  wire tsop_in = (carrier_hold != 0) ? 1'b0 : 1'b1;

  // ---- Device under test ----
  ir_top dut (
           .clk (clk),
           .clk_en (clk_en),
           .data_in (data_in),
           .clk_in (clk_in),
           .data_out (data_out),
           .data_out_en (data_out_en),
           .tsop_in (tsop_in),
           .ir_out (ir_out),
           .ir_out_en (ir_out_en),
           .fpga_led (fpga_led),
           .fpga_led_en (fpga_led_en)
         );

  // ---- 50 MHz clock ----
  always #10 clk = ~clk;

  // ---- Bit-bang a 24-bit command (type,addr,cmd) MSB first ----
  task send_word(input [7:0] b0, input [7:0] b1, input [7:0] b2);
    integer i;
    reg [23:0] w;
    begin
      w = {b0, b1, b2};
      for (i = 23; i >= 0; i = i - 1)
      begin
        data_in = w[i];
        #100;
        clk_in = 1'b1;
        #100;   // rising edge -> FPGA shifts a bit
        clk_in = 1'b0;
        #100;
      end
      data_in = 1'b0;
    end
  endtask

  // ---- Stimulus ----
  initial
  begin
    $dumpfile("tb_ir_loopback.vcd");
    // Curated dump (NOT the 50MHz clk / free-running counters) so the
    // VCD stays small and readable in gtkwave.
    $dumpvars(0, data_in);
    $dumpvars(0, clk_in);
    $dumpvars(0, ir_out);
    $dumpvars(0, tsop_in);
    $dumpvars(0, data_out);
    $dumpvars(0, fpga_led);
    $dumpvars(0, dut.nec_send);
    $dumpvars(0, dut.nec_busy);
    $dumpvars(0, dut.mod_enable);
    $dumpvars(0, dut.carrier);
    $dumpvars(0, dut.dec_valid);
    $dumpvars(0, dut.dec_repeat);
    $dumpvars(0, dut.dec_addr);
    $dumpvars(0, dut.dec_cmd);
    $dumpvars(0, dut.rx_status);
    $dumpvars(0, dut.u_enc.state);
    $dumpvars(0, dut.u_dec.state);

    $display("[%0t] Reset / settle", $time);
    #2000;

    $display("[%0t] Sending NEC command: type=0x01 addr=0x12 cmd=0x34", $time);
    send_word(8'h01, 8'h12, 8'h34);

    // Wait for the decoder to validate the looped-back frame
    wait (dut.dec_valid === 1'b1);
    $display("[%0t] DECODED  addr=0x%02h  cmd=0x%02h",
             $time, dut.dec_addr, dut.dec_cmd);

    if (dut.dec_addr === 8'h12 && dut.dec_cmd === 8'h34)
      $display("RESULT: PASS  (loopback decode matches transmitted frame)");
    else
      $display("RESULT: FAIL  (expected 0x12/0x34)");

    #50000;
    $display("[%0t] Done.", $time);
    $finish;
  end

  // ---- Safety timeout (NEC frame ~ 67ms) ----
  initial
  begin
    #150_000_000;          // 150 ms
    $display("[%0t] TIMEOUT - no decode", $time);
    $finish;
  end

endmodule
