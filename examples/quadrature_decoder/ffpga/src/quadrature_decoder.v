module quadrature_decoder #(
    parameter WIDTH        = 16,
    parameter CLK_FREQ     = 50_000_000,
    parameter UPDATE_MS    = 500,        // update every time at this value
    parameter CPR          = 4000        // counts per revolution (4x decoding)
)(
    input                           clk,
    input                           rst,

    input                           enc_a,
    input                           enc_b,

    output reg  signed [WIDTH-1:0]  position,
    output reg  signed [WIDTH-1:0]  speed,
    output reg  [WIDTH-1:0]         angle,
    output reg                      direction,
    output reg                      data_valid
);

/* Synchronization of input pulses */
reg [1:0] sync_a, sync_b;

always @(posedge clk) begin
    if (rst) begin
        sync_a <= 0;
        sync_b <= 0;
    end else begin
        sync_a <= {sync_a[0], enc_a};
        sync_b <= {sync_b[0], enc_b};
    end
end

/* Logic to track the State */
reg [1:0] prev, curr;

always @(posedge clk) begin
    if (rst) begin
        prev <= 0;
        curr <= 0;
    end else begin
        prev <= curr;
        curr <= {sync_a[1], sync_b[1]};
    end
end

/* Logic to determine Position and Direction */
reg step_pulse;

always @(posedge clk) begin
    if (rst) begin
        position   <= 0;
        direction  <= 0;
        step_pulse <= 0;
    end else begin
        step_pulse <= 0;

        case ({prev, curr})
            // Forward
            4'b0001,4'b0111,4'b1110,4'b1000: begin
                position   <= position + 1;
                direction  <= 1;
                step_pulse <= 1;
            end

            // Reverse
            4'b0010,4'b0100,4'b1101,4'b1011: begin
                position   <= position - 1;
                direction  <= 0;
                step_pulse <= 1;
            end
        endcase
    end
end

/* Speed calculation (configurable window) */
reg signed [WIDTH-1:0] step_count;

localparam TIMER_MAX = (CLK_FREQ / 1000) * UPDATE_MS;

reg [31:0] timer_cnt;
wire tick = (timer_cnt == TIMER_MAX - 1);

always @(posedge clk) begin
    if (rst) begin
        timer_cnt  <= 0;
        step_count <= 0;
        speed      <= 0;
        data_valid <= 0;
    end else begin
        data_valid <= 0;
        timer_cnt <= (tick) ? 0 : timer_cnt + 1;

        if (step_pulse) begin
            if (direction)
                step_count <= step_count + 1;
            else
                step_count <= step_count - 1;
        end

        if (tick) begin
            // normalize to steps/sec
            speed      <= (step_count * (1000 / UPDATE_MS));
            step_count <= 0;
            data_valid <= 1;
        end
    end
end

/* 5. Angle Calculation */
reg [31:0] angle_cnt;

always @(posedge clk) begin
    if (rst) begin
        angle_cnt <= 0;
    end else if (step_pulse) begin
        if (direction) begin
            if (angle_cnt == CPR-1)
                angle_cnt <= 0;
            else
                angle_cnt <= angle_cnt + 1;
        end else begin
            if (angle_cnt == 0)
                angle_cnt <= CPR-1;
            else
                angle_cnt <= angle_cnt - 1;
        end
    end
end

always @(posedge clk) begin
    angle <= angle_cnt[15:0];
end

endmodule