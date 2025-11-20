//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Upendra Reddi <upendrareddi667@gmail.com>
// 
// Create Date:     November 20, 2025
// Design Name:     Debouncer
// Module Name:     debouncer.v
// Project:         Shrike-Lite Examples
// Target Device:   Shrike-Lite (RP2040 + Renesas FPGA (SLG47910V))
// Tool Versions:   Go Configure Software Hub v.6.48
// 
// Description: 
//    This module is used to debounce any switch or button coming into the FPGA
//    Does not allow the output of the switch to change unless the switch is
//    steady for enough time (not toggling).
// 
// Dependencies: None
// 
// Version:
//    1.0 - 20/11/2025 - KKK - Initial release
// 
// Additional Comments: 
//
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2025
//-----------------------------------------------------------------------------

(* top *) module debouncer(
    (* iopad_external_pin, clkbuf_inhibit *) input   clk,
    (* iopad_external_pin *) input   i_pulse,
    (* iopad_external_pin *) output  o_pulse,
    (* iopad_external_pin *) output  o_pulse_en,
    (* iopad_external_pin *) output  clk_en
);

localparam DEBOUNCE_CNT_LIMIT = 5_00_000;  // 10 ms at 50 MHz (min time)

reg [19:0]  r_clk_cnt = 0;
reg         r_pulse = 1'b0; // To store previous i_pulse value 

assign clk_en = 1'b1;
assign o_pulse_en = 1'b1;
assign o_pulse = r_pulse;

always @(posedge clk) begin
    if((i_pulse != r_pulse) && (r_clk_cnt < DEBOUNCE_CNT_LIMIT)) begin
        r_clk_cnt <= r_clk_cnt + 1;
    end
    else if(r_clk_cnt == DEBOUNCE_CNT_LIMIT) begin
        r_pulse <= i_pulse;
        r_clk_cnt <= 0;
    end 
    else begin
        r_clk_cnt <= 0;
    end
end
endmodule