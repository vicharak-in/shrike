// ============================================================================
// TOP MODULE: Shrike Lite FPGA Core (ASCII to Braille + IRQ over Split CS)
// ============================================================================
(* top *) module top ( 
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *)                 output clk_en, 
    
    // QSPI Clock
    (* iopad_external_pin *) input  spi_sck, 
    
    // Split CS/IRQ Pins (No internal tristates!)
    (* iopad_external_pin *) input  spi_ss_in,  // Reads the physical CS line
    (* iopad_external_pin *) output spi_ss_out, // Drives the physical CS line
    (* iopad_external_pin *) output spi_ss_oe,  // Output Enable for CS line
    
    // Split QSPI Data Pins
    (* iopad_external_pin *) input  [3:0] qspi_rx, 
    (* iopad_external_pin *) output [3:0] qspi_tx, 
    (* iopad_external_pin *) output [3:0] qspi_oe, 

    // Status LED
    (* iopad_external_pin *) output reg led, 
    (* iopad_external_pin *) output led_en 
);

    wire rst_n = 1'b1; // Reset tied high (Always running)
    assign led_en = 1'b1;
    assign clk_en = 1'b1;

    wire [7:0] rx_data_wire;
    wire       rx_valid_pulse;
    reg  [7:0] tx_data_reg;

    // --------------------------------------------------------
    // ASCII to Braille LUT
    // --------------------------------------------------------
    wire [7:0] lower_ascii = rx_data_wire | 8'h20; 

    always @(*) begin
        case (lower_ascii)
            8'h61: tx_data_reg = 8'b00000001; // a
            8'h62: tx_data_reg = 8'b00000011; // b
            8'h63: tx_data_reg = 8'b00001001; // c
            8'h64: tx_data_reg = 8'b00011001; // d
            8'h65: tx_data_reg = 8'b00010001; // e
            8'h66: tx_data_reg = 8'b00001011; // f
            8'h67: tx_data_reg = 8'b00011011; // g
            8'h68: tx_data_reg = 8'b00010011; // h
            8'h69: tx_data_reg = 8'b00001010; // i
            8'h6a: tx_data_reg = 8'b00011010; // j
            8'h6b: tx_data_reg = 8'b00000101; // k
            8'h6c: tx_data_reg = 8'b00000111; // l
            8'h6d: tx_data_reg = 8'b00001101; // m
            8'h6e: tx_data_reg = 8'b00011101; // n
            8'h6f: tx_data_reg = 8'b00010101; // o
            8'h70: tx_data_reg = 8'b00001111; // p
            8'h71: tx_data_reg = 8'b00011111; // q
            8'h72: tx_data_reg = 8'b00010111; // r
            8'h73: tx_data_reg = 8'b00001110; // s
            8'h74: tx_data_reg = 8'b00011110; // t
            8'h75: tx_data_reg = 8'b00100101; // u
            8'h76: tx_data_reg = 8'b00100111; // v
            8'h77: tx_data_reg = 8'b00111010; // w
            8'h78: tx_data_reg = 8'b00101101; // x
            8'h79: tx_data_reg = 8'b00111101; // y
            8'h7a: tx_data_reg = 8'b00110101; // z
            8'h20: tx_data_reg = 8'b00000000; // space
            8'h3f: tx_data_reg = 8'b11110000; // '?' -> Special Alert Code
            default: tx_data_reg = 8'b11111111; // Error state
        endcase
    end

    // --------------------------------------------------------
    // Shared CS/IRQ Logic (Split Pad Open-Drain Simulation)
    // --------------------------------------------------------
    reg fpga_wants_to_talk = 0;
    
    // To interrupt the MCU, we must pull the line LOW.
    assign spi_ss_out = 1'b0; 
    
    // When OE is high, we pull the line LOW. When OE is low, the pin floats.
    assign spi_ss_oe  = fpga_wants_to_talk; 
    
    // Timer logic to generate an interrupt every 2 seconds
    reg [26:0] timer = 0; 
    
    always @(posedge clk) begin
        // If the MCU starts clocking or a transaction finishes, release OE
        if (rx_valid_pulse || spi_sck) begin
            fpga_wants_to_talk <= 1'b0;
            timer <= 0;
            led <= 1'b1; 
        end else begin
            led <= 1'b0;
            if (timer == 100_000_000) begin // 2 seconds at 50MHz
                fpga_wants_to_talk <= 1'b1; // Assert OE to pull line low
                timer <= timer;             
            end else begin
                timer <= timer + 1;
            end
        end
    end

    // --------------------------------------------------------
    // QSPI Target Instantiation
    // --------------------------------------------------------
    qspi_target u_qspi_target (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_ss_n(spi_ss_in),     // Pass the READ-BACK state from the physical pin
        .i_sck(spi_sck),
        .i_qspi_rx(qspi_rx),
        .o_qspi_tx(qspi_tx),
        .o_qspi_oe(qspi_oe),
        .o_rx_data(rx_data_wire),
        .o_rx_data_valid(rx_valid_pulse),
        .i_tx_data(tx_data_reg) 
    );
endmodule

module qspi_target (
    input  wire       i_clk,
    input  wire       i_rst_n,
    input  wire       i_ss_n,
    input  wire       i_sck,
    
    input  wire [3:0] i_qspi_rx,
    output reg  [3:0] o_qspi_tx,
    output reg  [3:0] o_qspi_oe,
    
    output reg  [7:0] o_rx_data,
    output reg        o_rx_data_valid,
    input  wire [7:0] i_tx_data
);

    localparam STATE_IDLE  = 3'd0;
    localparam STATE_RX_N1 = 3'd1;
    localparam STATE_RX_N2 = 3'd2;
    localparam STATE_TURN  = 3'd3;
    localparam STATE_TX_N1 = 3'd4;
    localparam STATE_TX_N2 = 3'd5;

    reg [2:0] state;

    // SCK & CS Synchronization Filters
    reg [2:0] sck_sync, cs_sync;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            sck_sync <= 3'b000;
            cs_sync  <= 3'b111;
        end else begin
            sck_sync <= {sck_sync[1:0], i_sck};
            cs_sync  <= {cs_sync[1:0], i_ss_n};
        end
    end

    wire sck_rising = (sck_sync[2:1] == 2'b01);
    wire cs_active  = ~cs_sync[1]; // Active Low

    // QSPI State Machine
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= STATE_IDLE;
            o_qspi_oe <= 4'b0000;
            o_rx_data <= 8'h00;
            o_rx_data_valid <= 1'b0;
            o_qspi_tx <= 4'h0;
        end else begin
            o_rx_data_valid <= 1'b0; 

            if (!cs_active) begin
                state <= STATE_IDLE;
                o_qspi_oe <= 4'b0000; // MCU has the bus
            end else if (sck_rising) begin
                case (state)
                    STATE_IDLE: begin
                        state <= STATE_RX_N1;
                        o_rx_data[7:4] <= i_qspi_rx; // RX High Nibble
                    end
                    STATE_RX_N1: begin
                        state <= STATE_RX_N2;
                        o_rx_data[3:0] <= i_qspi_rx; // RX Low Nibble
                    end
                    STATE_RX_N2: begin
                        state <= STATE_TURN;
                        o_qspi_oe <= 4'b1111;        // FPGA takes the bus (Drive all 4 pins)
                        o_rx_data_valid <= 1'b1;     // Trigger LUT lookup
                    end
                    STATE_TURN: begin
                        state <= STATE_TX_N1;
                        o_qspi_tx <= i_tx_data[7:4]; // TX High Nibble
                    end
                    STATE_TX_N1: begin
                        state <= STATE_TX_N2;
                        o_qspi_tx <= i_tx_data[3:0]; // TX Low Nibble
                    end
                    STATE_TX_N2: begin
                        state <= STATE_IDLE;
                        o_qspi_oe <= 4'b0000;        // FPGA releases the bus
                    end
                    default: begin
                        state <= STATE_IDLE;
                        o_qspi_oe <= 4'b0000;
                    end
                endcase
            end
        end
    end
endmodule