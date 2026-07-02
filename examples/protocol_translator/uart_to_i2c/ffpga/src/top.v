`timescale 1ns/1ps
//------------------------------------------------------------
// Module Name : top
//
// Description:
// Top level module for the UART to I2C Bridge.
//------------------------------------------------------------

(* top *)
module top #(

    parameter CLK       = 50000000,
    parameter BAUD_RATE = 115200

)(

    (* iopad_external_pin, clkbuf_inhibit *) input clk,

    (* iopad_external_pin *) output clk_en,

    (* iopad_external_pin *) input  i_uart_rx,
    (* iopad_external_pin *) output o_uart_tx,
    (* iopad_external_pin *) output o_uart_tx_oe,

    (* iopad_external_pin *) input  i_i2c_sda,
    (* iopad_external_pin *) input  i_i2c_scl,
    (* iopad_external_pin *) output o_i2c_scl,
    (* iopad_external_pin *) output o_i2c_scl_oe,
    (* iopad_external_pin *) output o_i2c_sda,
    (* iopad_external_pin *) output o_i2c_sda_oe

);

    assign clk_en       = 1'b1;
    assign o_uart_tx_oe = 1'b1;
    assign o_i2c_scl    = 1'b0;
    assign o_i2c_sda    = 1'b0;

// Global Parameters / Constants
    localparam [6:0] I2C_ADDR = 7'h50;

// I2C Synchronizer Signals
    reg  [1:0] scl_sync = 2'b11;
    reg  [1:0] sda_sync = 2'b11;
    wire       filtered_scl;
    wire       filtered_sda;

// UART RX Signals
    wire [7:0] w_uart_byte;
    wire       w_uart_dv;

// UART TX Signals
    reg  [7:0] r_uart_tx_byte = 8'd0;
    reg        r_uart_tx_start = 1'b0;
    wire       w_uart_tx_busy;

// I2C Master Signals
    reg        r_i2c_start = 1'b0;
    reg        r_i2c_rnw = 1'b0;
    wire [7:0] w_i2c_data_read;
    wire       w_i2c_busy;
    wire       w_i2c_done;
    wire       w_i2c_ack_ok;

// Bridge Control Signals
    reg  [7:0] bridge_holding_reg = 8'd0;
    reg        rx_pending = 1'b0;

// State Machine States
    localparam [1:0] BR_IDLE      = 2'd0;
    localparam [1:0] BR_I2C_WRITE = 2'd1;
    localparam [1:0] BR_I2C_READ  = 2'd2;
    localparam [1:0] BR_UART_ECHO = 2'd3;

    reg  [1:0] bridge_state = BR_IDLE;

// Filter Assignments
    assign filtered_scl = scl_sync[1];
    assign filtered_sda = sda_sync[1];

// Submodule Instantiations
    uart_rx #(
        .CLKS_PER_BIT(9'd434)
    ) u_uart_receiver (
        .i_clk(clk),
        .i_rx(i_uart_rx),

        .o_rx_byte(w_uart_byte),
        .o_rx_dv(w_uart_dv)
    );

    uart_tx #(
        .CLKS_PER_BIT(9'd434)
    ) u_uart_transmitter (
        .i_clk(clk),
        .i_tx_start(r_uart_tx_start),
        .i_tx_byte(r_uart_tx_byte),

        .o_tx_serial(o_uart_tx),
        .o_tx_busy(w_uart_tx_busy)
    );

    i2c_master_core #(
        .CLK_DIV(16'd250)
    ) u_i2c_master (
        .i_clk(clk),
        .i_start(r_i2c_start),
        .i_rnw(r_i2c_rnw),
        .i_addr(I2C_ADDR),
        .i_data_write(bridge_holding_reg),

        .i_sda(filtered_sda),
        .i_scl(filtered_scl),

        .o_scl_oe(o_i2c_scl_oe),
        .o_sda_oe(o_i2c_sda_oe),
        
        .o_data_read(w_i2c_data_read),
        .o_busy(w_i2c_busy),
        .o_done(w_i2c_done),
        .o_ack_ok(w_i2c_ack_ok)
    );

// Synchronizer Block
    always @(posedge clk) begin
        scl_sync <= {scl_sync[0], i_i2c_scl};
        sda_sync <= {sda_sync[0], i_i2c_sda};
    end

// Main Bridge State Machine
    always @(posedge clk) begin
        r_i2c_start     <= 1'b0;
        r_uart_tx_start <= 1'b0;

        if (w_uart_dv) begin
            bridge_holding_reg <= w_uart_byte;
            rx_pending         <= 1'b1;
        end

        case (bridge_state)
            BR_IDLE: begin
                if (rx_pending && !w_i2c_busy) begin
                    r_i2c_start  <= 1'b1;
                    r_i2c_rnw    <= 1'b0;
                    rx_pending   <= 1'b0;
                    bridge_state <= BR_I2C_WRITE;
                end
            end

            BR_I2C_WRITE: begin
                if (w_i2c_done) begin
                    if (w_i2c_ack_ok) begin
                        r_i2c_start  <= 1'b1;
                        r_i2c_rnw    <= 1'b1;
                        bridge_state <= BR_I2C_READ;
                    end else begin
                        r_uart_tx_byte  <= 8'hEE;
                        r_uart_tx_start <= 1'b1;
                        bridge_state    <= BR_UART_ECHO;
                    end
                end
            end

            BR_I2C_READ: begin
                if (w_i2c_done) begin
                    r_uart_tx_byte  <= w_i2c_ack_ok ? w_i2c_data_read : 8'hEE;
                    r_uart_tx_start <= 1'b1;
                    bridge_state    <= BR_UART_ECHO;
                end
            end

            BR_UART_ECHO: begin
                if (!w_uart_tx_busy) begin
                    bridge_state <= BR_IDLE;
                end
            end

            default: begin
                bridge_state <= BR_IDLE;
            end
        endcase
    end

endmodule