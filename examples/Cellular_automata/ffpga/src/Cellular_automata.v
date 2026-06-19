(* top *) module Cellular_automata (
    (* iopad_external_pin, clkbuf_inhibit *) input  clk,
    (* iopad_external_pin *)                 input  reset,

    // 4 mode switches
    (* iopad_external_pin *) input  sw0,  // Rule 30
    (* iopad_external_pin *) input  sw1,  // Rule 90
    (* iopad_external_pin *) input  sw2,  // Rule 110
    (* iopad_external_pin *) input  sw3,  // Rule 45

    (* iopad_external_pin *) output DO,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) output do_en
);

assign do_en       = 1'b1;
assign clk_en = 1'b1;

// Rule select 
reg [7:0] active_rule;
always @(*) begin
    if      (sw0) active_rule = 8'd30;
    else if (sw1) active_rule = 8'd90;
    else if (sw2) active_rule = 8'd110;
    else if (sw3) active_rule = 8'd45;
    else          active_rule = 8'd30;  // default if none high
end

//Generation timer ~1.49Hz
reg [24:0] timer;
wire gen_tick = (timer == 25'd0);
always @(posedge clk) timer <= timer + 1;

//4 rows of 4 cells 
reg [3:0] row0, row1, row2, row3;

wire [3:0] ng;  //next generation
wire [7:0] r = active_rule;

// For each cell i: idx = {left, center, right} with wrap
assign ng[0] = (r >> {row0[3], row0[0], row0[1]}) & 1'b1;
assign ng[1] = (r >> {row0[0], row0[1], row0[2]}) & 1'b1;
assign ng[2] = (r >> {row0[1], row0[2], row0[3]}) & 1'b1;
assign ng[3] = (r >> {row0[2], row0[3], row0[0]}) & 1'b1;

reg [3:0] sw_prev;
wire sw_changed = (sw_prev != {sw3, sw2, sw1, sw0});

always @(posedge clk) sw_prev <= {sw3, sw2, sw1, sw0};

// scroll down, new row at top 
always @(posedge clk) begin
    if (!reset || sw_changed) begin
        row0 <= 4'b0100;
        row1 <= 4'b0000;
        row2 <= 4'b0000;
        row3 <= 4'b0000;
    end else if (gen_tick) begin
        row0 <= ng;
        row1 <= row0;
        row2 <= row1;
        row3 <= row2;
    end
end

// Flatten to 16-bit
wire [15:0] grid = {row3, row2, row1, row0};

// Color per mode 
wire [3:0] ws_addr;
wire       alive = grid[ws_addr];

reg [7:0] ws_red, ws_green, ws_blue;
always @(*) begin
    if (alive) begin
        if      (sw0) begin ws_red = 8'd220; ws_green = 8'd20;  ws_blue = 8'd20;  end  // red
        else if (sw1) begin ws_red = 8'd20;  ws_green = 8'd220; ws_blue = 8'd20;  end  // green
        else if (sw2) begin ws_red = 8'd200;  ws_green = 8'd200;  ws_blue = 8'd200; end  // white
        else if (sw3) begin ws_red = 8'd200; ws_green = 8'd120; ws_blue = 8'd0;   end  // amber
        else          begin ws_red = 8'd80;  ws_green = 8'd20;  ws_blue = 8'd220; end  // default purple
    end else begin
        ws_red   = 8'd0;
        ws_green = 8'd8;
        ws_blue  = 8'd15;  // dim teal background always
    end
end


ws2812 #(
    .NUM_LEDS(16),
    .SYSTEM_CLOCK(50_000_000)
) driver (
    .clk(clk),
    .reset(~reset),
    .address(ws_addr),
    .red_in(ws_red),
    .green_in(ws_green),
    .blue_in(ws_blue),
    .DO(DO)
);

endmodule
