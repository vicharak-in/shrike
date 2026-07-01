// cordic_divide.v
// Author: Yash Sharda
// CORDIC linear vectoring mode: computes in_y / in_x using shift-and-subtract.
// Output is Q1.6 fixed point. If the accumulated result overshoots into negative, it is corrected to its absolute value

module cordic_divide (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              start,
    input  wire signed [7:0] in_y,  // numerator
    input  wire signed [7:0] in_x,  // denominator
    output reg  signed [7:0] out_z, // quotient result
    output reg               done
);

    reg signed [7:0] x;
    reg signed [7:0] y;
    reg signed [7:0] z;
    reg [2:0]        i;
    reg [1:0]        state;

    localparam IDLE  = 2'd0;
    localparam APPROX = 2'd1;
    localparam DONE  = 2'd2;

    // Q1.6 representation of 1.0
    localparam signed [7:0] ONE = 8'sd64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_z <= 8'sd0;
            done  <= 1'b0;
            i     <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x     <= in_x;
                        y     <= in_y;
                        z     <= 8'sd0;
                        i     <= 3'd0;
                        state <= APPROX;
                    end
                end

                APPROX: begin
                    if (y[7] == 1'b0) begin
                        y <= y - (x >>> i);
                        z <= z + (ONE >>> i);
                    end else begin
                        y <= y + (x >>> i);
                        z <= z - (ONE >>> i);
                    end

                    // 6 iterations are sufficient for Q1.6 precision
                    if (i == 3'd5) begin
                        state <= DONE;
                    end else begin
                        i <= i + 3'd1;
                    end
                end

                DONE: begin
                    done  <= 1'b1;
                    state <= IDLE;
                    // Correct for sign overshoot: take absolute value if result went negative
                    if (z[7] == 1'b1) begin
                        out_z <= -z;
                    end else begin
                        out_z <= z;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
