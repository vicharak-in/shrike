// =============================================================================
// uart_rx.v -- minimal 8N1 UART receiver for shrike_serv.
//
// Fixed 8 data bits, no parity, 1 stop bit; bit period = CLK / BAUD_RATE clocks.
// A 2-FF synchronizer guards the async RX line; the start bit is re-checked at
// its midpoint, data bits are sampled at their centres, and o_RX_DV pulses one
// clock when a byte is complete (o_RX_Byte then holds it). Kept tiny (fixed 8N1)
// to fit alongside the CPU; drop-in for the general uart_sum core's ports.
// =============================================================================
`default_nettype none

module uart_rx #(
    parameter CLK       = 25_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       i_Clock,
    input  wire       i_RX_Serial,
    output wire       o_RX_DV,
    output wire [7:0] o_RX_Byte
);
    localparam integer CPB = CLK / BAUD_RATE;         // clocks per bit (~217)
    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg       rx_d1 = 1'b1, rx_d2 = 1'b1;             // 2-FF synchronizer
    always @(posedge i_Clock) begin rx_d1 <= i_RX_Serial; rx_d2 <= rx_d1; end

    reg [1:0] state = IDLE;
    reg [8:0] cnt   = 9'd0;
    reg [2:0] bit_i = 3'd0;
    reg [7:0] data  = 8'd0;
    reg       dv    = 1'b0;

    always @(posedge i_Clock) begin
        dv <= 1'b0;
        case (state)
            IDLE: begin
                cnt <= 9'd0; bit_i <= 3'd0;
                if (~rx_d2) state <= START;           // start bit edge
            end
            START: begin
                if (cnt == (CPB-1)/2) begin           // midpoint of start bit
                    if (~rx_d2) begin cnt <= 9'd0; state <= DATA; end
                    else        state <= IDLE;         // false start
                end else cnt <= cnt + 9'd1;
            end
            DATA: begin
                if (cnt == CPB-1) begin
                    cnt <= 9'd0; data[bit_i] <= rx_d2;
                    if (bit_i == 3'd7) state <= STOP; else bit_i <= bit_i + 3'd1;
                end else cnt <= cnt + 9'd1;
            end
            STOP: begin
                if (cnt == CPB-1) begin dv <= 1'b1; cnt <= 9'd0; state <= IDLE; end
                else               cnt <= cnt + 9'd1;
            end
        endcase
    end

    assign o_RX_DV   = dv;
    assign o_RX_Byte = data;
endmodule
`default_nettype wire
