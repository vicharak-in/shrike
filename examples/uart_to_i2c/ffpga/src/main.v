`timescale 1ns/1ps

// ============================================================
// 1. UART RX MODULE
// ============================================================
module uart_rx #(
    parameter [8:0] CLKS_PER_BIT = 9'd434
)(
    input  wire       i_clk,
    input  wire       i_rx,
    output reg [7:0]  o_rx_byte,
    output reg        o_rx_dv
);
    localparam [2:0] IDLE = 3'd0, START = 3'd1, DATA = 3'd2, STOP = 3'd3, CLEANUP = 3'd4;
    reg [2:0] state = IDLE;
    reg [8:0] clk_cnt = 9'd0;
    reg [2:0] bit_idx = 3'd0;
    reg [7:0] rx_shift = 8'd0;
    reg rx_ff1 = 1'b1; reg rx_ff2 = 1'b1;

    always @(posedge i_clk) begin
        rx_ff1 <= i_rx;
        rx_ff2 <= rx_ff1;
    end

    always @(posedge i_clk) begin
        o_rx_dv <= 1'b0;
        case (state)
            IDLE: begin
                clk_cnt <= 9'd0; bit_idx <= 3'd0;
                if (rx_ff2 == 1'b0) state <= START;
            end
            START: begin
                if (clk_cnt == (CLKS_PER_BIT >> 1) - 1) begin
                    if (rx_ff2 == 1'b0) begin clk_cnt <= 9'd0; state <= DATA; end
                    else state <= IDLE;
                end else clk_cnt <= clk_cnt + 9'd1;
            end
            DATA: begin
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt <= 9'd0; rx_shift[bit_idx] <= rx_ff2;
                    if (bit_idx == 3'd7) begin bit_idx <= 3'd0; state <= STOP; end
                    else bit_idx <= bit_idx + 3'd1;
                end else clk_cnt <= clk_cnt + 9'd1;
            end
            STOP: begin
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt <= 9'd0; o_rx_byte <= rx_shift; o_rx_dv <= 1'b1; state <= CLEANUP;
                end else clk_cnt <= clk_cnt + 9'd1;
            end
            CLEANUP: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule

// ============================================================
// 2. UART TX MODULE
// ============================================================
module uart_tx #(
    parameter [8:0] CLKS_PER_BIT = 9'd434
)(
    input  wire       i_clk,
    input  wire       i_tx_start,
    input  wire [7:0] i_tx_byte,
    output reg        o_tx_serial,
    output reg        o_tx_busy
);
    localparam [2:0] IDLE = 3'd0, START = 3'd1, DATA = 3'd2, STOP = 3'd3, CLEANUP = 3'd4;
    reg [2:0] state = IDLE;
    reg [8:0] clk_cnt = 9'd0;
    reg [2:0] bit_idx = 3'd0;
    reg [7:0] tx_shift = 8'd0;

    always @(posedge i_clk) begin
        case (state)
            IDLE: begin
                o_tx_serial <= 1'b1; o_tx_busy <= 1'b0; clk_cnt <= 9'd0; bit_idx <= 3'd0;
                if (i_tx_start) begin tx_shift <= i_tx_byte; o_tx_busy <= 1'b1; state <= START; end
            end
            START: begin
                o_tx_serial <= 1'b0;
                if (clk_cnt == CLKS_PER_BIT - 1) begin clk_cnt <= 9'd0; state <= DATA; end
                else clk_cnt <= clk_cnt + 9'd1;
            end
            DATA: begin
                o_tx_serial <= tx_shift[bit_idx];
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt <= 9'd0;
                    if (bit_idx == 3'd7) begin bit_idx <= 3'd0; state <= STOP; end
                    else bit_idx <= bit_idx + 3'd1;
                end else clk_cnt <= clk_cnt + 9'd1;
            end
            STOP: begin
                o_tx_serial <= 1'b1;
                if (clk_cnt == CLKS_PER_BIT - 1) begin clk_cnt <= 9'd0; state <= CLEANUP; end
                else clk_cnt <= clk_cnt + 9'd1;
            end
            CLEANUP: begin o_tx_busy <= 1'b0; state <= IDLE; end
            default: state <= IDLE;
        endcase
    end
endmodule

// ============================================================
// 3. COMPLETE I2C CORE WITH CLOCK STRETCHING SUPPORT
// ============================================================
module i2c_master_core #(
    parameter [15:0] CLK_DIV = 16'd250
)(
    input  wire       i_clk,
    input  wire       i_start,
    input  wire       i_rnw,         
    input  wire [6:0] i_addr,
    input  wire [7:0] i_data_write,
    input  wire       i_sda,
    input  wire       i_scl,         // Monitor pin for Clock Stretching detection

    output reg        o_scl_oe = 1'b0,
    output reg        o_sda_oe = 1'b0,

    output reg [7:0]  o_data_read = 8'd0,
    output reg        o_busy = 1'b0,
    output reg        o_done = 1'b0,
    output reg        o_ack_ok = 1'b0
);
    localparam [3:0] S_IDLE=4'd0, S_START1=4'd1, S_START2=4'd2, S_START3=4'd3,
                     S_BYTE_LOW=4'd4, S_BYTE_HIGH=4'd5, S_ACK_LOW=4'd6, S_ACK_HIGH=4'd7,
                     S_ACK_FALL=4'd8, S_STOP_LOW=4'd9, S_STOP_HIGH=4'd10, S_STOP_FINAL=4'd11;

    reg [3:0]  state = S_IDLE;
    reg [15:0] div_cnt = 16'd0;
    reg [2:0]  bit_cnt = 3'd7;
    reg [7:0]  shifter = 8'd0;
    reg        saved_rnw = 1'b0;
    reg        accumulated_ack = 1'b1;

    wire phase_done = (div_cnt == CLK_DIV - 1);
    
    // Freeze the timebase if the FPGA master releases SCL high, but the slave holds it low
    wire scl_stretched = (o_scl_oe == 1'b0 && i_scl == 1'b0);

    always @(posedge i_clk) begin
        o_done <= 1'b0;

        if (scl_stretched) begin
            div_cnt <= 16'd0; // Freeze counter until slave lets go of SCL
        end else begin
            case (state)
                S_IDLE: begin
                    o_busy <= 1'b0; o_scl_oe <= 1'b0; o_sda_oe <= 1'b0; div_cnt <= 16'd0;
                    if (i_start) begin
                        o_busy          <= 1'b1;
                        o_ack_ok        <= 1'b0;
                        saved_rnw       <= i_rnw;
                        shifter         <= {i_addr, i_rnw};
                        accumulated_ack <= 1'b1;
                        bit_cnt         <= 3'd7;
                        state           <= S_START1;
                    end
                end

                S_START1: begin
                    o_scl_oe <= 1'b0; o_sda_oe <= 1'b0;
                    if (phase_done) begin div_cnt <= 16'd0; state <= S_START2; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_START2: begin
                    o_scl_oe <= 1'b0; o_sda_oe <= 1'b1; 
                    if (phase_done) begin div_cnt <= 16'd0; state <= S_START3; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_START3: begin
                    o_scl_oe <= 1'b1; o_sda_oe <= 1'b1;
                    if (phase_done) begin div_cnt <= 16'd0; state <= S_BYTE_LOW; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_BYTE_LOW: begin
                    o_scl_oe <= 1'b1;
                    if (shifter == i_data_write && saved_rnw)
                        o_sda_oe <= 1'b0; 
                    else
                        o_sda_oe <= ~shifter[bit_cnt];

                    if (phase_done) begin div_cnt <= 16'd0; state <= S_BYTE_HIGH; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_BYTE_HIGH: begin
                    o_scl_oe <= 1'b0;
                    if (phase_done) begin
                        div_cnt <= 16'd0;
                        if (shifter == i_data_write && saved_rnw)
                            o_data_read[bit_cnt] <= i_sda; // Fixed compilation bug variable map

                        if (bit_cnt == 3'd0) begin
                            state <= S_ACK_LOW;
                        end else begin
                            bit_cnt <= bit_cnt - 3'd1;
                            state   <= S_BYTE_LOW;
                        end
                    end else div_cnt <= div_cnt + 16'd1;
                end

                S_ACK_LOW: begin
                    o_scl_oe <= 1'b1;
                    o_sda_oe <= 1'b0; 
                    if (phase_done) begin div_cnt <= 16'd0; state <= S_ACK_HIGH; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_ACK_HIGH: begin
                    o_scl_oe <= 1'b0;
                    if (phase_done) begin
                        div_cnt <= 16'd0;
                        if (!(shifter == i_data_write && saved_rnw)) begin
                            accumulated_ack <= accumulated_ack & (i_sda == 1'b0);
                        end
                        
                        if (shifter == {i_addr, saved_rnw}) begin
                            shifter <= i_data_write;
                            bit_cnt <= 3'd7;
                            state   <= S_BYTE_LOW;
                        end else begin
                            state <= S_ACK_FALL; // Safely exit the ACK cycle first
                        end
                    end else div_cnt <= div_cnt + 16'd1;
                end

                S_ACK_FALL: begin
                    o_scl_oe <= 1'b1; o_sda_oe <= 1'b0; // Drop SCL low while keeping SDA open
                    if (phase_done) begin div_cnt <= 16'd0; state <= S_STOP_LOW; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_STOP_LOW: begin
                    o_scl_oe <= 1'b1; o_sda_oe <= 1'b1; // Clamp SDA low safely while SCL is already low
                    if (phase_done) begin div_cnt <= 16'd0; state <= S_STOP_HIGH; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_STOP_HIGH: begin
                    o_scl_oe <= 1'b0; o_sda_oe <= 1'b1; // Release SCL high while holding SDA low
                    if (phase_done) begin div_cnt <= 16'd0; state <= S_STOP_FINAL; end
                    else div_cnt <= div_cnt + 16'd1;
                end

                S_STOP_FINAL: begin
                    o_scl_oe <= 1'b0; o_sda_oe <= 1'b0; // Release SDA high -> Glitch-Free True Stop Condition
                    if (phase_done) begin
                        div_cnt  <= 16'd0;
                        o_ack_ok <= accumulated_ack;
                        o_done   <= 1'b1;
                        o_busy   <= 1'b0;
                        state    <= S_IDLE;
                    end else div_cnt <= div_cnt + 16'd1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

// ============================================================
// 4. TOP MODULE WIRE ASSIGNMENTS
// ============================================================
(* top *)
module top (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *)                 output wire clk_en,

    // UART Hardware Ports
    (* iopad_external_pin *)                 input  wire i_uart_rx,
    (* iopad_external_pin *)                 output wire o_uart_tx,
    (* iopad_external_pin *)                 output wire o_uart_tx_oe,

    // I2C Hardware Ports
    (* iopad_external_pin *)                 input  wire i_i2c_sda,
    (* iopad_external_pin *)                 input  wire i_i2c_scl, // NEW: Added input capture for SCL
    (* iopad_external_pin *)                 output wire o_i2c_scl,
    (* iopad_external_pin *)                 output wire o_i2c_scl_oe,
    (* iopad_external_pin *)                 output wire o_i2c_sda,
    (* iopad_external_pin *)                 output wire o_i2c_sda_oe
);
    assign clk_en       = 1'b1;
    assign o_uart_tx_oe = 1'b1;
    
    assign o_i2c_scl    = 1'b0; 
    assign o_i2c_sda    = 1'b0;

    localparam [6:0] I2C_ADDR = 7'h50;

    wire [7:0] w_uart_byte;
    wire       w_uart_dv;

    reg        r_i2c_start = 1'b0;
    reg        r_i2c_rnw   = 1'b0;
    wire [7:0] w_i2c_data_read;
    wire       w_i2c_busy;
    wire       w_i2c_done;
    wire       w_i2c_ack_ok;

    reg [7:0]  r_uart_tx_byte  = 8'd0;
    reg        r_uart_tx_start = 1'b0;
    wire       w_uart_tx_busy;

    reg [7:0]  bridge_holding_reg = 8'd0;
    reg        rx_pending = 1'b0;

    localparam [1:0] BR_IDLE       = 2'd0,
                     BR_I2C_WRITE  = 2'd1,
                     BR_I2C_READ   = 2'd2,
                     BR_UART_ECHO  = 2'd3;

    reg [1:0] bridge_state = BR_IDLE;

    uart_rx #(.CLKS_PER_BIT(9'd434)) u_uart_receiver (
        .i_clk(clk), .i_rx(i_uart_rx), .o_rx_byte(w_uart_byte), .o_rx_dv(w_uart_dv)
    );

    uart_tx #(.CLKS_PER_BIT(9'd434)) u_uart_transmitter (
        .i_clk(clk), .i_tx_start(r_uart_tx_start), .i_tx_byte(r_uart_tx_byte),
        .o_tx_serial(o_uart_tx), .o_tx_busy(w_uart_tx_busy)
    );

    i2c_master_core #(.CLK_DIV(16'd250)) u_i2c_master (
        .i_clk(clk), .i_start(r_i2c_start), .i_rnw(r_i2c_rnw), .i_addr(I2C_ADDR),
        .i_data_write(bridge_holding_reg), .i_sda(i_i2c_sda), .i_scl(i_i2c_scl),
        .o_scl_oe(o_i2c_scl_oe), .o_sda_oe(o_i2c_sda_oe), .o_data_read(w_i2c_data_read), 
        .o_busy(w_i2c_busy), .o_done(w_i2c_done), .o_ack_ok(w_i2c_ack_ok)
    );

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
            default: bridge_state <= BR_IDLE;
        endcase
    end
endmodule