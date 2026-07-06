(* top *)
module shrike_lite_top(
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) input rst_n,
    (* iopad_external_pin *) input spi_ss_n,
    (* iopad_external_pin *) input spi_sck,
    (* iopad_external_pin *) input spi_mosi,
    (* iopad_external_pin *) output spi_miso,
    (* iopad_external_pin *) output spi_miso_en,
    (* iopad_external_pin *) output reg led,
    (* iopad_external_pin *) output led_en
);

assign clk_en = 1'b1;
assign led_en = 1'b1;

wire [7:0] rx_data;
wire rx_valid;
wire tx_hold;
reg [7:0] tx_data;
reg [7:0] response_data;

reg signed [31:0] angle_reg;

reg [2:0] rx_state;
localparam IDLE  = 3'd0;
localparam BYTE0 = 3'd1;
localparam BYTE1 = 3'd2;
localparam BYTE2 = 3'd3;
localparam BYTE3 = 3'd4;

reg start;
reg done_sticky;

reg sin_neg_reg;
reg cos_neg_reg;

reg signed [15:0] sin_corrected;
reg signed [15:0] cos_corrected;

wire signed [15:0] cordic_angle;
wire sin_neg;
wire cos_neg;
reg latch_pending;

wire signed [15:0] sin_out;
wire signed [15:0] cos_out;
wire done;

// tan divider: starts one cycle after 'done' (sin_out/cos_out are already
// stable/final at that point, same timing sin_corrected/cos_corrected rely on).
wire signed [15:0] sin_true = sin_neg_reg ? -sin_out : sin_out;
reg  div_start;
wire signed [15:0] tan_out;
wire tan_done;
reg  tan_done_sticky;
reg  signed [15:0] tan_corrected;

spi_target u_spi(
    .i_clk(clk),
    .i_rst_n(rst_n),
    .i_enable(1'b1),
    .i_ss_n(spi_ss_n),
    .i_sck(spi_sck),
    .i_mosi(spi_mosi),
    .o_miso(spi_miso),
    .o_miso_oe(spi_miso_en),
    .o_rx_data(rx_data),
    .o_rx_data_valid(rx_valid),
    .i_tx_data(tx_data),
    .o_tx_data_hold(tx_hold)
);

quadrant u_quadrant(
    .angle_in(angle_reg),
    .cordic_angle(cordic_angle),
    .sin_neg(sin_neg),
    .cos_neg(cos_neg)
);

cordic_core u_cordic(
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .angle_in(cordic_angle),
    .sin_out(sin_out),
    .cos_out(cos_out),
    .done(done)
);

linear_divide u_divide(
    .clk(clk),
    .rst_n(rst_n),
    .start(div_start),
    .in_y(sin_true),
    .in_x(cos_out),
    .cos_neg(cos_neg_reg),
    .out_z(tan_out),
    .done(tan_done)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        div_start <= 1'b0;
    else
        div_start <= done;
end

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        angle_reg     <= 32'd0;
        rx_state      <= IDLE;
        response_data <= 8'hEE;
        start         <= 1'b0;
        done_sticky   <= 1'b0;
        latch_pending <= 1'b0;
        sin_neg_reg   <= 1'b0;
        cos_neg_reg   <= 1'b0;
        sin_corrected <= 16'sd0;
        cos_corrected <= 16'sd0;
        tan_corrected <= 16'sd0;
        tan_done_sticky <= 1'b0;
        led           <= 1'b0;
    end
    else
    begin
        start <= 1'b0;

        if(done)
        begin
            sin_corrected <= sin_neg_reg ? -sin_out : sin_out;
            cos_corrected <= cos_neg_reg ? -cos_out : cos_out;
            done_sticky   <= 1'b1;
            led           <= 1'b1;
        end

        if(tan_done)
        begin
            tan_corrected   <= tan_out;
            tan_done_sticky <= 1'b1;
        end

        if(latch_pending)
        begin
            sin_neg_reg   <= sin_neg;
            cos_neg_reg   <= cos_neg;
            start         <= 1'b1;
            latch_pending <= 1'b0;
        end

        if(rx_valid)
        begin
            case(rx_state)
                IDLE:
                begin
                    if(rx_data == 8'hA1) //A1: an angle is about to be sent
                    begin
                        rx_state        <= BYTE0;
                        done_sticky     <= 1'b0;
                        tan_done_sticky <= 1'b0;
                        led             <= 1'b0;
                    end
                    else if(rx_data == 8'hA2) //A2: checks whether calculation is finished or not
                        response_data <= {7'd0, done_sticky};
                    else if(rx_data == 8'hA3)
                        response_data <= sin_corrected[7:0];
                    else if(rx_data == 8'hA4)
                        response_data <= sin_corrected[15:8];
                    else if(rx_data == 8'hA6)
                        response_data <= cos_corrected[7:0];
                    else if(rx_data == 8'hA7)
                        response_data <= cos_corrected[15:8];
                    else if(rx_data == 8'hA5) //A5: checks whether tan calculation is finished or not
                        response_data <= {7'd0, tan_done_sticky};
                    else if(rx_data == 8'hA8) //A8: TAN low byte
                        response_data <= tan_corrected[7:0];
                    else if(rx_data == 8'hA9) //A9: TAN high byte
                        response_data <= tan_corrected[15:8];
                    else
                        response_data <= 8'hEE;
                end

                BYTE0:
                begin
                    angle_reg[7:0] <= rx_data;
                    rx_state       <= BYTE1;
                end

                BYTE1:
                begin
                    angle_reg[15:8] <= rx_data;
                    rx_state        <= BYTE2;
                end

                BYTE2:
                begin
                    angle_reg[23:16] <= rx_data;
                    rx_state         <= BYTE3;
                end

                BYTE3:
                begin
                    angle_reg[31:24] <= rx_data;
                    latch_pending    <= 1'b1;
                    rx_state         <= IDLE;
                end

                default:
                    rx_state <= IDLE;
            endcase
        end
    end
end

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        tx_data <= 8'h55;
    else if(tx_hold)
        tx_data <= response_data;
end

endmodule