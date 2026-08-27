// =============================================================================
// uart_tx.v -- minimal 8N1 UART transmitter for shrike_serv.
//
// Fixed 8 data bits, no parity, 1 stop bit; bit period = IN_CLK_HZ / BAUD_RATE
// clocks. Pulse i_tx_start for one clock with a byte on i_tx_data (only sampled
// while idle); o_tx_done pulses one clock when the stop bit completes. The extra
// parameters are accepted for drop-in compatibility with the general uart_sum
// core but are fixed here (8N1) to keep the datapath tiny.
// =============================================================================
`default_nettype none

module uart_tx #(
    parameter IN_CLK_HZ         = 25_000_000,
    parameter BAUD_RATE         = 115200,
    parameter DATA_FRAME        = 8,      // fixed 8
    parameter OVERSAMPLING_MODE = 16,     // unused
    parameter STOP_BIT          = 1,      // fixed 1
    parameter LSB               = 1'b0    // fixed LSB-first
)(
    input  wire       i_clk,
    input  wire       i_rst,
    output wire       o_tx,
    input  wire [7:0] i_tx_data,
    input  wire       i_tx_start,
    output wire       o_tx_done
);
    localparam integer CPB = IN_CLK_HZ / BAUD_RATE;   // clocks per bit (~217)
    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [1:0] state   = IDLE;
    reg [8:0] cnt     = 9'd0;      // 0..CPB-1
    reg [2:0] bit_i   = 3'd0;
    reg [7:0] shifter = 8'd0;
    reg       tx      = 1'b1;
    reg       done    = 1'b0;

    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= IDLE; tx <= 1'b1; done <= 1'b0; cnt <= 9'd0; bit_i <= 3'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    tx <= 1'b1; cnt <= 9'd0; bit_i <= 3'd0;
                    if (i_tx_start) begin shifter <= i_tx_data; state <= START; end
                end
                START: begin
                    tx <= 1'b0;
                    if (cnt == CPB-1) begin cnt <= 9'd0; state <= DATA; end
                    else                cnt <= cnt + 9'd1;
                end
                DATA: begin
                    tx <= shifter[bit_i];
                    if (cnt == CPB-1) begin
                        cnt <= 9'd0;
                        if (bit_i == 3'd7) state <= STOP; else bit_i <= bit_i + 3'd1;
                    end else cnt <= cnt + 9'd1;
                end
                STOP: begin
                    tx <= 1'b1;
                    if (cnt == CPB-1) begin cnt <= 9'd0; done <= 1'b1; state <= IDLE; end
                    else                cnt <= cnt + 9'd1;
                end
            endcase
        end
    end

    assign o_tx      = tx;
    assign o_tx_done = done;
endmodule
`default_nettype wire
