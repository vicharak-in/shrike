// top -- USB-to-SPI bridge top level for Shrike-Lite (RP2040 + ForgeFPGA).
//
// Data path: PC USB -> RP2040 (SPI master) -> FPGA (this design) -> external
// SPI slave (e.g. Arduino). The FPGA is an SPI *target* on the fixed RP2040
// link and an SPI *master* on free GPIOs out to the external device, so it
// forwards every byte the RP2040 sends and returns the external slave's reply
// on the next transfer (store-and-forward, one transfer of latency).
//
// Sub-modules: spi_target (slave to RP2040) and spi_master (master to the
// external device). An internal power-on reset releases the design after the
// oscillator is stable; there is no external reset pin.
//
// FPGA pin map (Shrike FPGA GPIO numbers):
//   spi_sck=3(in)  spi_ss_n=4(in)  spi_mosi=5(in)  spi_miso=6(out)  led=16(out)
//   m_sck=0(out)   m_mosi=1(out)   m_ss_n=7(out)   m_miso=8(in)
(* top *) module top (
(* iopad_external_pin, clkbuf_inhibit *) input  clk,
(* iopad_external_pin *) output clk_en,
(* iopad_external_pin *) input spi_ss_n,
(* iopad_external_pin *) input spi_sck,
(* iopad_external_pin *) input spi_mosi,
(* iopad_external_pin *) output spi_miso,
(* iopad_external_pin *) output spi_miso_en,
(* iopad_external_pin *) output m_ss_n,
(* iopad_external_pin *) output m_ss_n_en,
(* iopad_external_pin *) output m_sck,
(* iopad_external_pin *) output m_sck_en,
(* iopad_external_pin *) output m_mosi,
(* iopad_external_pin *) output m_mosi_en,
(* iopad_external_pin *) input m_miso,
(* iopad_external_pin *) output reg led,
(* iopad_external_pin *) output led_en);
assign clk_en = 1'b1;
assign led_en = 1'b1;
assign m_ss_n_en = 1'b1;
assign m_sck_en = 1'b1;
assign m_mosi_en = 1'b1;
reg [3:0] por_cnt = 4'd0;
reg rst_n = 1'b0;
always @(posedge clk) begin
        if (por_cnt != 4'hF) por_cnt <= por_cnt + 1'b1;
        rst_n <= (por_cnt == 4'hF);
    end

    wire [7:0] rx_data;
    wire rx_valid;

    wire [7:0] m_rx_data;
    wire m_busy;
    wire m_done;

    reg [7:0] m_tx_data;      
    reg m_start;      
    reg [7:0] return_data;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_tx_data <= 8'h00;
            m_start <= 1'b0;
        end else begin
            m_start <= 1'b0;
            if (rx_valid && !m_busy && !m_start) begin
                m_tx_data <= rx_data;
                m_start <= 1'b1;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) return_data <= 8'h00;
        else if (m_done) return_data <= m_rx_data;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) led <= 1'b0;
        else if (rx_valid) led <= rx_data[0];
    end
    spi_target #(
        .CPOL (1'b0), .CPHA (1'b0), .WIDTH (8), .LSB (1'b0)
    ) u_spi_slave (
        .i_clk(clk),.i_rst_n(rst_n),.i_enable(1'b1),.i_ss_n  (spi_ss_n),
        .i_sck(spi_sck),.i_mosi(spi_mosi),
        .o_miso(spi_miso),
        .o_miso_oe(spi_miso_en),
        .o_rx_data(rx_data),
        .o_rx_data_valid(rx_valid),
        .i_tx_data(return_data),
        .o_tx_data_hold());
    spi_master #(
        .WIDTH (8), .CLK_DIV (64)
    ) u_spi_master (.i_clk(clk),.i_rst_n(rst_n),.i_start(m_start),
        .i_tx_data(m_tx_data),.o_rx_data(m_rx_data),
        .o_busy(m_busy),.o_done(m_done),
        .o_ss_n(m_ss_n),.o_sck(m_sck),.o_mosi(m_mosi),.i_miso(m_miso));
endmodule