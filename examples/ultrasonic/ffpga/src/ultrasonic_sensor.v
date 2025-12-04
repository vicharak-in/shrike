//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Upendra Reddi <upendrareddi667@gmail.com>
// 
// Create Date:     December 03, 2025
// Design Name:     ULTRASONIC SENSOR
// Module Name:     ultrasonic_sensor.v
// Project:         Shrike-Lite Examples
// Target Device:   Shrike-Lite (RP2040 + Renesas FPGA (SLG47910V))
// Tool Versions:   Go Configure Software Hub v.6.48
// 
// Description: 
//    This module will generate the trig pulse and recevies the echo.  
//    Based on the time, calculates the time and detects whether the  
//	  object is in the range or not.
// 
// Dependencies: NONE
// 
// Version:
//    1.0 - 03/12/2025 - Initial release
// 
// Additional Comments: 
//
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2025
//-----------------------------------------------------------------------------

module ultrasonic_sensor #(
	parameter CLK_FREQ  = 50000000,
	parameter TRIG_PULSE_US = 10,
	parameter MAX_DIST_CM    = 20
) (
    input		clk,
    input     	echo,
    output reg  trig,
    output reg  object_detected
);

localparam SOUND_SPEED_CM_PER_US = 0.0343 / 2;
localparam MAX_ECHO_TIME_US      = MAX_DIST_CM / SOUND_SPEED_CM_PER_US;
localparam MAX_COUNT             = (MAX_ECHO_TIME_US * (CLK_FREQ / 1_000_000));
localparam DEBOUNCE_CNT_LIMIT	= 5_00_000;  // 10 ms at 50 MHz (min time)

// Internal registers
reg [31:0]  echo_count = 0;
reg         echo_prev = 0;
reg [31:0]  trig_counter = 0;
reg			detect = 0;
reg [31:0]  debounce_clk_cnt = 0;

// Trigger pulse generator (10us pulse every 60ms)
always @(posedge clk) begin
    if (trig_counter < (CLK_FREQ * 60_000 / 1_000_000)) begin
        trig_counter <= trig_counter + 1;
    end else begin
        trig_counter <= 0;
    end

    if (trig_counter < (TRIG_PULSE_US * (CLK_FREQ / 1_000_000)))
        trig <= 1;
    else
        trig <= 0;
end

// Echo pulse measurement
always @(posedge clk) begin
    echo_prev <= echo;

    // Detects rising edge of echo and handles echo_count
    if (~echo_prev && echo) begin
        echo_count <= 0;
    end
    else if (echo) begin
        echo_count <= echo_count + 1;
    end

    // Detects falling edge of echo and compares with MAX_COUNT
    if (echo_prev && ~echo) begin
        if (echo_count <= MAX_COUNT)
            detect <= 1;
        else
            detect <= 0;
    end
end

// Debounce logic to remove glitches
always @(posedge clk) begin
    if((object_detected != detect) && (debounce_clk_cnt < DEBOUNCE_CNT_LIMIT)) begin
        debounce_clk_cnt <= debounce_clk_cnt + 1;
    end
    else if(debounce_clk_cnt == DEBOUNCE_CNT_LIMIT) begin
        object_detected <= detect;
        debounce_clk_cnt <= 0;
    end 
    else begin
        debounce_clk_cnt <= 0;
    end
end
endmodule