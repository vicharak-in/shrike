`timescale 1ns/1ps
//------------------------------------------------------------
// Module : top  (UART <-> I2C, fully bidirectional)
//
// The FPGA is an I2C SLAVE (address 0x50) driven by an external
// I2C master, plus a full-duplex UART link. The two directions
// run INDEPENDENTLY through their own FIFOs:
//
//   I2C master WRITE  --> [fifo_i2u] --> UART TX        (I2C -> UART)
//   UART RX byte      --> [latest-byte reg] --> I2C READ (UART -> I2C)
//
// So a byte the master writes over I2C is forwarded out on UART,
// and a byte received on UART is handed back the next time the
// master reads over I2C. Neither side has to trigger the other.
//------------------------------------------------------------

(* top *)
module top (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *)                 output wire clk_en,

    // UART
    (* iopad_external_pin *)                 input  wire i_uart_rx,
    (* iopad_external_pin *)                 output wire o_uart_tx,
    (* iopad_external_pin *)                 output wire o_uart_tx_oe,

    // I2C (slave; SCL input-only, SDA open-drain)
    (* iopad_external_pin *)                 input  wire i_i2c_sda,
    (* iopad_external_pin *)                 input  wire i_i2c_scl,
    (* iopad_external_pin *)                 output wire o_i2c_sda,
    (* iopad_external_pin *)                 output wire o_i2c_sda_oe
);
    assign clk_en       = 1'b1;
    assign o_uart_tx_oe = 1'b1;
    assign o_i2c_sda    = 1'b0;   // open-drain: only ever pulled low via oe

    // ---- UART ----
    wire [7:0] uart_rx_byte;
    wire       uart_rx_dv;
    reg  [7:0] uart_tx_byte  = 8'h00;
    reg        uart_tx_start = 1'b0;
    wire       uart_tx_busy;

    uart_rx #(.CLKS_PER_BIT(9'd434)) u_rx (
        .i_clk(clk), .i_rx(i_uart_rx),
        .o_rx_byte(uart_rx_byte), .o_rx_dv(uart_rx_dv)
    );
    uart_tx #(.CLKS_PER_BIT(9'd434)) u_tx (
        .i_clk(clk), .i_tx_start(uart_tx_start), .i_tx_byte(uart_tx_byte),
        .o_tx_serial(o_uart_tx), .o_tx_busy(uart_tx_busy)
    );

    // ---- I2C slave ----
    wire [7:0] i2c_rx_data;
    wire       i2c_rx_valid;
    wire [7:0] i2c_tx_data;

    i2c_slave_core #(.SLAVE_ADDR(7'h50)) u_i2c (
        .i_clk(clk), .i_scl(i_i2c_scl), .i_sda(i_i2c_sda),
        .i_tx_data(i2c_tx_data),
        .o_sda_oe(o_i2c_sda_oe),
        .o_rx_data(i2c_rx_data), .o_rx_valid(i2c_rx_valid),
        .o_rd_done()            // not used: read path is a latest-byte register
    );

    // ---- FIFO: I2C write -> UART TX ----
    wire [7:0] i2u_head;
    wire       i2u_empty, i2u_full;
    reg        i2u_rd = 1'b0;
    sync_fifo #(.WIDTH(8), .DEPTH(16), .AWID(4)) fifo_i2u (
        .i_clk(clk), .i_wr(i2c_rx_valid), .i_wdata(i2c_rx_data),
        .i_rd(i2u_rd), .o_rdata(i2u_head), .o_empty(i2u_empty), .o_full(i2u_full)
    );

    // ---- UART RX -> I2C read : latest-byte register ----
    // The I2C master reads back the most recently received UART byte. Using a
    // register (not a pop-on-read FIFO) makes this robust to real I2C read
    // timing -- the read never has to advance a queue pointer.
    reg [7:0] uart_latch = 8'h00;
    always @(posedge clk) begin
        if (uart_rx_dv) uart_latch <= uart_rx_byte;
    end
    assign i2c_tx_data = uart_latch;

    // ---- UART TX pump: drain fifo_i2u onto the serial line ----
    localparam [1:0] P_IDLE = 2'd0, P_WAITBUSY = 2'd1, P_WAITDONE = 2'd2;
    reg [1:0] p_state = P_IDLE;
    always @(posedge clk) begin
        uart_tx_start <= 1'b0;
        i2u_rd        <= 1'b0;
        case (p_state)
            P_IDLE: begin
                if (!i2u_empty && !uart_tx_busy) begin
                    uart_tx_byte  <= i2u_head;
                    uart_tx_start <= 1'b1;
                    i2u_rd        <= 1'b1;      // pop the byte we just latched
                    p_state       <= P_WAITBUSY;
                end
            end
            P_WAITBUSY: if (uart_tx_busy)  p_state <= P_WAITDONE;
            P_WAITDONE: if (!uart_tx_busy) p_state <= P_IDLE;
            default:    p_state <= P_IDLE;
        endcase
    end
endmodule
