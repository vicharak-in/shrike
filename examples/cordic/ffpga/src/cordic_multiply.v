// cordic_multiply.v
// Author: Yash Sharda
// Shift-and-add integer multiplier for 3-bit signed operands sign-extended to 8-bit.

module cordic_multiply (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              start,
    input  wire signed [7:0] in1,
    input  wire signed [7:0] in2,
    output reg  signed [7:0] out,
    output reg               done
);

    reg signed [7:0] x_eff;
    reg        [7:0] z;
    reg signed [7:0] y;
    reg [2:0]        i;
    reg              neg;
    reg [2:0]        state;

    localparam IDLE   = 3'd0;
    localparam LOAD   = 3'd1; 
    localparam APPROX = 3'd2;
    localparam DONE   = 3'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out   <= 8'sd0;
            done  <= 1'b0;
            i     <= 3'd0;
            neg   <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start)
                        state <= LOAD;
                end

                LOAD: begin
                
                    neg   <= in1[7] ^ in2[7];
                    x_eff <= in1[7] ? -in1 : in1;
                    z     <= in2[7] ? -in2 : in2;
                    y     <= 8'sd0;
                    i     <= 3'd0;
                    state <= APPROX;
                end

                APPROX: begin
                    if (z[0] == 1'b1)
                        y <= y + (x_eff << i);
                    z <= z >> 1;
                    if (i == 3'd2)
                        state <= DONE;
                    else
                        i <= i + 3'd1;
                end

                DONE: begin
                    done  <= 1'b1;
                    out   <= neg ? -y : y;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
