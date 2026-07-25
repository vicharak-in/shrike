`timescale 1ns/1ps

module uart_tx #(
    parameter [8:0] CLKS_PER_BIT = 9'd434
)(
    input  wire       i_clk,
    input  wire       i_tx_start,
    input  wire [7:0] i_tx_byte,
    output reg        o_tx_serial,
    output reg        o_tx_busy
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0, 
                     START   = 3'd1, 
                     DATA    = 3'd2, 
                     STOP    = 3'd3, 
                     CLEANUP = 3'd4;

    reg [2:0] state    = IDLE;
    reg [8:0] clk_cnt  = 9'd0;
    reg [2:0] bit_idx  = 3'd0;
    reg [7:0] tx_shift = 8'd0;

    // Transmitter state machine
    always @(posedge i_clk) begin
        case (state)
            IDLE: begin
                o_tx_serial <= 1'b1; 
                o_tx_busy   <= 1'b0; 
                clk_cnt     <= 9'd0; 
                bit_idx     <= 3'd0;
                
                if (i_tx_start) begin 
                    tx_shift  <= i_tx_byte; 
                    o_tx_busy <= 1'b1; 
                    state     <= START; 
                end
            end

            START: begin
                o_tx_serial <= 1'b0;
                if (clk_cnt == CLKS_PER_BIT - 1) begin 
                    clk_cnt <= 9'd0; 
                    state   <= DATA; 
                end else begin
                    clk_cnt <= clk_cnt + 9'd1;
                end
            end

            DATA: begin
                o_tx_serial <= tx_shift[bit_idx];
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt <= 9'd0;
                    if (bit_idx == 3'd7) begin 
                        bit_idx <= 3'd0; 
                        state   <= STOP; 
                    end else begin
                        bit_idx <= bit_idx + 3'd1;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 9'd1;
                end
            end

            STOP: begin
                o_tx_serial <= 1'b1;
                if (clk_cnt == CLKS_PER_BIT - 1) begin 
                    clk_cnt <= 9'd0; 
                    state   <= CLEANUP; 
                end else begin
                    clk_cnt <= clk_cnt + 9'd1;
                end
            end

            CLEANUP: begin 
                o_tx_busy <= 1'b0; 
                state     <= IDLE; 
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end

endmodule