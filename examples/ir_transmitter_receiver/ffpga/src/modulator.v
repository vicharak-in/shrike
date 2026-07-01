// -----------------------------------------------------------------------------
// Module: ir_top
// Description: Top-level module for the IR Transmitter and Receiver.
//              Handles the communication bridge between a microcontroller 
//              (via bit-banging) and the NEC IR encoder/decoder modules.
// -----------------------------------------------------------------------------
(* top *) module ir_top (
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) input data_in,
    (* iopad_external_pin *) input clk_in,
    (* iopad_external_pin *) output reg data_out = 1'b0,
    (* iopad_external_pin *) output data_out_en,
    (* iopad_external_pin *) input tsop_in,
    (* iopad_external_pin *) output reg ir_out = 1'b0,
    (* iopad_external_pin *) output ir_out_en,
    (* iopad_external_pin *) output reg fpga_led = 1'b0,
    (* iopad_external_pin *) output fpga_led_en
);

    assign clk_en = 1'b1;
    assign ir_out_en = 1'b1;
    assign fpga_led_en = 1'b1;
    assign data_out_en = 1'b1;

    // Synchronize external clock and data signals to the internal clock domain
    reg [2:0] clk_sync = 3'b000;
    reg [2:0] data_sync = 3'b000;
    
    always @(posedge clk) begin
        clk_sync <= {clk_sync[1:0], clk_in};
        data_sync <= {data_sync[1:0], data_in};
    end
    
    wire ext_clk_rise = ~clk_sync[2] & clk_sync[1];
    wire ext_clk_fall = clk_sync[2] & ~clk_sync[1];
    wire ext_data_bit = data_sync[2];

    // LED blinking logic to indicate successful decoding
    reg [24:0] led_cnt = 25'd0;
    reg got_decode = 1'b0;
    
    always @(posedge clk) begin
        led_cnt <= led_cnt + 1;
        if (dec_valid || dec_repeat) got_decode <= 1'b1;
        if (got_decode)
            fpga_led <= 1'b1;
        else if (led_cnt == 0)
            fpga_led <= ~fpga_led;
    end

    // Shift register to read commands from the microcontroller
    reg [23:0] shift_reg = 24'd0;
    reg [4:0] bit_cnt = 5'd0;
    reg cmd_ready = 1'b0;
    reg [19:0] timeout = 20'd0;
    
    always @(posedge clk) begin
        cmd_ready <= 1'b0;
        if (ext_clk_rise) begin
            shift_reg <= {shift_reg[22:0], ext_data_bit};
            timeout <= 20'd0;
            if (bit_cnt == 5'd23) begin
                cmd_ready <= 1'b1;
                bit_cnt <= 5'd0;
            end else
                bit_cnt <= bit_cnt + 5'd1;
        end else if (timeout < 20'd500000)
            timeout <= timeout + 20'd1;
        else
            bit_cnt <= 5'd0;
    end

    // Process incoming commands from MCU
    reg [7:0] cmd_addr = 8'd0;
    reg [7:0] cmd_cmd = 8'd0;
    reg cmd_rep = 1'b0;
    reg nec_send = 1'b0;
    
    always @(posedge clk) begin
        nec_send <= 1'b0;
        if (cmd_ready && !nec_busy &&
           (shift_reg[23:16] == 8'h01 || shift_reg[23:16] == 8'h02)) begin
            cmd_rep <= (shift_reg[23:16] == 8'h02);
            cmd_addr <= shift_reg[15:8];
            cmd_cmd <= shift_reg[7:0];
            nec_send <= 1'b1;
        end
    end

    // Instantiate the NEC Encoder
    wire mod_enable, nec_busy;
    nec_encoder u_enc (
        .i_clk(clk),
        .addr(cmd_addr),
        .cmd(cmd_cmd),
        .is_repeat(cmd_rep),
        .send(nec_send),
        .mod_enable(mod_enable),
        .busy(nec_busy)
    );

    // Instantiate the 38kHz Carrier Generator
    wire carrier;
    carrier_generator u_car (
        .i_clk(clk),
        .enable(mod_enable),
        .carrier(carrier)
    );
    
    always @(posedge clk) ir_out <= carrier;

    // Instantiate the NEC Decoder
    wire [7:0] dec_addr, dec_cmd;
    wire dec_valid, dec_repeat;
    wire [2:0] dec_state;
    wire [4:0] dec_bit_idx;
    
    nec_decoder u_dec (
        .i_clk(clk),
        .tsop_in(tsop_in),
        .rx_addr(dec_addr),
        .rx_cmd(dec_cmd),
        .rx_valid(dec_valid),
        .rx_repeat(dec_repeat),
        .dbg_state(dec_state),
        .dbg_bit_idx(dec_bit_idx)
    );

    // Handle return data logic to send decoded data back to MCU
    reg [7:0] rx_status = 8'd0;
    reg [7:0] rx_addr_r = 8'd0;
    reg [7:0] rx_cmd_r = 8'd0;
    reg [4:0] rd_ptr = 5'd24; 
    reg skip_fall = 1'b0;
    
    wire [23:0] rd_frame = {rx_status, rx_addr_r, rx_cmd_r};
    wire is_tx_cmd = cmd_ready &&
                     (shift_reg[23:16] == 8'h01 || shift_reg[23:16] == 8'h02);
                     
    always @(posedge clk) begin
        if (dec_valid) begin
            rx_status <= 8'h81;
            rx_addr_r <= dec_addr;
            rx_cmd_r <= dec_cmd;
        end else if (dec_repeat && rx_status == 8'h00) begin
            rx_status <= 8'h82;
            rx_addr_r <= 8'h00;
            rx_cmd_r <= 8'h00;
        end
        
        if (is_tx_cmd) begin
            rx_status <= 8'h00;
            rd_ptr <= 5'd0;
            skip_fall <= 1'b1;
        end else if (ext_clk_fall) begin
            if (skip_fall)
                skip_fall <= 1'b0;
            else if (rd_ptr < 5'd24)
                rd_ptr <= rd_ptr + 5'd1;
        end
        
        if (rd_ptr < 5'd24)
            data_out <= rd_frame[23 - rd_ptr];
        else
            data_out <= 1'b0;
    end
    
endmodule
