module quadrant(

    input  wire signed [31:0] angle_in,

    output reg  signed [15:0] cordic_angle,

    output reg  sin_neg,
    output reg  cos_neg

);

localparam signed [31:0] PI_Q14        = 32'sd51471;
localparam signed [31:0] HALF_PI_Q14   = 32'sd25735;
localparam signed [31:0] THREE_HALF_PI = 32'sd77206;
localparam signed [31:0] TWO_PI_Q14    = 32'sd102943;

reg signed [31:0] angle_norm;
reg signed [31:0] angle_red;

always @(*) begin

    // Defaults
    angle_norm   = angle_in;
    angle_red    = 32'sd0;

    cordic_angle = 16'sd0;
    sin_neg      = 1'b0;
    cos_neg      = 1'b0;


angle_norm = angle_in;

if(angle_norm >= TWO_PI_Q14)
    angle_norm = angle_norm - TWO_PI_Q14;

    // Quadrant I : 0° - 90°
    if(angle_norm <= HALF_PI_Q14) begin

        angle_red = angle_norm;

        sin_neg = 1'b0;
        cos_neg = 1'b0;

    end

    // Quadrant II : 90° - 180°
    else if(angle_norm <= PI_Q14) begin

        angle_red = PI_Q14 - angle_norm;

        sin_neg = 1'b0;
        cos_neg = 1'b1;

    end

    // Quadrant III : 180° - 270°
    else if(angle_norm <= THREE_HALF_PI) begin

        angle_red = angle_norm - PI_Q14;

        sin_neg = 1'b1;
        cos_neg = 1'b1;

    end

    // Quadrant IV : 270° - 360°
    else begin

        angle_red = TWO_PI_Q14 - angle_norm;

        sin_neg = 1'b1;
        cos_neg = 1'b0;

    end

    cordic_angle = angle_red[15:0];

end

endmodule



