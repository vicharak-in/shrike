`timescale 1ns/1ps
//------------------------------------------------------------
// Module : i2c_slave_core
//
// Byte-wide I2C slave. An EXTERNAL I2C master drives SCL and
// starts every transaction:
//   * master WRITE  -> received byte appears on o_rx_data with
//                      a 1-cycle o_rx_valid pulse.
//   * master READ   -> the byte on i_tx_data is shifted out;
//                      o_rd_done pulses when it has been delivered.
//
// SCL is input-only (this slave does not clock-stretch), SDA is
// open-drain via o_sda_oe (1 = pull low, 0 = release).
//------------------------------------------------------------

module i2c_slave_core #(
    parameter [6:0] SLAVE_ADDR = 7'h50
)(
    input  wire       i_clk,
    input  wire       i_scl,
    input  wire       i_sda,
    input  wire [7:0] i_tx_data,
    output reg        o_sda_oe   = 1'b0,
    output reg [7:0]  o_rx_data  = 8'h00,
    output reg        o_rx_valid = 1'b0,
    output reg        o_rd_done  = 1'b0
);
    // Edge detection on the synchronized bus
    reg [2:0] scl_r = 3'b111;
    reg [2:0] sda_r = 3'b111;
    always @(posedge i_clk) begin
        scl_r <= {scl_r[1:0], i_scl};
        sda_r <= {sda_r[1:0], i_sda};
    end

    wire scl_pos = (scl_r[2:1] == 2'b01);
    wire scl_neg = (scl_r[2:1] == 2'b10);
    wire start   = (scl_r[1] == 1'b1) && (sda_r[2:1] == 2'b10);
    wire stop    = (scl_r[1] == 1'b1) && (sda_r[2:1] == 2'b01);

    localparam [2:0] S_IDLE     = 3'd0,
                     S_ADDR     = 3'd1,
                     S_ACK_ADDR = 3'd2,
                     S_RX_DATA  = 3'd3,
                     S_ACK_DATA = 3'd4,
                     S_TX_DATA  = 3'd5,
                     S_TX_ACK   = 3'd6;

    reg [2:0] state      = S_IDLE;
    reg [3:0] bit_cnt    = 4'd0;
    reg [7:0] shift_reg  = 8'd0;
    reg       rnw        = 1'b0;
    reg [7:0] tx_shifter = 8'd0;

    always @(posedge i_clk) begin
        o_rx_valid <= 1'b0;
        o_rd_done  <= 1'b0;

        if (start) begin
            state    <= S_ADDR;
            bit_cnt  <= 4'd0;
            o_sda_oe <= 1'b0;
        end else if (stop) begin
            state    <= S_IDLE;
            o_sda_oe <= 1'b0;
        end else begin
            case (state)
                S_IDLE: o_sda_oe <= 1'b0;

                S_ADDR: begin
                    if (scl_pos) begin
                        shift_reg <= {shift_reg[6:0], sda_r[1]};
                        bit_cnt   <= bit_cnt + 4'd1;
                    end
                    if (bit_cnt == 4'd8) begin
                        bit_cnt <= 4'd0;
                        rnw     <= shift_reg[0];
                        if (shift_reg[7:1] == SLAVE_ADDR) state <= S_ACK_ADDR;
                        else                              state <= S_IDLE;
                    end
                end

                S_ACK_ADDR: begin
                    if (scl_neg) o_sda_oe <= 1'b1;
                    if (scl_pos) begin
                        bit_cnt <= 4'd0;
                        if (rnw == 1'b0) begin
                            state <= S_RX_DATA;
                        end else begin
                            tx_shifter <= i_tx_data;
                            state      <= S_TX_DATA;
                        end
                    end
                end

                S_RX_DATA: begin
                    if (scl_neg) o_sda_oe <= 1'b0;
                    if (scl_pos) begin
                        shift_reg <= {shift_reg[6:0], sda_r[1]};
                        bit_cnt   <= bit_cnt + 4'd1;
                    end
                    if (bit_cnt == 4'd8) begin
                        bit_cnt   <= 4'd0;
                        o_rx_data <= shift_reg;
                        state     <= S_ACK_DATA;
                    end
                end

                S_ACK_DATA: begin
                    if (scl_neg) begin
                        if (o_sda_oe == 1'b0) begin
                            o_sda_oe   <= 1'b1;   // drive ACK
                            o_rx_valid <= 1'b1;   // byte is valid
                        end else begin
                            o_sda_oe   <= 1'b0;   // release
                            state      <= S_IDLE;
                        end
                    end
                end

                S_TX_DATA: begin
                    if (scl_neg) begin
                        o_sda_oe   <= ~tx_shifter[7];
                        tx_shifter <= {tx_shifter[6:0], 1'b0};
                        bit_cnt    <= bit_cnt + 4'd1;
                    end
                    if (bit_cnt == 4'd8 && scl_pos) begin
                        bit_cnt   <= 4'd0;
                        o_rd_done <= 1'b1;         // read byte fully delivered
                        state     <= S_TX_ACK;
                    end
                end

                S_TX_ACK: begin
                    if (scl_neg) begin
                        o_sda_oe <= 1'b0;
                        state    <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
