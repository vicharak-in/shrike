// top.v
// Author: Yash Sharda
// Top-level module for the CORDIC math coprocessor.
// Receives an 8-bit command byte over SPI. The top 2 bits select the operation
// and the lower 6 bits carry the operand(s).
//
// Mode encoding:
//   2'b00  Cosine of angle (bits [5:0])
//   2'b01  Sine of angle (bits [5:0])
//   2'b10  Multiply: operand A = bits [5:3], operand B = bits [2:0]
//   2'b11  Tangent: sin/cos using the same angle as modes 00/01

(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input  clk,
    (* iopad_external_pin *)                 output clk_en,
    (* iopad_external_pin *)                 input  rst_n,

    (* iopad_external_pin *) input  spi_ss_n,
    (* iopad_external_pin *) input  spi_sck,
    (* iopad_external_pin *) input  spi_mosi,
    (* iopad_external_pin *) output spi_miso,
    (* iopad_external_pin *) output spi_miso_en
);

    assign clk_en = 1'b1;

    // SPI interconnect
    wire [7:0] rx_data;
    wire       rx_valid;
    reg  [7:0] tx_data;
    wire       tx_hold;

    // Decoded command fields
    reg [1:0] mode_reg;
    reg [5:0] data_reg;
    reg       engine_start;

    // Circular core outputs
    wire signed [7:0] circ_cos;
    wire signed [7:0] circ_sin;
    wire              circ_done;

    // Multiply core output
    wire signed [7:0] mult_out;
    wire              mult_done;

    // Divide core output (tangent)
    wire signed [7:0] div_out;
    wire              div_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            engine_start <= 1'b0;
            mode_reg     <= 2'b00;
            data_reg     <= 6'b000000;
        end else begin
            engine_start <= 1'b0; 
            if (rx_valid) begin
                mode_reg     <= rx_data[7:6]; // operation select
                data_reg     <= rx_data[5:0]; // operand payload
                engine_start <= 1'b1;
            end
        end
    end

    always @(*) begin
        case (mode_reg)
            2'b00:   tx_data = circ_cos;
            2'b01:   tx_data = circ_sin;
            2'b10:   tx_data = mult_out;
            2'b11:   tx_data = div_out;
            default: tx_data = 8'h00;
        endcase
    end

    // SPI target
    spi_target #(
        .CPOL(1'b0),
        .CPHA(1'b0),
        .WIDTH(8),
        .LSB(1'b0)
    ) U_SPI_TARGET (
        .i_clk          (clk),
        .i_rst_n        (rst_n),
        .i_enable       (1'b1),
        .i_ss_n         (spi_ss_n),
        .i_sck          (spi_sck),
        .i_mosi         (spi_mosi),
        .o_miso         (spi_miso),
        .o_miso_oe      (spi_miso_en),
        .o_rx_data      (rx_data),
        .o_rx_data_valid(rx_valid),
        .i_tx_data      (tx_data),
        .o_tx_data_hold (tx_hold)
    );

    // Circular CORDIC: computes sin and cos, active for modes 00, 01, 11
    cordic_circular U_CIRCULAR (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (engine_start && (mode_reg != 2'b10)),
        .angle_in({ 2'b00, data_reg }), // zero-pad top 2 bits, no sign extension
        .cos_out (circ_cos),
        .sin_out (circ_sin),
        .done    (circ_done)
    );

    // Multiply CORDIC: active for mode 10, operands packed into the 6-bit payload
    cordic_multiply U_MULTIPLY (
        .clk   (clk),
        .rst_n (rst_n),
        .start (engine_start && (mode_reg == 2'b10)),
        .in1   ({ {5{data_reg[5]}}, data_reg[5:3] }), // sign-extend upper 3 bits
        .in2   ({ {5{data_reg[2]}}, data_reg[2:0] }), // sign-extend lower 3 bits
        .out   (mult_out),
        .done  (mult_done)
    );

    // Divide CORDIC: computes sin/cos (tangent), from U_CIRCULAR in mode 11
    cordic_divide U_DIVIDE (
        .clk   (clk),
        .rst_n (rst_n),
        .start (circ_done && (mode_reg == 2'b11)),
        .in_y  (circ_sin), // numerator
        .in_x  (circ_cos), // denominator
        .out_z (div_out),
        .done  (div_done)
    );

endmodule
