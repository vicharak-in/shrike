`timescale 1ns/1ps
//------------------------------------------------------------
// Module : top  (SPI <-> I2C, FPGA = SPI slave + I2C MASTER)
//
// An external SPI master (e.g. RP2040) talks to the FPGA SPI slave.
// The FPGA is the I2C MASTER and drives an external I2C slave/sensor
// at TARGET_SLAVE_ADDR. Each SPI command byte drives one cycle:
//
//   SPI write X   --> I2C master WRITE X to the slave   (SPI -> I2C)
//                 --> (turnaround wait)
//                 --> I2C master READ the slave         (I2C -> SPI)
//                 --> result placed in the SPI TX buffer
//   SPI read      --> master clocks the result back on MISO
//
// The host does two SPI transactions per value: a command byte, then
// a dummy read-back. expect_readback discards that dummy by
// transaction (not by value) so 0x00 is a legal payload.
//------------------------------------------------------------

(* top *)
module top (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *)                 output wire clk_en,

    // SPI slave
    (* iopad_external_pin *)                 input  wire i_spi_sck,
    (* iopad_external_pin *)                 input  wire i_spi_mosi,
    (* iopad_external_pin *)                 output wire o_spi_miso,
    (* iopad_external_pin *)                 output wire o_spi_miso_oe,
    (* iopad_external_pin *)                 input  wire i_spi_ss,

    // I2C master (drives SCL and SDA, open-drain)
    (* iopad_external_pin *)                 input  wire i_i2c_sda,
    (* iopad_external_pin *)                 input  wire i_i2c_scl,
    (* iopad_external_pin *)                 output wire o_i2c_scl,
    (* iopad_external_pin *)                 output wire o_i2c_scl_oe,
    (* iopad_external_pin *)                 output wire o_i2c_sda,
    (* iopad_external_pin *)                 output wire o_i2c_sda_oe
);
    assign clk_en        = 1'b1;
    assign o_i2c_scl     = 1'b0;          // open-drain
    assign o_i2c_sda     = 1'b0;
    assign o_spi_miso_oe = ~i_spi_ss;     // drive MISO only when selected

    localparam [6:0] TARGET_SLAVE_ADDR = 7'h50;   // <-- set to your sensor address

    // Input synchronizers for the I2C lines
    reg [1:0] scl_sync = 2'b11;
    reg [1:0] sda_sync = 2'b11;
    always @(posedge clk) begin
        scl_sync <= {scl_sync[0], i_i2c_scl};
        sda_sync <= {sda_sync[0], i_i2c_sda};
    end
    wire filtered_scl = scl_sync[1];
    wire filtered_sda = sda_sync[1];

    // SPI slave
    wire [7:0] w_spi_rx_byte;
    wire       w_spi_rx_dv;
    reg  [7:0] r_spi_tx_byte = 8'h00;

    // I2C master
    reg        r_i2c_start = 1'b0;
    reg        r_i2c_rnw   = 1'b0;
    wire [7:0] w_i2c_data_read;
    wire       w_i2c_busy;
    wire       w_i2c_done;
    wire       w_i2c_ack_ok;

    reg [7:0]  bridge_holding_reg = 8'd0;
    reg        rx_pending         = 1'b0;
    reg        expect_readback    = 1'b0;

    localparam [1:0] BR_IDLE       = 2'd0,
                     BR_I2C_WRITE  = 2'd1,
                     BR_WAIT_SLAVE = 2'd2,
                     BR_I2C_READ   = 2'd3;
    reg [1:0]  bridge_state          = BR_IDLE;
    reg [16:0] software_wait_counter = 17'd0;

    spi_slave u_spi (
        .i_clk(clk), .i_sck(i_spi_sck), .i_mosi(i_spi_mosi),
        .o_miso(o_spi_miso), .i_ss(i_spi_ss),
        .o_rx_byte(w_spi_rx_byte), .o_rx_dv(w_spi_rx_dv),
        .o_tx_load(), .i_tx_byte(r_spi_tx_byte)
    );

    i2c_master_core #(.CLK_DIV(16'd250)) u_i2c_master (
        .i_clk(clk), .i_start(r_i2c_start), .i_rnw(r_i2c_rnw),
        .i_addr(TARGET_SLAVE_ADDR), .i_data_write(bridge_holding_reg),
        .i_sda(filtered_sda), .i_scl(filtered_scl),
        .o_scl_oe(o_i2c_scl_oe), .o_sda_oe(o_i2c_sda_oe),
        .o_data_read(w_i2c_data_read), .o_busy(w_i2c_busy),
        .o_done(w_i2c_done), .o_ack_ok(w_i2c_ack_ok)
    );

    always @(posedge clk) begin
        r_i2c_start <= 1'b0;

        if (w_spi_rx_dv) begin
            if (expect_readback) begin
                expect_readback <= 1'b0;          // discard the dummy read-back byte
            end else begin
                bridge_holding_reg <= w_spi_rx_byte;
                rx_pending         <= 1'b1;
            end
        end

        case (bridge_state)
            BR_IDLE: begin
                software_wait_counter <= 17'd0;
                if (rx_pending && !w_i2c_busy) begin
                    r_i2c_start  <= 1'b1;
                    r_i2c_rnw    <= 1'b0;         // write phase
                    rx_pending   <= 1'b0;
                    bridge_state <= BR_I2C_WRITE;
                end
            end

            BR_I2C_WRITE: begin
                if (w_i2c_done) begin
                    if (w_i2c_ack_ok) begin
                        software_wait_counter <= 17'd0;
                        bridge_state          <= BR_WAIT_SLAVE;
                    end else begin
                        r_spi_tx_byte   <= 8'hEE;
                        expect_readback <= 1'b1;
                        bridge_state    <= BR_IDLE;
                    end
                end
            end

            BR_WAIT_SLAVE: begin
                if (software_wait_counter == 17'd75_000) begin
                    r_i2c_start  <= 1'b1;
                    r_i2c_rnw    <= 1'b1;         // read phase
                    bridge_state <= BR_I2C_READ;
                end else begin
                    software_wait_counter <= software_wait_counter + 17'd1;
                end
            end

            BR_I2C_READ: begin
                if (w_i2c_done) begin
                    r_spi_tx_byte   <= w_i2c_ack_ok ? w_i2c_data_read : 8'hEE;
                    expect_readback <= 1'b1;      // next SPI byte is the dummy read
                    bridge_state    <= BR_IDLE;
                end
            end

            default: bridge_state <= BR_IDLE;
        endcase
    end
endmodule
