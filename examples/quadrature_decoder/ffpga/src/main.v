(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input       clk,

    (* iopad_external_pin *) input       enc_a,
    (* iopad_external_pin *) input       enc_b,

    (* iopad_external_pin *) output      uart_tx,
    (* iopad_external_pin *) output		uart_tx_en,
    (* iopad_external_pin *) output		clk_en
);

assign clk_en = 1'b1;
assign uart_tx_en = 1'b1;

parameter WIDTH        = 16;
parameter CLK_FREQ     = 50_000_000;
parameter UPDATE_MS    = 500;        // update every time at this value
parameter CPR          = 4000;       // counts per revolution (4x decoding)

// Wires from quad decoder
wire signed [15:0] position;
wire signed [15:0] speed;
wire [15:0] angle;
wire direction;
wire data_valid;

// Instantiate Quadrature Decoder
quadrature_decoder #(
    .WIDTH       (WIDTH),
    .CLK_FREQ    (CLK_FREQ),
    .UPDATE_MS   (UPDATE_MS),
    .CPR         (CPR)
) QUAD_DEC_INST (
    .clk         (clk),
    .rst         (1'b0),
    .enc_a       (enc_a),
    .enc_b       (enc_b),
    .position    (position),
    .speed       (speed),
    .angle       (angle),
    .direction   (direction),
    .data_valid  (data_valid)
);

// UART TX wires
wire uart_busy;
wire uart_active;
wire uart_dv;
wire [7:0] uart_byte;

// Instantiate Packet Sender
uart_packetizer PKT_SENDER (
    .clk         (clk),
    .position    (position),
    .speed       (speed),
    .angle       (angle),
    .direction   (direction),
    .data_valid  (data_valid),
    .uart_busy   (uart_active),
    .uart_dv     (uart_dv),
    .uart_byte   (uart_byte)
);

// Instantiate UART TX
uart_tx #(
    .CLKS_PER_BIT(434) // 50MHz / 115200
) UART_TX (
    .rst         (1'b1),
    .clk         (clk),
    .i_TX_DV     (uart_dv),
    .i_TX_Byte   (uart_byte),
    .o_TX_Active (uart_active),
    .o_TX_Serial (uart_tx),
    .o_TX_Done   ()
);

endmodule