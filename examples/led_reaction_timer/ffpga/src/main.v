// Code your design here
(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input  i_osc,
    (* iopad_external_pin *)                 input  i_trigger,
    (* iopad_external_pin *)                 output o_led,
    (* iopad_external_pin *)                 output o_led_oe,
    (* iopad_external_pin *)                 output o_signal,
    (* iopad_external_pin *)                 output o_signal_oe,
    (* iopad_external_pin *)                 output o_osc_en
);

    assign o_osc_en    = 1'b1;
    assign o_led_oe    = 1'b1;	
    assign o_signal_oe = 1'b1;

    reg [31:0] r_free_ctr;
    always @(posedge i_osc)
        r_free_ctr <= r_free_ctr + 1'b1;

    reg [1:0] r_trig_sync;
    always @(posedge i_osc)
        r_trig_sync <= {r_trig_sync[0], i_trigger};
    wire w_trig_rise = r_trig_sync[0] & ~r_trig_sync[1];

    reg [31:0] r_lfsr;
    wire       w_fb = r_lfsr[31] ^ r_lfsr[21] ^ r_lfsr[1] ^ r_lfsr[0];

    always @(posedge i_osc) begin
        if (w_trig_rise)
            r_lfsr <= (r_free_ctr == 0) ? 32'h12345678 : r_free_ctr;
        else
            r_lfsr <= {r_lfsr[30:0], w_fb};
    end

    reg [28:0] r_delay;  //for 50MHz
    reg        r_running;
    reg        r_led;

    always @(posedge i_osc) begin
        if (w_trig_rise) begin
            r_delay <= r_lfsr[28:0] % 29'd275_000_000; // 0 to ~5-6s @ 50MHz
            // change above line according to delay or interval u want (5-6s looked good enuf for me)
            r_running <= 1'b1;
            r_led     <= 1'b0;
        end else if (r_running) begin
            if (r_delay == 0) begin
                r_led     <= 1'b1;
                r_running <= 1'b0;
            end else begin
                r_delay <= r_delay - 1'b1;
            end
        end
    end

    assign o_led    = r_led;
    assign o_signal = r_led;

endmodule
