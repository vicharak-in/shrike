`timescale 1ns/1ps

module uart_rx #(
    parameter [8:0] CLKS_PER_BIT = 9'd434
)(
    input  wire       i_clk,
    input  wire       i_rx,
    output reg [7:0]  o_rx_byte,
    output reg        o_rx_dv
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0, 
                     START   = 3'd1, 
                     DATA    = 3'd2, 
                     STOP    = 3'd3, 
                     CLEANUP = 3'd4;

    reg [2:0] state     = IDLE;
    reg [8:0] clk_cnt   = 9'd0;
    reg [2:0] bit_idx   = 3'd0;
    reg [7:0] rx_shift  = 8'd0;
    reg       rx_ff1    = 1'b1; 
    reg       rx_ff2    = 1'b1;

    // Double-flop RX input for metastability mitigation
    always @(posedge i_clk) begin
        rx_ff1 <= i_rx;
        rx_ff2 <= rx_ff1;
    end

    // Receiver state machine
    always @(posedge i_clk) begin
        o_rx_dv <= 1'b0;

        case (state)
            IDLE: begin
                clk_cnt <= 9'd0; 
                bit_idx <= 3'd0;
                if (rx_ff2 == 1'b0) 
                    state <= START;
            end

            START: begin
                if (clk_cnt == (CLKS_PER_BIT >> 1) - 1) begin
                    if (rx_ff2 == 1'b0) begin 
                        clk_cnt <= 9'd0; 
                        state   <= DATA; 
                    end else begin
                        state   <= IDLE;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 9'd1;
                end
            end

            DATA: begin
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt            <= 9'd0; 
                    rx_shift[bit_idx]  <= rx_ff2;
                    
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
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt   <= 9'd0; 
                    o_rx_byte <= rx_shift; 
                    o_rx_dv   <= 1'b1; 
                    state     <= CLEANUP;
                end else begin
                    clk_cnt <= clk_cnt + 9'd1;
                end
            end

            CLEANUP: begin
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end

endmodule