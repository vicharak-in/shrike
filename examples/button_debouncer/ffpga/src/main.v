//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Upendra Reddi <upendrareddi667@gmail.com>
// 
// Create Date:     November 20, 2025
// Design Name:     Debouncer
// Module Name:     top.v
// Project:         Shrike-Lite Examples
// Target Device:   Shrike-Lite (RP2040 + Renesas FPGA (SLG47910V))
// Tool Versions:   Go Configure Software Hub v.6.48
// 
// Description: 
//    This module is the top module of debouncer,that will generate multiple 
//    instances of debouncer design based on the NUM_PORTS parameter.
// 
// Dependencies: debouncer.v
// 
// Version:
//    1.0 - 20/11/2025 - Initial release
// 
// Additional Comments: 
//
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2025
//-----------------------------------------------------------------------------

(* top *) module top #(
    parameter NUM_PORTS = 1,                   // Number of debouncer channels
    parameter DEBOUNCE_CNT_LIMIT = 5_00_000
)(
    (* iopad_external_pin, clkbuf_inhibit *) input  	    clk,
    (* iopad_external_pin *) input      [NUM_PORTS-1:0]  i_pulse,
    (* iopad_external_pin *) output     [NUM_PORTS-1:0]  o_pulse,
    (* iopad_external_pin *) output                      clk_en,
    (* iopad_external_pin *) output     [NUM_PORTS-1:0]  o_pulse_en
);

assign clk_en     = 1'b1;
assign o_pulse_en =  {NUM_PORTS{1'b1}};

genvar i;
generate
    for (i = 0; i < NUM_PORTS; i = i + 1) begin : GEN_DEBOUNCERS
        debouncer #(
            .DEBOUNCE_CNT_LIMIT(DEBOUNCE_CNT_LIMIT)
        ) u_debouncer (
            .clk(clk),
            .i_pulse(i_pulse[i]),
            .o_pulse(o_pulse[i])
        );
    end
endgenerate
endmodule