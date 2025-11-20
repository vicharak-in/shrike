// ---------------------------------------------------------------------------
// © 2024 Renesas Electronics
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
// OR OTHER DEALINGS IN THE SOFTWARE.
// ---------------------------------------------------------------------------
// Base Module Name: i2c_slave
// Target Device: SLG47910
// Tools version:
//   Software: ForgeFPGA Workshop v.6.31
//   Hardware: FPGAPAK Development Board Rev.1.1
// Revision:
//   02.08.2022 r001 - New design
//   09.15.2022 r002 - Code style review
//   03.25.2024 r003 - Changed output enable polarity
//   04.01.2024 r004 - Limits added in the parameters comments
//   10.29.2024 r005 :
//                      FSM optimization;
//                      ready signals are made in one period of the internal frequency;
//                      control of the SDA line only via an enable signal, the SDA output signal is constant (1'b0);
//                      the enable signal was transferred only to the initial state of FSM.
// ---------------------------------------------------------------------------
// Description :
//   In this module implemented an I2C slave controller which configures by the parameter I2C_SLAVE_ADR.
// ---------------------------------------------------------------------------

`timescale 1ns / 1ps

module i2c_slave #(
    parameter I2C_SLAVE_ADR = 7'h32 // Slave address, default value 7'h08 (Type - Hex, Default value = 7'h08, Min value = 7'h01, Max value = 7'h7F)
) (
    // common port
    input   wire        i_clk,      //  input clock signal
    input   wire        i_rst,      //  input reset signal
    input   wire        i_en,       //  input signal which start operation
    output  wire        o_busy,     //  output which indicates the operation state
    // interface port
    input   wire        i_scl,      //  input serial clock signal
    input   wire        i_sda,      //  input serial data signal
    output  wire        o_sda,      //  output serial data signal
    output  reg         o_sda_oe,   //  output enable signal for serial data output signal
    // internal port
    input   wire [7:0]  i_data_tx,  //  data inputs bus
    output  reg  [7:0]  o_data_rx,  //  data outputs bus
    output  reg         o_int_tx,   //  output signal which indicates that i_data_tx was sent
    output  reg         o_int_rx    //  output signal which indicates that o_data_rx was updated
);

// Localparam declaration
localparam IDLE         = 9'b0_0000_0001;  // 0x001
localparam START        = 9'b0_0000_0010;  // 0x002
localparam CMD          = 9'b0_0000_0100;  // 0x004
localparam ACK_CMD      = 9'b0_0000_1000;  // 0x008
localparam WRITE        = 9'b0_0001_0000;  // 0x010
localparam ACK_WRITE    = 9'b0_0010_0000;  // 0x020
localparam READ         = 9'b0_0100_0000;  // 0x040
localparam ACK_READ     = 9'b0_1000_0000;  // 0x080
localparam STOP         = 9'b1_0000_0000;  // 0x100

// Signal declaration
reg [8:0] r_state, n_state;
reg       n_sda, r_sda;
wire      r_cnt_en;
reg       r_ack_flag;
reg [7:0] r_buffer_tx, r_buffer_rx;
reg [2:0] r_bit_cnt;
reg [2:0] r_sda_in_sync, r_scl_in_sync;
reg       r_scl_in_rise, r_scl_in_fall;
wire      r_scl_in_fall_prev;
reg       r_det_start, r_det_stop;
reg       latch_buff_tx;
wire      sda_oe_mux;

// External signal synchronizers
always @(posedge i_clk) begin
    if(i_rst) begin
        r_scl_in_sync <= 3'b111;
    end else begin
        r_scl_in_sync[0] <= i_scl;
        r_scl_in_sync[1] <= r_scl_in_sync[0];
        r_scl_in_sync[2] <= r_scl_in_sync[1];
    end
end

always @(posedge i_clk) begin
    if(i_rst) begin
        r_sda_in_sync <= 3'b111;
    end else begin
        r_sda_in_sync[0] <= i_sda;
        r_sda_in_sync[1] <= r_sda_in_sync[0];
        r_sda_in_sync[2] <= r_sda_in_sync[1];
    end
end

// SCL Rise Edge Detector
always @(posedge i_clk) begin
    if (i_rst) begin
        r_scl_in_rise <= 1'b0;
    end else begin
        r_scl_in_rise <= r_scl_in_sync[1] & ~r_scl_in_sync[2];
    end
end

// SCL Fall Edge Detector
assign r_scl_in_fall_prev = ~r_scl_in_sync[1] & r_scl_in_sync[2];

always @(posedge i_clk) begin
    if (i_rst) begin
        r_scl_in_fall <= 1'b0;
    end else begin
        r_scl_in_fall <= r_scl_in_fall_prev;
    end
end

// Start Detection
always @(posedge i_clk) begin
    if (i_rst) begin
        r_det_start <= 1'b0;
    end else begin
        r_det_start <= (~r_sda_in_sync[1] & r_sda_in_sync[2]) & r_scl_in_sync[2];
    end
end

// Stop Detection
always @(posedge i_clk) begin
    if (i_rst) begin
        r_det_stop <= 1'b0;
    end else begin
        r_det_stop <= (r_sda_in_sync[1] & ~r_sda_in_sync[2]) & r_scl_in_sync[2];
    end
end

// Data bits counter
always @(posedge i_clk) begin
    if (i_rst) begin
        r_bit_cnt <= 3'h7;
    end else begin
        if (r_state == IDLE) begin
            r_bit_cnt <= 3'h7;
        end else if(r_cnt_en && r_scl_in_fall) begin
            r_bit_cnt <= r_bit_cnt - 1;
        end
    end
end

// Finite State-machine
always @(posedge i_clk) begin
    if (i_rst)  r_state <= IDLE;
    else        r_state <= n_state;
end

always @* begin
    latch_buff_tx = 1'b0;
    n_sda = 1'b1;
    n_state = IDLE;
    case(r_state)
        IDLE: begin
            if (i_en && r_det_start)  n_state = START;
            else                      n_state = IDLE;
        end
        START: begin
            if (r_scl_in_fall)  n_state = CMD;
            else                n_state = START;
        end
        CMD: begin
            if (r_bit_cnt == 0 && r_scl_in_fall)  n_state = ACK_CMD;
            else                                  n_state = CMD;
        end
        ACK_CMD: begin
            if (r_buffer_rx[7:1] == I2C_SLAVE_ADR) begin
                n_sda = 1'b0;
                if (r_scl_in_fall) begin
                    n_sda = 1'b1;
                    if (r_buffer_rx[0]) begin
                        latch_buff_tx = 1'b1;
                        n_state = WRITE;
                    end else begin
                        n_state = READ;
                    end
                end else begin
                    n_state = ACK_CMD;
                end
            end else begin
                n_state = STOP;
            end
        end
        WRITE: begin
            n_sda = r_buffer_tx[r_bit_cnt];
            if (r_bit_cnt == 0 && r_scl_in_fall)  n_state = ACK_WRITE;
            else if (r_det_start)                 n_state = START;
            else if (r_det_stop)                  n_state = IDLE;
            else                                  n_state = WRITE;
        end
        ACK_WRITE: begin
            if (r_scl_in_fall) begin
                if (r_ack_flag) begin
                    latch_buff_tx = 1'b1;
                    n_state = WRITE;
                end else begin
                  n_state = STOP;
                end
            end else begin
                n_state = ACK_WRITE;
          end
        end
        READ: begin
            if (r_bit_cnt == 0 && r_scl_in_fall)  n_state = ACK_READ;
            else if (r_det_start)                 n_state = START;
            else if (r_det_stop)                  n_state = IDLE;
            else                                  n_state = READ;
        end
        ACK_READ: begin
            n_sda = 1'b0;
            if (r_scl_in_fall) begin
                n_sda = 1'b1;
                n_state = READ;
            end else begin
                n_state = ACK_READ;
            end
        end
        STOP: begin
            if (r_det_stop)   n_state = IDLE;
            else              n_state = STOP;
        end
        default: begin
            latch_buff_tx = 1'b0;
            n_sda = 1'b1;
            n_state = IDLE;
        end
    endcase
end

// TX register buffer
always @(posedge i_clk) begin
    if(i_rst) begin
        r_buffer_tx <= 8'h00;
    end else if(latch_buff_tx) begin
        r_buffer_tx <= i_data_tx;
    end
end

// RX Buffer
always @(posedge i_clk) begin
    if(i_rst) begin
        r_buffer_rx <= 8'h00;
    end else if((r_state == CMD || r_state == READ) && (r_scl_in_rise)) begin
        r_buffer_rx[r_bit_cnt] <= r_sda_in_sync[2];
    end else if((r_state == IDLE)) begin
        r_buffer_rx <= 8'h00;
    end
end

// End of data transfer
always @(posedge i_clk) begin
    if(i_rst) begin
        o_int_tx <= 1'b0;
    end else if((r_state == WRITE) && (r_bit_cnt == 0 && r_scl_in_fall)) begin
        o_int_tx <= 1'b1;
    end else begin
        o_int_tx <= 1'b0;
    end
end

// End of data receive
always @(posedge i_clk) begin
    if(i_rst) begin
        o_int_rx <= 1'b0;
    end else if((r_state == ACK_READ) && r_scl_in_rise) begin
        o_int_rx <= 1'b1;
    end else begin
        o_int_rx <= 1'b0;
    end
end

// ACK flag
always @(posedge i_clk) begin
    if(i_rst) begin
        r_ack_flag <= 1'b0;
    end else if(r_state == ACK_WRITE) begin
        if (r_scl_in_rise) begin
            if (~r_sda_in_sync[2]) begin
                r_ack_flag <= 1'b1;
            end else begin
                r_ack_flag <= 1'b0;
            end
        end
    end else begin
        r_ack_flag <= 1'b0;
    end
end

// Enable counter
assign r_cnt_en = (r_state == CMD || r_state == WRITE || r_state == READ) ? 1'b1 : 1'b0;

// Busy signal
assign o_busy = (r_state == IDLE) ? 1'b0 : 1'b1;

// Data Output Bus
always @(posedge i_clk) begin
    if(i_rst) begin
        o_data_rx <= 8'h00;
    end else if(r_scl_in_rise && (r_state == ACK_READ)) begin
        o_data_rx <= r_buffer_rx;
    end
end

// SDA register
always @(posedge i_clk) begin
    if (i_rst) begin
        r_sda <= 1'b1;
    end else begin
        r_sda <= n_sda;
    end
end

// SDA output control
assign sda_oe_mux = (r_sda) ? 1'b0 : 1'b1;

always @(posedge i_clk) begin
    if (i_rst) begin
        o_sda_oe <= 1'b0;
    end else begin
        o_sda_oe <= sda_oe_mux;
    end
end

assign o_sda = 1'b0;

endmodule
