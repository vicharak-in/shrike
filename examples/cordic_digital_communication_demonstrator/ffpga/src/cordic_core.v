module cordic_core(
    input  wire clk,
    input  wire rst_n,

    input  wire start,

    input  wire signed [15:0] angle_in,

    output reg signed [15:0] sin_out,
    output reg signed [15:0] cos_out,

    output reg done

);

localparam signed [9:0] K_INV = 10'sd155;   // 0.6072 * 256

reg signed [9:0] x;
reg signed [9:0] y;
reg signed [9:0] z;

reg signed [9:0] x_next;
reg signed [9:0] y_next;
reg signed [9:0] z_next;

reg [2:0] iter;      // 0..7 -> 8 iterations, matches the 8 fractional bits
reg running;

wire signed [9:0] atan_val;

atan_rom u_rom(
    .addr(iter),
    .atan_val(atan_val)
);

always @(*) begin

    if(z >= 0) begin

        x_next = x - (y >>> iter);
        y_next = y + (x >>> iter);
        z_next = z - atan_val;

    end
    else begin

        x_next = x + (y >>> iter);
        y_next = y - (x >>> iter);
        z_next = z + atan_val;

    end

end

always @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin

        x <= 0;
        y <= 0;
        z <= 0;

        iter <= 0;

        running <= 0;

        done <= 0;

        sin_out <= 0;
        cos_out <= 0;

    end
    else begin

        done <= 0;

        if(start && !running) begin

            x <= K_INV;
            y <= 0;
            // Truncate Q1.14 angle down to Q1.8 by bit-slicing (free --
            // the binary point is already aligned, no shift needed).
            z <= angle_in[15:6];

            iter <= 0;

            running <= 1'b1;

        end
        else if(running) begin

            x <= x_next;
            y <= y_next;
            z <= z_next;

            if(iter == 3'd7) begin

                running <= 1'b0;

                // Rescale Q1.8 -> Q1.14 (16-bit) on the way out: sign-extend
                // then shift left by 6 (8 frac bits -> 14 frac bits).
                sin_out <= {{6{y_next[9]}}, y_next} <<< 6;
                cos_out <= {{6{x_next[9]}}, x_next} <<< 6;

                done <= 1'b1;

            end
            else begin

                iter <= iter + 1'b1;
            end

        end

    end

end

endmodule