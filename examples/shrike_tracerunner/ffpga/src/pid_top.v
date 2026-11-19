`timescale 1ns / 1ps

/*
 * Module: pid_top.v
 * Complete FPGA PID Pipeline for Renesas ForgeFPGA SLG47910
 * Optimized for 360-Degree Continuous Rotation Servos:
 *   - 2-Stage Pipelined PID for High-Frequency Timing Closure (>70 MHz)
 *   - Synchronous SPI target (Mode 0) with parity verification and telemetry
 *   - Line-position decoding (8 IR bitmask to signed error [-7..+7] + line loss)
 *   - Anti-windup integral clamp [-63..+63] & steering saturation [-100..+100]
 *   - 50 Hz RC Servo Engine (1000 us - 2000 us, 1500 us neutral stop)
 *   - Hardware differential mixer with mirrored right-channel drive
 *   - True-Silence Disarm Mode (0V idle to prevent servo creep/jitter)
 *   - 50 ms hardware SPI watchdog timeout and fail-safe motor shutdown
 */

(* top *) module pid_top (
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) input  rst_n,

    // SPI Interconnect to ESP32-S3
    (* iopad_external_pin *) input  spi_ss_n,
    (* iopad_external_pin *) input  spi_sck,
    (* iopad_external_pin *) input  spi_mosi,
    (* iopad_external_pin *) output spi_miso,
    (* iopad_external_pin *) output spi_miso_en,

    // 50 Hz RC Servo Motor Outputs
    (* iopad_external_pin *) output pwm_left_out,
    (* iopad_external_pin *) output pwm_left_oe,
    (* iopad_external_pin *) output pwm_right_out,
    (* iopad_external_pin *) output pwm_right_oe,
    (* iopad_external_pin *) output motor_en_out,
    (* iopad_external_pin *) output motor_en_oe,

    // FPGA Onboard User LED
    (* iopad_external_pin *) output led,
    (* iopad_external_pin *) output led_en
);

    assign clk_en       = 1'b1;
    assign led_en       = 1'b1;
    assign pwm_left_oe  = 1'b1;
    assign pwm_right_oe = 1'b1;
    assign motor_en_oe  = 1'b1;

    // Power-on reset (8-bit counter = 256 clock cycles)
    reg [7:0] rst_cnt = 8'd0;
    reg       internal_rst_n = 1'b0;
    always @(posedge clk) begin
        if (rst_cnt == 8'hFF) internal_rst_n <= (rst_n !== 1'b0);
        else begin
            rst_cnt <= rst_cnt + 1'b1;
            internal_rst_n <= 1'b0;
        end
    end

    // Master 1 kHz prescaler (50,000 cycles at 50 MHz = 1 ms)
    reg [15:0] tick_cnt = 16'd0;
    reg        tick_1ms = 1'b0;
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            tick_cnt <= 16'd0;
            tick_1ms <= 1'b0;
        end else if (tick_cnt >= 16'd49999) begin
            tick_cnt <= 16'd0;
            tick_1ms <= 1'b1;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
            tick_1ms <= 1'b0;
        end
    end

    // Heartbeat LED (500 ms toggle)
    reg [8:0] hb_cnt = 9'd0;
    reg       hb_led = 1'b0;
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            hb_cnt <= 9'd0;
            hb_led <= 1'b0;
        end else if (tick_1ms) begin
            if (hb_cnt >= 9'd499) begin
                hb_cnt <= 9'd0;
                hb_led <= ~hb_led;
            end else hb_cnt <= hb_cnt + 1'b1;
        end
    end

    // -------------------------------------------------------------
    // Synchronous SPI Target (Mode 0: CPOL=0, CPHA=0)
    // -------------------------------------------------------------
    reg [2:0] sck_sync;
    reg [2:0] ss_sync;
    reg [1:0] mosi_sync;
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            sck_sync  <= 3'b000;
            ss_sync   <= 3'b111;
            mosi_sync <= 2'b00;
        end else begin
            sck_sync  <= {sck_sync[1:0], spi_sck};
            ss_sync   <= {ss_sync[1:0], spi_ss_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};
        end
    end

    wire sck_rising  = (sck_sync[2:1] == 2'b01);
    wire sck_falling = (sck_sync[2:1] == 2'b10);
    wire ss_active   = ~ss_sync[1];
    wire ss_falling  = (ss_sync[2:1] == 2'b10);
    wire ss_rising   = (ss_sync[2:1] == 2'b01);

    reg [2:0] bit_idx;
    reg [7:0] rx_shift;
    reg [7:0] rx_byte;
    reg       rx_byte_valid;
    reg [7:0] tx_shift;

    assign spi_miso    = tx_shift[7];
    assign spi_miso_en = ss_active;

    // Telemetry registers (returned over SPI)
    reg [7:0] telem_status;
    reg [7:0] telem_pwml;
    reg [7:0] telem_pwmr;
    reg [7:0] telem_err;

    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            bit_idx       <= 3'd7;
            rx_shift      <= 8'd0;
            rx_byte       <= 8'd0;
            rx_byte_valid <= 1'b0;
            tx_shift      <= 8'd0;
        end else if (ss_falling) begin
            bit_idx       <= 3'd7;
            rx_byte_valid <= 1'b0;
            tx_shift      <= telem_status;
        end else if (ss_active) begin
            rx_byte_valid <= 1'b0;
            if (sck_rising) begin
                rx_shift <= {rx_shift[6:0], mosi_sync[1]};
                if (bit_idx == 3'd0) begin
                    rx_byte       <= {rx_shift[6:0], mosi_sync[1]};
                    rx_byte_valid <= 1'b1;
                    bit_idx       <= 3'd7;
                end else bit_idx  <= bit_idx - 1'b1;
            end else if (sck_falling) begin
                if (bit_idx == 3'd7) begin
                    case (byte_idx)
                        2'd1: tx_shift <= telem_pwml;
                        2'd2: tx_shift <= telem_pwmr;
                        2'd3: tx_shift <= telem_err;
                        default: tx_shift <= 8'h00;
                    endcase
                end else begin
                    tx_shift <= {tx_shift[6:0], 1'b0};
                end
            end
        end else begin
            bit_idx       <= 3'd7;
            rx_byte_valid <= 1'b0;
        end
    end

    // -------------------------------------------------------------
    // 50 ms Watchdog Timer
    // -------------------------------------------------------------
    reg [5:0] wd_cnt = 6'd0;
    reg       wd_timeout = 1'b0;
    reg       wd_kick = 1'b0;

    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            wd_cnt     <= 6'd0;
            wd_timeout <= 1'b0;
        end else if (wd_kick) begin
            wd_cnt     <= 6'd0;
            wd_timeout <= 1'b0;
        end else if (tick_1ms) begin
            if (wd_cnt >= 6'd50) wd_timeout <= 1'b1;
            else wd_cnt <= wd_cnt + 1'b1;
        end
    end

    // -------------------------------------------------------------
    // SPI Packet Processor & Tuning Registers
    // -------------------------------------------------------------
    reg [1:0] byte_idx = 2'd0;
    reg [7:0] r_cmd = 8'd0;
    reg [7:0] r_sensor = 8'd0;
    reg [7:0] r_speed = 8'd0;
    reg       is_armed = 1'b0;
    reg       pid_step_trig = 1'b0;
    reg       parity_err = 1'b0;

    reg [5:0] kp_reg = 6'd32;
    reg [3:0] ki_reg = 4'd2;
    reg [5:0] kd_reg = 6'd48;

    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            byte_idx      <= 2'd0;
            r_cmd         <= 8'd0;
            r_sensor      <= 8'd0;
            r_speed       <= 8'd0;
            is_armed      <= 1'b0;
            pid_step_trig <= 1'b0;
            parity_err    <= 1'b0;
            wd_kick       <= 1'b0;
            kp_reg        <= 6'd32;
            ki_reg        <= 4'd2;
            kd_reg        <= 6'd48;
        end else begin
            pid_step_trig <= 1'b0;
            wd_kick       <= 1'b0;
            if (ss_falling) byte_idx <= 2'd0;

            if (rx_byte_valid) begin
                case (byte_idx)
                    2'd0: r_cmd    <= rx_byte;
                    2'd1: r_sensor <= rx_byte;
                    2'd2: r_speed  <= rx_byte;
                    2'd3: begin
                        if (rx_byte == (r_cmd ^ r_sensor ^ r_speed)) begin
                            parity_err <= 1'b0;
                            wd_kick    <= 1'b1;
                            case (r_cmd)
                                8'h00: is_armed <= 1'b0; // Disarm
                                8'h10: begin             // Run
                                    is_armed      <= (r_speed > 8'd0) && (!wd_timeout || wd_kick);
                                    pid_step_trig <= 1'b1;
                                end
                                8'h20: kp_reg <= r_sensor[5:0];
                                8'h21: ki_reg <= r_sensor[3:0];
                                8'h22: kd_reg <= r_sensor[5:0];
                                default: ;
                            endcase
                        end else begin
                            parity_err <= 1'b1;
                        end
                    end
                endcase
                byte_idx <= byte_idx + 1'b1;
            end

            // Safety shutdown on watchdog
            if (wd_timeout) is_armed <= 1'b0;
        end
    end

    // -------------------------------------------------------------
    // Line Position Decoder (8 IR inputs -> 4-bit error [-7..+7])
    // -------------------------------------------------------------
    reg signed [3:0] dec_err;
    reg              dec_lost;
    wire signed [6:0] dec_err_7b = {{3{dec_err[3]}}, dec_err};

    always @(*) begin
        case (r_sensor)
            8'b00011000: begin dec_err = 4'sd0;  dec_lost = 1'b0; end
            8'b00010000: begin dec_err = -4'sd1; dec_lost = 1'b0; end
            8'b00001000: begin dec_err = 4'sd1;  dec_lost = 1'b0; end
            8'b00110000: begin dec_err = -4'sd2; dec_lost = 1'b0; end
            8'b00001100: begin dec_err = 4'sd2;  dec_lost = 1'b0; end
            8'b00100000: begin dec_err = -4'sd3; dec_lost = 1'b0; end
            8'b00000100: begin dec_err = 4'sd3;  dec_lost = 1'b0; end
            8'b01100000: begin dec_err = -4'sd4; dec_lost = 1'b0; end
            8'b00000110: begin dec_err = 4'sd4;  dec_lost = 1'b0; end
            8'b01000000: begin dec_err = -4'sd5; dec_lost = 1'b0; end
            8'b00000010: begin dec_err = 4'sd5;  dec_lost = 1'b0; end
            8'b11000000: begin dec_err = -4'sd6; dec_lost = 1'b0; end
            8'b00000011: begin dec_err = 4'sd6;  dec_lost = 1'b0; end
            8'b10000000: begin dec_err = -4'sd7; dec_lost = 1'b0; end
            8'b00000001: begin dec_err = 4'sd7;  dec_lost = 1'b0; end
            8'b00000000: begin dec_err = 4'sd0;  dec_lost = 1'b1; end
            default: begin
                if (r_sensor[7:6] != 2'b00)      begin dec_err = -4'sd6; dec_lost = 1'b0; end
                else if (r_sensor[1:0] != 2'b00) begin dec_err = 4'sd6;  dec_lost = 1'b0; end
                else if (r_sensor[5:4] != 2'b00) begin dec_err = -4'sd2; dec_lost = 1'b0; end
                else if (r_sensor[3:2] != 2'b00) begin dec_err = 4'sd2;  dec_lost = 1'b0; end
                else                             begin dec_err = 4'sd0;  dec_lost = 1'b1; end
            end
        endcase
    end

    // -------------------------------------------------------------
    // PIPELINE STAGE 1: Error, Delta, Anti-Windup Accumulator
    // Breaks the long combinational multiplier/adder path!
    // -------------------------------------------------------------
    reg signed [3:0] prev_err = 4'sd0;
    reg signed [6:0] i_acc = 7'sd0;
    reg              last_dir = 1'b0; // 0=L, 1=R
    reg              pipe_valid = 1'b0;

    reg signed [3:0] pipe1_err;
    reg signed [4:0] pipe1_delta_e;
    reg signed [6:0] pipe1_i_acc;
    reg              pipe1_lost;
    reg [7:0]        pipe1_speed;

    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            prev_err      <= 4'sd0;
            i_acc         <= 7'sd0;
            last_dir      <= 1'b0;
            pipe_valid    <= 1'b0;
            pipe1_err     <= 4'sd0;
            pipe1_delta_e <= 5'sd0;
            pipe1_i_acc   <= 7'sd0;
            pipe1_lost    <= 1'b1;
            pipe1_speed   <= 8'd0;
        end else if (pid_step_trig) begin
            pipe_valid    <= 1'b1;
            pipe1_err     <= dec_err;
            pipe1_delta_e <= dec_err - prev_err;
            pipe1_lost    <= dec_lost;
            pipe1_speed   <= r_speed;

            if (!dec_lost) begin
                prev_err <= dec_err;
                if (dec_err > 4'sd0) last_dir <= 1'b1;
                else if (dec_err < 4'sd0) last_dir <= 1'b0;

                // Anti-windup clamp [-63, +63]
                if ((i_acc + dec_err_7b) > 7'sd63) begin
                    i_acc       <= 7'sd63;
                    pipe1_i_acc <= 7'sd63;
                end else if ((i_acc + dec_err_7b) < -7'sd63) begin
                    i_acc       <= -7'sd63;
                    pipe1_i_acc <= -7'sd63;
                end else begin
                    i_acc       <= i_acc + dec_err_7b;
                    pipe1_i_acc <= i_acc + dec_err_7b;
                end
            end else begin
                pipe1_i_acc <= i_acc;
            end
        end else begin
            pipe_valid <= 1'b0;
        end
    end

    // -------------------------------------------------------------
    // PIPELINE STAGE 2: Multipliers, PID Sum, Differential Mixer
    // -------------------------------------------------------------
    wire signed [10:0] p_term = pipe1_err * $signed({1'b0, kp_reg});
    wire signed [11:0] d_term = pipe1_delta_e * $signed({1'b0, kd_reg});
    wire signed [11:0] i_term = (pipe1_i_acc * $signed({1'b0, ki_reg})) >>> 2;

    wire signed [11:0] pid_total  = p_term + d_term + i_term;
    wire signed [7:0]  pid_scaled = pid_total[11:4];

    // Clamped steer [-100..+100]
    wire signed [7:0] steer_clamped = (pid_scaled > 8'sd100) ? 8'sd100 :
                                      (pid_scaled < -8'sd100) ? -8'sd100 : pid_scaled;

    // Differential mixer intermediate duties (0..255)
    wire signed [8:0] mix_l = $signed({1'b0, pipe1_speed}) - steer_clamped;
    wire signed [8:0] mix_r = $signed({1'b0, pipe1_speed}) + steer_clamped;

    wire [7:0] duty_l_raw = (mix_l < 9'sd0) ? 8'd0 : (mix_l > 9'sd255) ? 8'd255 : mix_l[7:0];
    wire [7:0] duty_r_raw = (mix_r < 9'sd0) ? 8'd0 : (mix_r > 9'sd255) ? 8'd255 : mix_r[7:0];

    // Target servo pulse widths (1000 us to 2000 us, 1500 us neutral)
    reg [11:0] target_pulse_l = 12'd0;
    reg [11:0] target_pulse_r = 12'd0;
    reg [7:0]  active_duty_l  = 8'd0;
    reg [7:0]  active_duty_r  = 8'd0;
    reg        steer_sat      = 1'b0;

    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            target_pulse_l <= 12'd0;
            target_pulse_r <= 12'd0;
            active_duty_l  <= 8'd0;
            active_duty_r  <= 8'd0;
            steer_sat      <= 1'b0;
            telem_status   <= 8'h01;
            telem_pwml     <= 8'd0;
            telem_pwmr     <= 8'd0;
            telem_err      <= 8'd0;
        end else if (!is_armed) begin
            target_pulse_l <= 12'd0;
            target_pulse_r <= 12'd0;
            active_duty_l  <= 8'd0;
            active_duty_r  <= 8'd0;
            telem_pwml     <= 8'd0;
            telem_pwmr     <= 8'd0;
            telem_status[1] <= 1'b0;
        end else if (pipe_valid) begin
            steer_sat <= (pid_scaled > 8'sd100) || (pid_scaled < -8'sd100);

            if (pipe1_speed == 8'd0) begin
                // Silence mode: 0 us pulse width (0V DC)
                target_pulse_l <= 12'd0;
                target_pulse_r <= 12'd0;
                active_duty_l  <= 8'd0;
                active_duty_r  <= 8'd0;
                telem_pwml     <= 8'd0;
                telem_pwmr     <= 8'd0;
            end else if (pipe1_lost) begin
                // Pivot recovery toward last known line direction
                if (last_dir) begin
                    // Spin turn Right: Left drives forward, Right stopped
                    target_pulse_l <= 12'd1500 + 12'd120; // 1620 us
                    target_pulse_r <= 12'd1500;            // 1500 us neutral stop
                    active_duty_l  <= 8'd60;
                    active_duty_r  <= 8'd0;
                    telem_pwml     <= 8'd60;
                    telem_pwmr     <= 8'd0;
                end else begin
                    // Spin turn Left: Left stopped, Right drives forward (mirrored: 1500 - 120 = 1380 us)
                    target_pulse_l <= 12'd1500;            // 1500 us neutral stop
                    target_pulse_r <= 12'd1500 - 12'd120; // 1380 us
                    active_duty_l  <= 8'd0;
                    active_duty_r  <= 8'd60;
                    telem_pwml     <= 8'd0;
                    telem_pwmr     <= 8'd60;
                end
            end else begin
                // Forward Differential Drive with Right Wheel Mirroring:
                // Left Servo:  1500 + duty_l (Forward is > 1500 us)
                // Right Servo: 1500 - duty_r (Forward is < 1500 us due to opposite motor mount)
                // Multiplier x2 maps 0..250 duty to +/- 500 us (1000 us .. 2000 us range)
                target_pulse_l <= 12'd1500 + {3'b000, duty_l_raw, 1'b0};
                target_pulse_r <= 12'd1500 - {3'b000, duty_r_raw, 1'b0};
                active_duty_l  <= duty_l_raw;
                active_duty_r  <= duty_r_raw;
                telem_pwml     <= duty_l_raw;
                telem_pwmr     <= duty_r_raw;
            end

            // Update Telemetry packet registers
            telem_status <= {hb_led, pipe1_lost, (i_acc == 7'sd63 || i_acc == -7'sd63),
                             steer_sat, parity_err, last_dir, is_armed, 1'b1};
            telem_err    <= {{4{pipe1_err[3]}}, pipe1_err};
        end
    end

    // -------------------------------------------------------------
    // 50 Hz RC Servo Engine (20,000 us frame, 1000..2000 us high)
    // -------------------------------------------------------------
    // 1 us microsecond generator (50 MHz / 50 = 1 MHz)
    reg [5:0] us_div = 6'd0;
    reg       tick_us = 1'b0;

    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            us_div  <= 6'd0;
            tick_us <= 1'b0;
        end else if (us_div >= 6'd49) begin
            us_div  <= 6'd0;
            tick_us <= 1'b1;
        end else begin
            us_div  <= us_div + 1'b1;
            tick_us <= 1'b0;
        end
    end

    // 20 ms (20,000 us) Frame Counter
    reg [14:0] frame_cnt = 15'd0;

    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            frame_cnt <= 15'd0;
        end else if (tick_us) begin
            if (frame_cnt >= 15'd19999) frame_cnt <= 15'd0;
            else frame_cnt <= frame_cnt + 1'b1;
        end
    end

    // Continuous Servo Pulse Outputs with Zero-Creep Silence
    assign pwm_left_out  = is_armed && (target_pulse_l > 12'd0) && (frame_cnt < {3'b000, target_pulse_l});
    assign pwm_right_out = is_armed && (target_pulse_r > 12'd0) && (frame_cnt < {3'b000, target_pulse_r});
    assign motor_en_out  = is_armed && !wd_timeout;
    assign led           = hb_led;

endmodule
