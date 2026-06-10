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
// 3. SYNCHRONOUS I2C SLAVE CORE ENGINE (Dual-Edge Handshaking)
// ============================================================
module i2c_slave_core (
    input  wire       i_clk,
    input  wire       i_scl,
    input  wire       i_sda,
    input  wire [7:0] i_tx_data,      
    output reg        o_sda_oe = 1'b0,       
    output reg [7:0]  o_rx_data = 8'h00,
    output reg        o_rx_valid = 1'b0
);
    reg [2:0] scl_r = 3'b111; reg [2:0] sda_r = 3'b111;
    always @(posedge i_clk) begin
        scl_r <= {scl_r[1:0], i_scl};
        sda_r <= {sda_r[1:0], i_sda};
    end
    
    wire scl_pos = (scl_r[2:1] == 2'b01);
    wire scl_neg = (scl_r[2:1] == 2'b10);
    wire start   = (scl_r[1] == 1'b1) && (sda_r[2:1] == 2'b10);
    wire stop    = (scl_r[1] == 1'b1) && (sda_r[2:1] == 2'b01);

    localparam [2:0] S_IDLE=3'd0, S_ADDR=3'd1, S_ACK_ADDR=3'd2, 
                     S_RX_DATA=3'd3, S_ACK_DATA=3'd4, S_TX_DATA=3'd5, S_TX_ACK=3'd6;
                     
    reg [2:0] state = S_IDLE;
    reg [3:0] bit_cnt = 4'd0;
    reg [7:0] shift_reg = 8'd0;
    reg       rnw = 1'b0;
    reg [7:0] tx_shifter = 8'd0;

    always @(posedge i_clk) begin
        o_rx_valid <= 1'b0;
        
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
                        if (shift_reg[7:1] == 7'h50) state <= S_ACK_ADDR;
                        else                         state <= S_IDLE;
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
                            o_sda_oe   <= 1'b1; 
                            o_rx_valid <= 1'b1; 
                        end else begin
                            o_sda_oe   <= 1'b0; 
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
                        bit_cnt <= 4'd0;
                        state   <= S_TX_ACK;
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

// ============================================================
// 4. TOP MODULE BRIDGE COORDINATOR (With Full Restored Attributes)
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
    (* iopad_external_pin *)                 input  wire i_i2c_scl, 
    (* iopad_external_pin *)                 output wire o_i2c_sda,
    (* iopad_external_pin *)                 output wire o_i2c_sda_oe
);
    assign clk_en       = 1'b1;
    assign o_uart_tx_oe = 1'b1;
    assign o_i2c_sda    = 1'b0; 

    wire [7:0] w_i2c_rx_data;
    wire       w_i2c_rx_valid;
    reg  [7:0] r_i2c_tx_data = 8'h00;

    wire [7:0] w_uart_rx_byte;
    wire       w_uart_rx_dv;
    reg  [7:0] r_uart_tx_byte = 8'h00;
    reg        r_uart_tx_start = 1'b0;
    wire       w_uart_tx_busy;

    localparam [1:0] BR_IDLE        = 2'd0,
                     BR_UART_LAUNCH = 2'd1,
                     BR_UART_WAIT   = 2'd2,
                     BR_UART_RX     = 2'd3;
                     
    reg [1:0] bridge_state = BR_IDLE;

    uart_rx #(.CLKS_PER_BIT(9'd434)) u_uart_receiver (
        .i_clk(clk), .i_rx(i_uart_rx), .o_rx_byte(w_uart_rx_byte), .o_rx_dv(w_uart_rx_dv)
    );

    uart_tx #(.CLKS_PER_BIT(9'd434)) u_uart_transmitter (
        .i_clk(clk), .i_tx_start(r_uart_tx_start), .i_tx_byte(r_uart_tx_byte),
        .o_tx_serial(o_uart_tx), .o_tx_busy(w_uart_tx_busy)
    );

    i2c_slave_core u_i2c_slave (
        .i_clk(clk), .i_scl(i_i2c_scl), .i_sda(i_i2c_sda), .i_tx_data(r_i2c_tx_data),
        .o_sda_oe(o_i2c_sda_oe), .o_rx_data(w_i2c_rx_data), .o_rx_valid(w_i2c_rx_valid)
    );

    always @(posedge clk) begin
        r_uart_tx_start <= 1'b0;

        case (bridge_state)
            BR_IDLE: begin
                if (w_i2c_rx_valid) begin
                    r_uart_tx_byte  <= w_i2c_rx_data; 
                    r_uart_tx_start <= 1'b1;
                    bridge_state    <= BR_UART_LAUNCH;
                end
            end

            BR_UART_LAUNCH: begin
                bridge_state <= BR_UART_WAIT; 
            end

            BR_UART_WAIT: begin
                if (!w_uart_tx_busy) begin
                    bridge_state <= BR_UART_RX; 
                end
            end

            BR_UART_RX: begin
                if (w_uart_rx_dv) begin
                    r_i2c_tx_data <= w_uart_rx_byte; 
                    bridge_state  <= BR_IDLE;        
                end
            end
            default: bridge_state <= BR_IDLE;
        endcase
    end
endmodule