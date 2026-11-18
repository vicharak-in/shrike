/*
 * Module: pwm_generator.v
 * Description: Hardware PWM Generator for ForgeFPGA motor drive.
 * Generates an ultrasonic ~19.53 kHz PWM signal from 50 MHz system clock.
 *
 * Parameters:
 *  - PRESCALER = 10 : 50 MHz / 10 = 5 MHz tick
 *  - WIDTH = 8      : 8-bit resolution (0..255) -> 5 MHz / 256 = 19.531 kHz
 */

`timescale 1ns / 1ps

module pwm_generator #(
    parameter PRESCALER = 10,
    parameter WIDTH     = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             enable,
    input  wire [WIDTH-1:0] duty,
    output reg              pwm_out
);

    // Clock prescaler
    reg [3:0] prescaler_cnt;
    wire      tick = (prescaler_cnt == (PRESCALER - 1));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prescaler_cnt <= 4'd0;
        end else begin
            if (tick)
                prescaler_cnt <= 4'd0;
            else
                prescaler_cnt <= prescaler_cnt + 1'b1;
        end
    end

    // 8-bit PWM accumulator & comparator
    reg [WIDTH-1:0] pwm_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_cnt <= {WIDTH{1'b0}};
            pwm_out <= 1'b0;
        end else begin
            if (!enable) begin
                pwm_cnt <= {WIDTH{1'b0}};
                pwm_out <= 1'b0;
            end else if (tick) begin
                pwm_cnt <= pwm_cnt + 1'b1;
                pwm_out <= (pwm_cnt < duty);
            end
        end
    end

endmodule
