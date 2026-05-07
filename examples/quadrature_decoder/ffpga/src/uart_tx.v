//////////////////////////////////////////////////////////////////////
// This file contains the UART Transmitter.  This transmitter is able
// to transmit 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When transmit is complete o_Tx_done will be
// driven high for one clock cycle.
//
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of clk)/(Frequency of UART)
// Example: 25 MHz Clock, 115200 baud UART
// (50000000)/(115200) = 434
 
module uart_tx #(
    parameter CLKS_PER_BIT = 434)
(
    input       rst,
    input       clk,
    input       i_TX_DV,
    input [7:0] i_TX_Byte, 
    output reg  o_TX_Active,
    output reg  o_TX_Serial,
    output reg  o_TX_Done
);

localparam IDLE         = 3'b000;
localparam TX_START_BIT = 3'b001;
localparam TX_DATA_BITS = 3'b010;
localparam TX_STOP_BIT  = 3'b011;
localparam CLEANUP      = 3'b100;

reg [2:0] state;
reg [$clog2(CLKS_PER_BIT):0] clk_cnt;
reg [2:0] bit_index_cnt;
reg [7:0] r_TX_Data;


// Purpose: Control TX state machine
always @(posedge clk or negedge rst) begin
    if (~rst) begin
        state <= 3'b000;
    end else begin
        o_TX_Done <= 1'b0; // default assignment

        case (state)
            IDLE : begin
                o_TX_Serial   <= 1'b1; // Drive Line High for Idle
                clk_cnt <= 0;
                bit_index_cnt   <= 0;

                if (i_TX_DV == 1'b1) begin
                    o_TX_Active <= 1'b1;
                    r_TX_Data   <= i_TX_Byte;
                    state   <= TX_START_BIT;
                end else begin
                    state <= IDLE;
                end
            end

            // Send out Start Bit. Start bit = 0
            TX_START_BIT : begin
                o_TX_Serial <= 1'b0;

                // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
                if (clk_cnt < CLKS_PER_BIT-1) begin
                    clk_cnt <= clk_cnt + 1;
                    state     <= TX_START_BIT;
                end else begin
                    clk_cnt <= 0;
                    state     <= TX_DATA_BITS;
                end
            end

            // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
            TX_DATA_BITS : begin
                o_TX_Serial <= r_TX_Data[bit_index_cnt];

                if (clk_cnt < CLKS_PER_BIT-1) begin
                    clk_cnt <= clk_cnt + 1;
                    state     <= TX_DATA_BITS;
                end else begin
                    clk_cnt <= 0;

                    // Check if we have sent out all bits
                    if (bit_index_cnt < 7) begin
                        bit_index_cnt <= bit_index_cnt + 1;
                        state   <= TX_DATA_BITS;
                    end else begin
                        bit_index_cnt <= 0;
                        state   <= TX_STOP_BIT;
                    end
                end
            end

            // Send out Stop bit.  Stop bit = 1
            TX_STOP_BIT : begin
                o_TX_Serial <= 1'b1;

                // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
                if (clk_cnt < CLKS_PER_BIT-1) begin
                    clk_cnt <= clk_cnt + 1;
                    state     <= TX_STOP_BIT;
                end else begin
                    o_TX_Done     <= 1'b1;
                    clk_cnt <= 0;
                    state     <= CLEANUP;
                    o_TX_Active   <= 1'b0;
                end
            end

            // Stay here 1 clock
            CLEANUP : begin
                state <= IDLE;
            end

            default : begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule