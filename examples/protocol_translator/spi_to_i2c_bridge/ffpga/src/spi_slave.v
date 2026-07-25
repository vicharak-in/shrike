`timescale 1ns/1ps
//------------------------------------------------------------
// Module : spi_slave  (SPI mode 0, MSB first)
//
// One byte per CS assertion. Full-duplex: every transfer
// simultaneously receives a MOSI byte (o_rx_byte / o_rx_dv) and
// sends the byte on i_tx_byte out on MISO.
//
// o_tx_load pulses at the CS falling edge, i.e. the instant the
// i_tx_byte value is committed to MISO. The bridge uses it to pop
// the outgoing FIFO exactly once per transfer (by transaction,
// not by value) so 0x00 is a legal payload.
//------------------------------------------------------------

module spi_slave (
    input  wire       i_clk,
    input  wire       i_sck,
    input  wire       i_mosi,
    output reg        o_miso    = 1'b0,
    input  wire       i_ss,
    output reg [7:0]  o_rx_byte = 8'h00,
    output reg        o_rx_dv   = 1'b0,
    output reg        o_tx_load = 1'b0,
    input  wire [7:0] i_tx_byte
);
    reg [2:0] sck_r  = 3'b000;
    reg [2:0] ss_r   = 3'b111;
    reg [1:0] mosi_r = 2'b00;

    always @(posedge i_clk) begin
        sck_r  <= {sck_r[1:0], i_sck};
        ss_r   <= {ss_r[1:0], i_ss};
        mosi_r <= {mosi_r[0], i_mosi};
    end

    wire sck_pos   = (sck_r[2:1] == 2'b01);
    wire sck_neg   = (sck_r[2:1] == 2'b10);
    wire ss_active = ~ss_r[1];

    reg [2:0] bit_cnt    = 3'd7;
    reg [7:0] rx_shifter = 8'h00;
    reg [7:0] tx_shifter = 8'h00;

    always @(posedge i_clk) begin
        o_rx_dv   <= 1'b0;
        o_tx_load <= 1'b0;

        if (!ss_active) begin
            bit_cnt    <= 3'd7;
            o_miso     <= 1'b0;
            tx_shifter <= i_tx_byte;   // track the FIFO head while idle
        end else begin
            if (ss_r[2:1] == 2'b10) begin      // CS falling edge
                o_miso    <= tx_shifter[7];
                o_tx_load <= 1'b1;             // commit -> pop outgoing FIFO
            end else if (sck_neg) begin
                tx_shifter <= {tx_shifter[6:0], 1'b0};
                o_miso     <= tx_shifter[6];
            end

            if (sck_pos) begin
                rx_shifter <= {rx_shifter[6:0], mosi_r[1]};
                if (bit_cnt == 3'd0) begin
                    o_rx_byte <= {rx_shifter[6:0], mosi_r[1]};
                    o_rx_dv   <= 1'b1;
                    bit_cnt   <= 3'd7;
                end else begin
                    bit_cnt <= bit_cnt - 3'd1;
                end
            end
        end
    end
endmodule
