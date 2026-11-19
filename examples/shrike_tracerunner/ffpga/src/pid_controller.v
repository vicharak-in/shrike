/*
 * Module: pid_controller.v
 * Description: Synthesizable deterministic fixed-point PID controller.
 * Target: Renesas ForgeFPGA SLG47910
 *
 * Arithmetic specifications:
 * - Error input: Signed 8-bit [-128, +127]
 * - Gains: Kp (8-bit unsigned), Ki (8-bit unsigned), Kd (8-bit unsigned)
 * - P term: 16-bit signed
 * - I term: 16-bit signed with anti-windup clamping to [-IMAX, +IMAX]
 * - D term: 16-bit signed from backward difference (e - e_prev)
 * - Steering Output: Signed 8-bit [-127, +127]
 */

`timescale 1ns / 1ps

module pid_controller #(
    parameter SCALE_SHIFT = 4,         // Division by 16 for gain scaling
    parameter IMAX = 16'sh01FF          // Integral clamp: +/- 511
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,    // Pulse to compute next PID step
    input  wire signed [7:0] error_in, // Line position error
    input  wire        line_lost,      // 1 if line lost
    input  wire [7:0]  kp,             // Proportional gain
    input  wire [7:0]  ki,             // Integral gain
    input  wire [7:0]  kd,             // Derivative gain

    output reg  signed [7:0] steer_out,// Steering correction [-127, +127]
    output reg         inter_sat,      // Integral anti-windup active flag
    output reg         steer_sat       // Steering saturation active flag
);

    // Internal state registers
    reg signed [7:0]  r_error_prev;
    reg signed [15:0] r_integral_acc;

    // Intermediate calculation wires
    wire signed [15:0] w_error_ext = {{8{error_in[7]}}, error_in};
    wire signed [15:0] w_kp_ext    = {8'b0, kp};
    wire signed [15:0] w_ki_ext    = {8'b0, ki};
    wire signed [15:0] w_kd_ext    = {8'b0, kd};

    // P term: Kp * error
    wire signed [15:0] w_p_term = w_error_ext * w_kp_ext;

    // D term: Kd * (error - error_prev)
    wire signed [7:0]  w_delta_e = error_in - r_error_prev;
    wire signed [15:0] w_d_term  = {{8{w_delta_e[7]}}, w_delta_e} * w_kd_ext;

    // Integral calculation with anti-windup
    wire signed [15:0] w_acc_next = r_integral_acc + w_error_ext;
    wire signed [15:0] w_i_term   = (r_integral_acc * w_ki_ext) >>> 4;

    // Total PID sum (unscaled)
    wire signed [15:0] w_pid_sum = w_p_term + w_i_term + w_d_term;

    // Scaled output
    wire signed [15:0] w_pid_scaled = w_pid_sum >>> SCALE_SHIFT;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_error_prev    <= 8'sh00;
            r_integral_acc  <= 16'sh0000;
            steer_out       <= 8'sh00;
            inter_sat       <= 1'b0;
            steer_sat       <= 1'b0;
        end else if (sample_tick) begin
            // 1. Update Error Memory
            r_error_prev <= error_in;

            // 2. Integral accumulation with Anti-Windup clamp
            if (line_lost) begin
                // Freeze integral accumulation during line loss
                r_integral_acc <= r_integral_acc;
                inter_sat      <= 1'b0;
            end else if (w_acc_next > IMAX) begin
                r_integral_acc <= IMAX;
                inter_sat      <= 1'b1;
            end else if (w_acc_next < -IMAX) begin
                r_integral_acc <= -IMAX;
                inter_sat      <= 1'b1;
            end else begin
                r_integral_acc <= w_acc_next;
                inter_sat      <= 1'b0;
            end

            // 3. Output Saturation to [-127, +127]
            if (w_pid_scaled > 16'sh007F) begin
                steer_out <= 8'sh7F; // +127
                steer_sat <= 1'b1;
            end else if (w_pid_scaled < -16'sh007F) begin
                steer_out <= -8'sh7F; // -127
                steer_sat <= 1'b1;
            end else begin
                steer_out <= w_pid_scaled[7:0];
                steer_sat <= 1'b0;
            end
        end
    end

endmodule
