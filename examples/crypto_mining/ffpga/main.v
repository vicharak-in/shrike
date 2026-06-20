/*
 * ============================================================================
 * SPONGENT-88 ASIC MINER - HARDWARE DESIGN
 * ============================================================================
 * This file contains the complete Verilog implementation of the SPONGENT-88 
 * cryptographic hash function, optimized for custom FPGA silicon.
 * * Key Engineering Features:
 * 1. Deep Combinatorial Logic: Executes XOR, S-Box lookups, and Bit Permutations 
 * within a single clock cycle.
 * 2. Asynchronous Memory Locks: Prevents SPI-bus polling requests from corrupting 
 * active hash states during long block computations.
 * 3. Custom Dual-SPI: Uses a half-duplex, dual-lane SPI implementation for 
 * rapid payload injection.
 */

// ============================================================================
// TOP MODULE: External Pin Routing
// ============================================================================
(* top *) module top ( 
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *)                 output clk_en, 
    (* iopad_external_pin *) input  spi_sck, 
    (* iopad_external_pin *) input  spi_ss_in,  
    (* iopad_external_pin *) output spi_ss_out, 
    (* iopad_external_pin *) output spi_ss_oe,  
    (* iopad_external_pin *) input  [1:0] dual_rx, 
    (* iopad_external_pin *) output [1:0] dual_tx, 
    (* iopad_external_pin *) output [1:0] dual_oe, 
    (* iopad_external_pin *) output wire led, 
    (* iopad_external_pin *) output wire led_en 
);
    assign clk_en = 1'b1;
    assign led_en = 1'b1;

    // Internal routing wires
    wire [7:0] rx_data_wire;
    wire       rx_valid_pulse;
    wire [7:0] miner_dout;
    
    wire       cs_start_pulse;
    wire       cs_end_pulse;
    wire       mining_done_flag;
    wire [1:0] tx_byte_sel_wire; 

    // LED illuminates while computing, turns off when proof-of-work is found
    assign led = ~mining_done_flag; 
    assign spi_ss_out = 1'b0; 
    assign spi_ss_oe  = 1'b0; 
    
    // Instantiate SPI Target Module
    dual_spi_target u_target (
        .i_clk(clk),
        .i_ss_n(spi_ss_in),     
        .i_sck(spi_sck),
        .i_dual_rx(dual_rx),
        .o_dual_tx(dual_tx),
        .o_dual_oe(dual_oe),
        .o_rx_data(rx_data_wire),
        .o_rx_data_valid(rx_valid_pulse),
        .i_tx_data(miner_dout),
        .o_cs_start(cs_start_pulse),
        .o_cs_end(cs_end_pulse),
        .o_tx_byte_sel(tx_byte_sel_wire)
    );
    
    // Instantiate SPONGENT Cryptographic Engine
    spongent_miner_engine u_miner (
        .clk(clk),
        .din(rx_data_wire),
        .din_valid(rx_valid_pulse),
        .cs_start(cs_start_pulse),
        .cs_end(cs_end_pulse),
        .tx_byte_sel(tx_byte_sel_wire), 
        .dout(miner_dout),
        .done_flag(mining_done_flag)
    );
endmodule

// ============================================================================
// CRYPTO MODULE: SPONGENT-88 Engine
// ============================================================================
module spongent_miner_engine (
    input  wire       clk,
    input  wire [7:0] din,
    input  wire       din_valid,
    input  wire       cs_start,
    input  wire       cs_end,
    input  wire [1:0] tx_byte_sel, 
    output reg  [7:0] dout,
    output reg        done_flag
);
    // Memory Registers
    reg [63:0] rx_shift = 64'h0;
    reg [3:0]  payload_len = 4'd0;

    reg [31:0] current_nonce = 32'h0;
    reg [31:0] winning_nonce = 32'h0;
    
    // State Machine Controls
    reg [1:0]  state = 2'd0;
    localparam S_IDLE = 2'd0, S_HASH = 2'd1, S_CHECK = 2'd2;
    
    reg [5:0]  round_cnt = 6'd0;
    reg [87:0] hash_state = 88'h0;

    // PRESENT S-Box Function (Combinatorial Look-Up Table)
    function [3:0] sbox4(input [3:0] din_val);
        case(din_val)
            4'h0: sbox4 = 4'hC; 4'h1: sbox4 = 4'h5; 4'h2: sbox4 = 4'h6; 4'h3: sbox4 = 4'hB;
            4'h4: sbox4 = 4'h9; 4'h5: sbox4 = 4'h0; 4'h6: sbox4 = 4'hA; 4'h7: sbox4 = 4'hD;
            4'h8: sbox4 = 4'h3; 4'h9: sbox4 = 4'hE; 4'hA: sbox4 = 4'hF; 4'hB: sbox4 = 4'h8;
            4'hC: sbox4 = 4'h4; 4'hD: sbox4 = 4'h7; 4'hE: sbox4 = 4'h1; 4'hF: sbox4 = 4'h2;
            default: sbox4 = 4'h0;
        endcase
    endfunction

    // 1-Cycle Spongent Math Block (XOR -> S-Box -> Bit Permutation)
    function [87:0] spongent_round;
        input [87:0] s_in;
        input [5:0]  r_in;
        reg [87:0] add_rc;
        reg [87:0] s_out;
        reg [87:0] p_out;
        integer j;
        begin
            add_rc = s_in ^ {82'h0, r_in};
            for(j=0; j<22; j=j+1) begin
                s_out[j*4 +: 4] = sbox4(add_rc[j*4 +: 4]);
            end
            for (j=0; j<44; j=j+1) begin
                p_out[j+44] = s_out[j*2 + 1];
                p_out[j]    = s_out[j*2];
            end
            spongent_round = p_out;
        end
    endfunction

    // Main Clock Edge Trigger
    always @(posedge clk) begin
        if (cs_start) begin
            payload_len <= 4'd0;
        end

        // FIX: The Memory Lock. 
        // We strictly require (state == S_IDLE) before modifying rx_shift.
        // This prevents the MCU's status polls from overwriting the block 
        // prefix memory while the engine is actively computing long hashes.
        if (din_valid && state == S_IDLE) begin
            rx_shift <= {rx_shift[55:0], din};
            if (payload_len < 4'd15) payload_len <= payload_len + 1'b1;
        end

        // Payload Execution Start
        if (cs_end && payload_len >= 4'd6 && state == S_IDLE) begin
            state <= S_HASH;
            round_cnt <= 6'd0;
            current_nonce <= rx_shift[31:0];
            hash_state <= {24'h0, rx_shift[63:32], rx_shift[31:0]};
            done_flag <= 1'b0; 
            
        // 45-Round Hashing Loop
        end else if (state == S_HASH) begin
            if (round_cnt == 6'd45) begin
                state <= S_CHECK;
            end else begin
                hash_state <= spongent_round(hash_state, round_cnt);
                round_cnt <= round_cnt + 1'b1;
            end
            
        // Validation Check
        end else if (state == S_CHECK) begin
            // Check for 16 leading zero bits
            if (hash_state[87:72] == 16'h0000) begin
                winning_nonce <= current_nonce;
                done_flag <= 1'b1; 
                state <= S_IDLE; // Workload Complete
            end else begin
                // Invalid hash. Increment nonce and loop immediately.
                current_nonce <= current_nonce + 1'b1;
                hash_state <= {24'h0, rx_shift[63:32], current_nonce + 1'b1};
                round_cnt <= 6'd0;
                state <= S_HASH;
            end
        end
    end

    // SPI Output Routing (Streams the 4-byte nonce back to MCU upon request)
    always @(*) begin
        if (done_flag) begin
            case (tx_byte_sel)
                2'd0: dout = winning_nonce[31:24];
                2'd1: dout = winning_nonce[23:16];
                2'd2: dout = winning_nonce[15:8];
                2'd3: dout = winning_nonce[7:0];
            endcase
        end else begin
            dout = 8'h00; 
        end
    end
endmodule

// ============================================================================
// INTERNAL MODULE: Dual-SPI Target FSM 
// ============================================================================
module dual_spi_target (
    input  wire       i_clk,
    input  wire       i_ss_n,
    input  wire       i_sck,
    input  wire [1:0] i_dual_rx,
    output wire [1:0] o_dual_tx, 
    output wire [1:0] o_dual_oe, 
    output reg  [7:0] o_rx_data = 8'h00,
    output reg        o_rx_data_valid = 1'b0,
    input  wire [7:0] i_tx_data,
    output wire       o_cs_start,
    output wire       o_cs_end,
    output wire [1:0] o_tx_byte_sel 
);
    reg [2:0] sck_sync = 3'b000; 
    reg [2:0] cs_sync = 3'b111;

    // Clock edge detection (Domain crossing prevention)
    always @(posedge i_clk) begin
        sck_sync <= {sck_sync[1:0], i_sck};
        cs_sync  <= {cs_sync[1:0], i_ss_n};
    end

    assign o_cs_start = (cs_sync[2:1] == 2'b10); 
    assign o_cs_end   = (cs_sync[2:1] == 2'b01); 
    
    wire cs_active   = ~cs_sync[1]; 
    wire sck_rising  = (sck_sync[2:1] == 2'b01); 
    wire sck_falling = (sck_sync[2:1] == 2'b10);

    reg [2:0] rx_clk_cnt = 3'd0; 
    reg [1:0] byte_cnt = 2'd0; 
    
    // Shift Register Control
    always @(posedge i_clk) begin
        o_rx_data_valid <= 1'b0;
        if (!cs_active) begin
            rx_clk_cnt <= 3'd0;
            byte_cnt <= 2'd0;
        end else begin
            if (sck_rising) begin
                if (rx_clk_cnt < 3'd4) begin
                    o_rx_data <= {o_rx_data[5:0], i_dual_rx};
                end
                
                if (rx_clk_cnt == 3'd3) begin
                    o_rx_data_valid <= 1'b1;
                end
            end
            
            if (sck_falling) begin
                rx_clk_cnt <= rx_clk_cnt + 1'b1;
                if (rx_clk_cnt == 3'd7) begin
                    byte_cnt <= byte_cnt + 1'b1;
                end
            end
        end
    end

    assign o_tx_byte_sel = byte_cnt;
    assign o_dual_oe = (cs_active && rx_clk_cnt >= 3'd4) ? 2'b11 : 2'b00;
    
    reg [1:0] tx_comb;
    always @(*) begin
        case(rx_clk_cnt)
            3'd4: tx_comb = i_tx_data[7:6];
            3'd5: tx_comb = i_tx_data[5:4];
            3'd6: tx_comb = i_tx_data[3:2];
            3'd7: tx_comb = i_tx_data[1:0];
            default: tx_comb = 2'b00;
        endcase
    end
    assign o_dual_tx = tx_comb;
endmodule