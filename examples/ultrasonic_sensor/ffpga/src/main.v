//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Upendra Reddi <upendrareddi667@gmail.com>
// 
// Create Date:     December 03, 2025
// Design Name:     ULTRASONIC SENSOR
// Module Name:     top.v
// Project:         Shrike-Lite Examples
// Target Device:   Shrike-Lite (RP2040 + Renesas FPGA (SLG47910V))
// Tool Versions:   Go Configure Software Hub v.6.48
// 
// Description: 
//    This module is the top module of ultrasonic_sensor,that will  
//    generate multiple instances of ultrasonic_sensor design based 
//	  on the NUM_SENSORS parameter.
// 
// Dependencies: ultrasonic_sensor.v
// 
// Version:
//    1.0 - 03/12/2025 - Initial release
// 
// Additional Comments: 
//
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2025
//-----------------------------------------------------------------------------

(* top *) module top #(
    parameter NUM_SENSORS 	= 1,
    parameter CLK_FREQ     	= 50000000,
	parameter TRIG_PULSE_US  = 10,
	parameter MAX_DIST_CM    = 20
)(
    (* iopad_external_pin, clkbuf_inhibit *) input   	 clk,
    (* iopad_external_pin *) input  [NUM_SENSORS-1:0] echo,
    (* iopad_external_pin *) output [NUM_SENSORS-1:0] trig,
    (* iopad_external_pin *) output [NUM_SENSORS-1:0] object_detected,
    (* iopad_external_pin *) output [NUM_SENSORS-1:0] trig_en,
    (* iopad_external_pin *) output [NUM_SENSORS-1:0] object_detected_en,
    (* iopad_external_pin *) output 					 clk_en
);

assign clk_en   = 1'b1;
assign trig_en  = {NUM_SENSORS{1'b1}};
assign object_detected_en =  {NUM_SENSORS{1'b1}};

genvar i;
generate
    for (i = 0; i < NUM_SENSORS; i = i + 1) begin : ULTRASONIC_SENSOR

        ultrasonic_sensor #(
        		.CLK_FREQ (CLK_FREQ),
        		.TRIG_PULSE_US (TRIG_PULSE_US),
        		.MAX_DIST_CM (MAX_DIST_CM)
        ) SENSOR_INST (
            .clk               (clk),
            .echo              (echo[i]),
            .trig              (trig[i]),
            .object_detected   (object_detected[i])
        );

    end
endgenerate
endmodule