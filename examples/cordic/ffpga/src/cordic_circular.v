// cordic_circular.v
// Author: Yash Sharda
// CORDIC circular rotation mode: computes sin and cos for a given angle input.
// Inputs and outputs are Q1.6 fixed point. Accumulators are extended to 12-bit

module cordic_circular (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    input  wire signed [7:0]  angle_in,  // Q1.6 angle input
    output reg  signed [7:0]  cos_out,   // Q1.6 cosine result
    output reg  signed [7:0]  sin_out,   // Q1.6 sine result
    output reg                done
);

    // 12-bit accumulators 
    reg signed [11:0] x;
    reg signed [11:0] y;
    reg signed [11:0] z;
    reg [2:0]         i;
    reg [1:0]         state;

    localparam IDLE   = 2'd0;
    localparam ROTATE = 2'd1;
    localparam DONE   = 2'd2;

    // CORDIC gain constant K in Q5.6 (12-bit internal format)
    localparam signed [11:0] K = 12'sd39;

    // Precomputed atan table in Q5.6 for iterations 0 to 6
    reg signed [11:0] atan_val;
    always @(*) begin
        case (i)
            3'd0:    atan_val = 12'sd50;
            3'd1:    atan_val = 12'sd30;
            3'd2:    atan_val = 12'sd16;
            3'd3:    atan_val = 12'sd8;
            3'd4:    atan_val = 12'sd4;
            3'd5:    atan_val = 12'sd2;
            3'd6:    atan_val = 12'sd1;
            default: atan_val = 12'sd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            cos_out <= 8'sd0;
            sin_out <= 8'sd0;
            done    <= 1'b0;
            x       <= 12'sd0;
            y       <= 12'sd0;
            z       <= 12'sd0;
            i       <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x     <= K;
                        y     <= 12'sd0;
                        z     <= { {4{angle_in[7]}}, angle_in }; // sign-extend to 12-bit
                        i     <= 3'd0;
                        state <= ROTATE;
                    end
                end

                ROTATE: begin
                    if (z[11] == 1'b0) begin
                        x <= x - (y >>> i);
                        y <= y + (x >>> i);
                        z <= z - atan_val;
                    end else begin
                        x <= x + (y >>> i);
                        y <= y - (x >>> i);
                        z <= z + atan_val;
                    end

                    if (i == 3'd6) begin
                        state <= DONE;
                    end else begin
                        i <= i + 3'd1;
                    end
                end

                DONE: begin
                    cos_out <= x[7:0]; // lower 8 bits hold the Q1.6 result
                    sin_out <= y[7:0];
                    done    <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
