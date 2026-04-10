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
//    1.0 - 20/11/2025 - Initial release
// 
// Additional Comments: 
//
// License: 
//    Proprietary © Vicharak Computers PVT LTD - 2025
//-----------------------------------------------------------------------------

module debouncer #(
    parameter DEBOUNCE_CNT_LIMIT = 500_000
)(
    input   		clk,
    input   		i_pulse,
    output  		o_pulse,
);

localparam CNT_WIDTH = $clog2(DEBOUNCE_CNT_LIMIT + 1);

reg [CNT_WIDTH-1:0]  r_clk_cnt = 0;
reg                  r_pulse   = 1'b0;

assign o_pulse     = r_pulse;

always @(posedge clk) begin
    if ((i_pulse != r_pulse) && (r_clk_cnt < DEBOUNCE_CNT_LIMIT)) begin
        r_clk_cnt <= r_clk_cnt + 1;
    end
    else if (r_clk_cnt == DEBOUNCE_CNT_LIMIT) begin
        r_pulse   <= i_pulse;
        r_clk_cnt <= 0;
    end
    else begin
        r_clk_cnt <= 0;
    end
end
endmodule