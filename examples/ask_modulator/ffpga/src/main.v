// --- START GUARD ---
`ifndef DDS_ASK_MODULATOR_H
`define DDS_ASK_MODULATOR_H

// Shrike-lite FPGA DDS
(* top *)
module dds_ask_modulator (
    (* iopad_external_pin *) input  wire [5:0] i_freq_word, 
    (* iopad_external_pin *) input  wire       i_data,      
    (* iopad_external_pin, clkbuf_inhibit *) input  wire       i_clk,       
    
    (* iopad_external_pin *) output wire       o_pwm_out,
    (* iopad_external_pin *) output wire       o_pwm_out_oe,
    (* iopad_external_pin *) output wire       o_clk_en
);

    assign o_clk_en = 1'b1;
    assign o_pwm_out_oe = 1'b1;

    // 16-bit Accumulator
    reg [15:0] phase_acc = 16'd0;
    
    always @(posedge i_clk) begin
        if (i_data) begin
            phase_acc <= phase_acc + {8'b0, i_freq_word, 2'b0}; 
        end else begin
            phase_acc <= 0; 
        end
    end

    // LUT
    wire [5:0] lut_addr = phase_acc[15:10];
    reg  [5:0] sine_amplitude;

    always @(*) begin
        case(lut_addr)
            // 0-90 deg
            6'd0 : sine_amplitude = 6'd32; 6'd1 : sine_amplitude = 6'd35;
            6'd2 : sine_amplitude = 6'd38; 6'd3 : sine_amplitude = 6'd41;
            6'd4 : sine_amplitude = 6'd44; 6'd5 : sine_amplitude = 6'd47;
            6'd6 : sine_amplitude = 6'd49; 6'd7 : sine_amplitude = 6'd52;
            6'd8 : sine_amplitude = 6'd54; 6'd9 : sine_amplitude = 6'd56;
            6'd10: sine_amplitude = 6'd58; 6'd11: sine_amplitude = 6'd59;
            6'd12: sine_amplitude = 6'd61; 6'd13: sine_amplitude = 6'd62;
            6'd14: sine_amplitude = 6'd63; 6'd15: sine_amplitude = 6'd63; 
            // 90-180 deg
            6'd16: sine_amplitude = 6'd63; 6'd17: sine_amplitude = 6'd62;
            6'd18: sine_amplitude = 6'd61; 6'd19: sine_amplitude = 6'd59;
            6'd20: sine_amplitude = 6'd58; 6'd21: sine_amplitude = 6'd56;
            6'd22: sine_amplitude = 6'd54; 6'd23: sine_amplitude = 6'd52;
            6'd24: sine_amplitude = 6'd49; 6'd25: sine_amplitude = 6'd47;
            6'd26: sine_amplitude = 6'd44; 6'd27: sine_amplitude = 6'd41;
            6'd28: sine_amplitude = 6'd38; 6'd29: sine_amplitude = 6'd35;
            6'd30: sine_amplitude = 6'd32; 6'd31: sine_amplitude = 6'd29;
            // 180-270 deg
            6'd32: sine_amplitude = 6'd26; 6'd33: sine_amplitude = 6'd23;
            6'd34: sine_amplitude = 6'd20; 6'd35: sine_amplitude = 6'd17;
            6'd36: sine_amplitude = 6'd14; 6'd37: sine_amplitude = 6'd12;
            6'd38: sine_amplitude = 6'd10; 6'd39: sine_amplitude = 6'd8; 
            6'd40: sine_amplitude = 6'd6;  6'd41: sine_amplitude = 6'd4; 
            6'd42: sine_amplitude = 6'd3;  6'd43: sine_amplitude = 6'd2; 
            6'd44: sine_amplitude = 6'd1;  6'd45: sine_amplitude = 6'd0; 
            6'd46: sine_amplitude = 6'd0;  6'd47: sine_amplitude = 6'd0; 
            // 270-360 deg
            6'd48: sine_amplitude = 6'd1;  6'd49: sine_amplitude = 6'd2;
            6'd50: sine_amplitude = 6'd3;  6'd51: sine_amplitude = 6'd4;
            6'd52: sine_amplitude = 6'd6;  6'd53: sine_amplitude = 6'd8;
            6'd54: sine_amplitude = 6'd10; 6'd55: sine_amplitude = 6'd12;
            6'd56: sine_amplitude = 6'd14; 6'd57: sine_amplitude = 6'd17;
            6'd58: sine_amplitude = 6'd20; 6'd59: sine_amplitude = 6'd23;
            6'd60: sine_amplitude = 6'd26; 6'd61: sine_amplitude = 6'd29;
            6'd62: sine_amplitude = 6'd31; 6'd63: sine_amplitude = 6'd32;
            default: sine_amplitude = 6'd32;
        endcase
    end

    reg [5:0] pwm_counter = 0;
    always @(posedge i_clk) begin
        pwm_counter <= pwm_counter + 1;
    end
    
    assign o_pwm_out = (sine_amplitude > pwm_counter) ? 1'b1 : 1'b0;

endmodule

`endif 
// --- END GUARD ---