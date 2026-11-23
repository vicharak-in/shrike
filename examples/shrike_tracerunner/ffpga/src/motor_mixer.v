/*
 * Module: motor_mixer.v
 * Description: Differential drive motor mixer with line-loss recovery.
 * Target: Renesas ForgeFPGA SLG47910
 *
 * Mixing Equations:
 *   PWM_Left  = clamp(BaseSpeed - Steering, 0, 255)
 *   PWM_Right = clamp(BaseSpeed + Steering, 0, 255)
 *
 * Line Loss Recovery:
 *   If line_lost is asserted and BaseSpeed > 0, execute pivot search toward last_dir:
 *     last_dir = 0 (Left):  PWM_Left = 0,            PWM_Right = SearchSpeed
 *     last_dir = 1 (Right): PWM_Left = SearchSpeed,  PWM_Right = 0
 *   If BaseSpeed == 0, both motors remain stopped (safety interlock).
 */

`timescale 1ns / 1ps

module motor_mixer #(
    parameter SEARCH_SPEED = 8'd60      // Gentle spin turn speed when line lost
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  base_speed,
    input  wire signed [7:0] steer_in,  // Signed steering correction [-127, +127]
    input  wire        line_lost,
    input  wire        last_dir,        // 0 = Left, 1 = Right
    output reg  [7:0]  pwm_left,
    output reg  [7:0]  pwm_right
);

    wire signed [9:0] w_base_ext  = {2'b00, base_speed};
    wire signed [9:0] w_steer_ext = {{2{steer_in[7]}}, steer_in};

    // Ideal mixed values (10-bit signed)
    wire signed [9:0] w_mix_left  = w_base_ext - w_steer_ext;
    wire signed [9:0] w_mix_right = w_base_ext + w_steer_ext;

    // Clamping logic for Left
    wire [7:0] w_clamped_left = (w_mix_left < 10'sd0)   ? 8'd0 :
                                (w_mix_left > 10'sd255) ? 8'd255 :
                                 w_mix_left[7:0];

    // Clamping logic for Right
    wire [7:0] w_clamped_right = (w_mix_right < 10'sd0)   ? 8'd0 :
                                 (w_mix_right > 10'sd255) ? 8'd255 :
                                  w_mix_right[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_left  <= 8'd0;
            pwm_right <= 8'd0;
        end else begin
            if (base_speed == 8'd0) begin
                // Safe stop: zero forward drive suppresses all motor activity
                pwm_left  <= 8'd0;
                pwm_right <= 8'd0;
            end else if (line_lost) begin
                // Search recovery: pivot toward the direction where line was last detected
                if (last_dir == 1'b0) begin
                    pwm_left  <= 8'd0;
                    pwm_right <= SEARCH_SPEED;
                end else begin
                    pwm_left  <= SEARCH_SPEED;
                    pwm_right <= 8'd0;
                end
            end else begin
                pwm_left  <= w_clamped_left;
                pwm_right <= w_clamped_right;
            end
        end
    end

endmodule
