// SPI master (Mode 0, MSB-first) -- FPGA drives an external SPI slave (e.g. Arduino).
// Generates SCK/SS_n/MOSI, samples a synchronized MISO. CLK_DIV sets the SCK rate
// from i_clk; the 2-FF MISO synchronizer is required for reliable hardware sampling.
module spi_master #(
    parameter WIDTH = 8,
    parameter CLK_DIV = 16
) (
    input i_clk,
    input i_rst_n,
    input i_start,
    input [WIDTH-1:0]  i_tx_data,
    output reg [WIDTH-1:0]  o_rx_data,
    output reg o_busy,
    output reg o_done,
    output reg o_ss_n,
    output reg o_sck,
    output reg o_mosi,
    input i_miso);
    localparam ST_IDLE = 2'd0, ST_XFER = 2'd1, ST_TAIL = 2'd2;

    reg [1:0] state;
    reg [15:0] div_cnt;
    reg [WIDTH-1:0] tx_shift;
    reg [WIDTH-1:0] rx_shift;
    reg [$clog2(WIDTH+1)-1:0] bit_cnt;

    wire tick = (div_cnt == CLK_DIV-1);
    reg [1:0] miso_sync;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) miso_sync <= 2'b00;
        else miso_sync <= {miso_sync[0], i_miso};
    end
    wire miso_s = miso_sync[1];
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= ST_IDLE; div_cnt <= 0; tx_shift <= 0; rx_shift <= 0;
            bit_cnt <= 0; o_rx_data <= 0; o_busy <= 0; o_done <= 0;
            o_ss_n <= 1'b1; o_sck <= 1'b0; o_mosi <= 1'b0;
        end else begin
            o_done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    o_sck <= 1'b0;
                    o_ss_n <= 1'b1;
                    if (i_start) begin
                        tx_shift <= i_tx_data;
                        o_mosi <= i_tx_data[WIDTH-1];
                        rx_shift <= 0; bit_cnt <= 0; div_cnt <= 0;
                        o_ss_n <= 1'b0; o_busy <= 1'b1;
                        state <= ST_XFER;
                    end
                end
                ST_XFER: begin
                    if (tick) begin
                        div_cnt <= 0;
                        o_sck <= ~o_sck;
                        if (!o_sck) begin
                            rx_shift <= {rx_shift[WIDTH-2:0], miso_s};
                            bit_cnt <= bit_cnt + 1'b1;
                            if (bit_cnt == WIDTH-1) state <= ST_TAIL;
                        end else begin
                            tx_shift <= {tx_shift[WIDTH-2:0], 1'b0};
                            o_mosi <= tx_shift[WIDTH-2];
                        end
                    end else div_cnt <= div_cnt + 1'b1;
                end
                ST_TAIL: begin
                    if (tick) begin
                        div_cnt <= 0; o_sck <= 1'b0; o_ss_n <= 1'b1;
                        o_busy <= 1'b0; o_done <= 1'b1; o_rx_data <= rx_shift;
                        state <= ST_IDLE;
                    end else div_cnt <= div_cnt + 1'b1;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
