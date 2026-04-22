/*
---------------------------------------------------------------------------
Copyright 2021 Dialog Semiconductor

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
---------------------------------------------------------------------------
Base Module Name: seven_seg_disp_ctrl_2d
Target Devices: SLG47910
Tools version:
  Software: FPGA Navigator v1.0
  Hardware: FPGAPAK Development Board Rev.1.0
Revision:
  05.11.2021 r001 - New design
---------------------------------------------------------------------------
Description :
The seven-segment display controller is used for displaying numbers and symbols on seven segment display.

    Table 1. Data for common anode seven-segment LED display
    ===========================================================================
    | input |   a   |   b   |   c   |   d   |   e   |   f   |   g   | display |
    ---------------------------------------------------------------------------             ===== a =====
    | 0000  |   0   |   0   |   0   |   0   |   0   |   0   |   1   |    0    |            ||           ||
    | 0001  |   1   |   0   |   0   |   1   |   1   |   1   |   1   |    1    |            ||           ||
    | 0010  |   0   |   0   |   1   |   0   |   0   |   1   |   0   |    2    |            f             b
    | 0011  |   0   |   0   |   0   |   0   |   1   |   1   |   0   |    3    |            ||           ||
    | 0100  |   1   |   0   |   0   |   1   |   1   |   0   |   0   |    4    |            ||           ||
    | 0101  |   0   |   1   |   0   |   0   |   1   |   0   |   0   |    5    |             ===== g =====
    | 0110  |   0   |   1   |   0   |   0   |   0   |   0   |   0   |    6    |            ||           ||
    | 0111  |   0   |   0   |   0   |   1   |   1   |   1   |   1   |    7    |            ||           ||
    | 1000  |   0   |   0   |   0   |   0   |   0   |   0   |   0   |    8    |            e             c
    | 1001  |   0   |   0   |   0   |   0   |   1   |   0   |   0   |    9    |            ||           ||
    | 1010  |   0   |   0   |   0   |   1   |   0   |   0   |   0   |    A    |            ||           ||
    | 1011  |   1   |   1   |   0   |   0   |   0   |   0   |   0   |    b    |	            ===== d =====  {dp}
    | 1100  |   0   |   1   |   1   |   0   |   0   |   0   |   1   |    C    |
    | 1101  |   1   |   0   |   0   |   0   |   0   |   1   |   0   |    d    |
    | 1110  |   0   |   1   |   1   |   0   |   0   |   0   |   0   |    E    |
    | 1111  |   0   |   1   |   1   |   1   |   0   |   0   |   0   |    F    |
    ===========================================================================

---------------------------------------------------------------------------
PARAMETERS
  Name    :  Range        :  Default  :  Description
  SEL_CA  :  1 bit value  :  0        :  0 - common anode: 1 - common cathode
---------------------------------------------------------------------------
PINS
  clk - input clock signal
  nreset - input negative reset signal
  data - input data bus
  load - load signal
  en - display enable signal
  refresh_clock - clock from the external counter for dynamic indication
  active_digit - active digit of seven-segment display. Connected to Ground/Vcc based on type of display
  out_a, out_b,.., out_f, out_g - seven-segment LED outputs
  out_dp - decimal point LED outputs
---------------------------------------------------------------------------
*/

`timescale 1ns / 1ps

module seven_segment_disp #(
  parameter SEL_CA = 0
) (
  input clk,
  input load,
  input en,
  input rst,
  input refresh_clock,
  input [9:0] data,
  output reg [1:0] active_digit,
  output out_a,
  output out_b,
  output out_c,
  output out_d,
  output out_e,
  output out_f,
  output out_g,
  output reg out_dp
  );

  localparam digit_0 = (SEL_CA) ? 2'b01 : 2'b10;
  localparam digit_1 = (SEL_CA) ? 2'b10 : 2'b01;

  reg [9:0] data_buffer = 0;
  reg [4:0] digit = 0;
  reg [6:0] digit_out = 0;

  always @(posedge clk) begin
    if (rst) begin
      active_digit <= digit_0;
    end else if (refresh_clock) begin
      active_digit <= active_digit << 1;
      active_digit[0] <= active_digit[1];
    end
  end

  always @(posedge clk) begin
    if (rst)
      data_buffer <= 0;
  else if (load)
    data_buffer <= data;
  end

  always @(posedge clk) begin
    if (rst)
      digit <= 'h0;
    else case (active_digit)
      digit_0: digit <= {data_buffer[8], data_buffer[3:0]};
      digit_1: digit <= {data_buffer[9], data_buffer[7:4]};
      default: digit <= {data_buffer[8], data_buffer[3:0]};
    endcase
  end

  always @(posedge clk) begin
    if (rst)
      digit_out <= (SEL_CA) ? 7'b0000000 : 7'b1111111;
    else if (en)
      case (digit[3:0])
        4'b0000 : digit_out <= (SEL_CA) ? 7'b1111110 : 7'b0000001; // "0" 0x01
        4'b0001 : digit_out <= (SEL_CA) ? 7'b0110000 : 7'b1001111; // "1" 0x4F
        4'b0010 : digit_out <= (SEL_CA) ? 7'b1101101 : 7'b0010010; // "2" 0x12
        4'b0011 : digit_out <= (SEL_CA) ? 7'b1111001 : 7'b0000110; // "3" 0x06
        4'b0100 : digit_out <= (SEL_CA) ? 7'b0110011 : 7'b1001100; // "4" 0x4C
        4'b0101 : digit_out <= (SEL_CA) ? 7'b1011011 : 7'b0100100; // "5" 0x24
        4'b0110 : digit_out <= (SEL_CA) ? 7'b1011111 : 7'b0100000; // "6" 0x20
        4'b0111 : digit_out <= (SEL_CA) ? 7'b1110000 : 7'b0001111; // "7" 0x0F
        4'b1000 : digit_out <= (SEL_CA) ? 7'b1111111 : 7'b0000000; // "8" 0x00
        4'b1001 : digit_out <= (SEL_CA) ? 7'b1111011 : 7'b0000100; // "9" 0x04
        4'b1010 : digit_out <= (SEL_CA) ? 7'b1110111 : 7'b0001000; // "A" 0x08
        4'b1011 : digit_out <= (SEL_CA) ? 7'b0011111 : 7'b1100000; // "b" 0x60
        4'b1100 : digit_out <= (SEL_CA) ? 7'b1001110 : 7'b0110001; // "C" 0x31
        4'b1101 : digit_out <= (SEL_CA) ? 7'b0111101 : 7'b1000010; // "d" 0x42
        4'b1110 : digit_out <= (SEL_CA) ? 7'b1001111 : 7'b0110000; // "E" 0x30
        4'b1111 : digit_out <= (SEL_CA) ? 7'b1000111 : 7'b0111000; // "F" 0x38
        default : digit_out <= (SEL_CA) ? 7'b0000000 : 7'b1111111; // display none
      endcase
    else
      digit_out <= (SEL_CA) ? 7'b0000000 : 7'b1111111;
  end

  always @(posedge clk) begin
    if (rst)
      out_dp <= (SEL_CA) ? 1'b0 : 2'b1;
    else if (en)
      out_dp <= (SEL_CA) ? digit[4] : ~digit[4];
    else
      out_dp <= (SEL_CA) ? 1'b0 : 1'b1;
  end

assign out_a = digit_out[6];
assign out_b = digit_out[5];
assign out_c = digit_out[4];
assign out_d = digit_out[3];
assign out_e = digit_out[2];
assign out_f = digit_out[1];
assign out_g = digit_out[0];

endmodule
