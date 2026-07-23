`timescale 1ns/1ps

module i2c_master_core # (
    parameter [15:0] CLK_DIV = 16'd250
)(
    input  wire       i_clk,
    input  wire       i_start,
    input  wire       i_rnw,         
    input  wire [6:0] i_addr,
    input  wire [7:0] i_data_write,
    input  wire       i_sda,
    input  wire       i_scl,         

    output reg        o_scl_oe    = 1'b0,
    output reg        o_sda_oe    = 1'b0,
    output reg [7:0]  o_data_read = 8'd0,
    output reg        o_busy      = 1'b0,
    output reg        o_done      = 1'b0,
    output reg        o_ack_ok    = 1'b0
);

    // State definitions
    localparam [3:0] S_IDLE       = 4'd0, 
                     S_START1     = 4'd1, 
                     S_START2     = 4'd2, 
                     S_START3     = 4'd3,
                     S_BYTE_LOW   = 4'd4, 
                     S_BYTE_HIGH  = 4'd5, 
                     S_ACK_LOW    = 4'd6, 
                     S_ACK_HIGH   = 4'd7,
                     S_ACK_FALL   = 4'd8, 
                     S_STOP_LOW   = 4'd9, 
                     S_STOP_HIGH  = 4'd10, 
                     S_STOP_FINAL = 4'd11;

    reg [3:0]  state           = S_IDLE;
    reg [15:0] div_cnt         = 16'd0;
    reg [2:0]  bit_cnt         = 3'd7;
    reg [7:0]  shifter         = 8'd0;
    reg        saved_rnw       = 1'b0;
    reg        accumulated_ack = 1'b1;
    reg        is_data_phase   = 1'b0; 

    wire phase_done     = (div_cnt == CLK_DIV - 1);
    wire scl_stretched  = (o_scl_oe == 1'b0 && i_scl == 1'b0) && (state == S_BYTE_HIGH || state == S_ACK_HIGH);

    // FSM execution loop
    always @(posedge i_clk) begin
        o_done <= 1'b0;

        if (scl_stretched) begin
            div_cnt <= 16'd0; 
        end else begin
            case (state)
                S_IDLE: begin
                    o_busy        <= 1'b0; 
                    o_scl_oe      <= 1'b0; 
                    o_sda_oe      <= 1'b0; 
                    div_cnt       <= 16'd0;
                    is_data_phase <= 1'b0;
                    
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
                    o_scl_oe <= 1'b0; 
                    o_sda_oe <= 1'b0;
                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_START2; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_START2: begin
                    o_scl_oe <= 1'b0; 
                    o_sda_oe <= 1'b1; 
                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_START3; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_START3: begin
                    o_scl_oe <= 1'b1; 
                    o_sda_oe <= 1'b1;
                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_BYTE_LOW; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_BYTE_LOW: begin
                    o_scl_oe <= 1'b1;
                    if (is_data_phase && saved_rnw)
                        o_sda_oe <= 1'b0; 
                    else
                        o_sda_oe <= ~shifter[bit_cnt];

                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_BYTE_HIGH; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_BYTE_HIGH: begin
                    o_scl_oe <= 1'b0;
                    if (phase_done) begin
                        div_cnt <= 16'd0;
                        if (is_data_phase && saved_rnw)
                            o_data_read[bit_cnt] <= i_sda; 

                        if (bit_cnt == 3'd0) begin
                            state <= S_ACK_LOW;
                        end else begin
                            bit_cnt <= bit_cnt - 3'd1;
                            state   <= S_BYTE_LOW;
                        end
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_ACK_LOW: begin
                    o_scl_oe <= 1'b1; 
                    o_sda_oe <= 1'b0; 
                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_ACK_HIGH; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_ACK_HIGH: begin
                    o_scl_oe <= 1'b0;
                    if (phase_done) begin
                        div_cnt <= 16'd0;
                        if (!(is_data_phase && saved_rnw)) begin
                            accumulated_ack <= accumulated_ack & (i_sda == 1'b0);
                        end
                        
                        if (!is_data_phase) begin
                            is_data_phase <= 1'b1;
                            shifter       <= i_data_write;
                            bit_cnt       <= 3'd7;
                            state         <= S_BYTE_LOW;
                        end else begin
                            state <= S_ACK_FALL; 
                        end
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_ACK_FALL: begin
                    o_scl_oe <= 1'b1; 
                    o_sda_oe <= 1'b0; 
                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_STOP_LOW; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_STOP_LOW: begin
                    o_scl_oe <= 1'b1; 
                    o_sda_oe <= 1'b1; 
                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_STOP_HIGH; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_STOP_HIGH: begin
                    o_scl_oe <= 1'b0; 
                    o_sda_oe <= 1'b1; 
                    if (phase_done) begin 
                        div_cnt <= 16'd0; 
                        state   <= S_STOP_FINAL; 
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                S_STOP_FINAL: begin
                    o_scl_oe <= 1'b0; 
                    o_sda_oe <= 1'b0; 
                    if (phase_done) begin
                        div_cnt  <= 16'd0;
                        o_ack_ok <= accumulated_ack;
                        o_done   <= 1'b1;
                        o_busy   <= 1'b0;
                        state    <= S_IDLE;
                    end else begin
                        div_cnt <= div_cnt + 16'd1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule