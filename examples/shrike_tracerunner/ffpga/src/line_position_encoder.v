/*
 * Module: line_position_encoder.v
 * Description: Combinational weighted centroid line position encoder for 8-channel IR sensor.
 * Target: Renesas ForgeFPGA SLG47910
 *
 * Input: 8-bit sensor vector [S7..S0], where 1 = line detected (black line on white ground).
 * Output: Signed 8-bit position error e in range [-7, +7].
 *         e = 0: Center alignment (S3, S4)
 *         e < 0: Line is to the left
 *         e > 0: Line is to the right
 *         line_lost: 1 if all sensors are 0
 *         last_dir: 0 = last seen left, 1 = last seen right
 */

`timescale 1ns / 1ps

module line_position_encoder (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] sensor_bits,
    output reg  [7:0] error_out,       // Signed 8-bit error (-7 to +7)
    output reg        line_lost,       // 1 if no line detected
    output reg        last_dir         // 0 = Left, 1 = Right
);

    wire [7:0] s = sensor_bits;

    // Combinational line centroid calculation
    always @(*) begin
        case (s)
            // Single sensor hits
            8'b0000_0001: error_out = 8'sh07; // Far right
            8'b0000_0010: error_out = 8'sh05;
            8'b0000_0100: error_out = 8'sh03;
            8'b0000_1000: error_out = 8'sh01; // Right center
            8'b0001_0000: error_out = -8'sh01; // Left center
            8'b0010_0000: error_out = -8'sh03;
            8'b0100_0000: error_out = -8'sh05;
            8'b1000_0000: error_out = -8'sh07; // Far left

            // Dual sensor hits (interpolated centers)
            8'b0001_1000: error_out = 8'sh00; // Perfect Dead Center
            8'b0000_1100: error_out = 8'sh02;
            8'b0000_0110: error_out = 8'sh04;
            8'b0000_0011: error_out = 8'sh06;
            8'b0011_0000: error_out = -8'sh02;
            8'b0110_0000: error_out = -8'sh04;
            8'b1100_0000: error_out = -8'sh06;

            // Triple sensor hits (wide line / acute angle)
            8'b0011_1000: error_out = -8'sh01;
            8'b0001_1100: error_out = 8'sh01;
            8'b0111_0000: error_out = -8'sh03;
            8'b0000_1110: error_out = 8'sh03;
            8'b1110_0000: error_out = -8'sh05;
            8'b0000_0111: error_out = 8'sh05;

            // All zero: Line lost
            8'b0000_0000: error_out = 8'sh00;

            // Default: weighted centroid approximation for irregular reflections
            default: begin
                if (s[7] | s[6])
                    error_out = -8'sh06;
                else if (s[0] | s[1])
                    error_out = 8'sh06;
                else if (s[5] | s[4])
                    error_out = -8'sh02;
                else
                    error_out = 8'sh02;
            end
        endcase
    end

    // Sequential line lost detection and memory of last known direction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            line_lost <= 1'b0;
            last_dir  <= 1'b0;
        end else begin
            if (s == 8'b0000_0000) begin
                line_lost <= 1'b1;
            end else begin
                line_lost <= 1'b0;
                // If line was to the right (positive error), remember right
                if ($signed(error_out) > 0)
                    last_dir <= 1'b1;
                // If line was to the left (negative error), remember left
                else if ($signed(error_out) < 0)
                    last_dir <= 1'b0;
            end
        end
    end

endmodule
