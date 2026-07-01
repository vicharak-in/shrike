// -----------------------------------------------------------------------------
// Module: nec_decoder
// Description: Decodes NEC protocol IR signals received from a TSOP sensor.
//              It measures mark/space durations to detect leader codes, bits,
//              and repeat codes, and outputs the decoded 8-bit address and command.
// -----------------------------------------------------------------------------
module nec_decoder (
    input i_clk,
    input tsop_in,
    output reg [7:0] rx_addr = 8'd0,
    output reg [7:0] rx_cmd = 8'd0,
    output reg rx_valid = 1'b0,
    output reg rx_repeat = 1'b0,
    output [2:0] dbg_state,
    output [4:0] dbg_bit_idx
  );

  // Synchronize and edge-detect the asynchronous tsop_in signal
  reg tsop_s1 = 1'b1, tsop_s2 = 1'b1, tsop_s3 = 1'b1;
  always @(posedge i_clk)
  begin
    tsop_s1 <= tsop_in;
    tsop_s2 <= tsop_s1;
    tsop_s3 <= tsop_s2;
  end

  // TSOP outputs LOW on mark (carrier present) and HIGH on space (no carrier)
  wire mark_start = ~tsop_s2 & tsop_s3; // Falling edge means mark started
  wire mark_end   = tsop_s2 & ~tsop_s3; // Rising edge means mark ended

  // Timing constants for NEC protocol (based on 50MHz clock)
  localparam MIN_LEADER_MARK  = 21'd270000,
             MAX_LEADER_MARK  = 21'd630000,
             MIN_LEADER_SPACE = 21'd135000,
             MAX_LEADER_SPACE = 21'd315000,
             MIN_REPEAT_SPACE = 21'd67500,
             MAX_REPEAT_SPACE = 21'd157500,
             MIN_BIT_MARK = 21'd16875,
             MAX_BIT_MARK = 21'd39375,
             MIN_ZERO_SPACE = 21'd16875,
             MAX_ZERO_SPACE = 21'd39375,
             MIN_ONE_SPACE = 21'd50625,
             MAX_ONE_SPACE = 21'd118125;

  // State machine states
  localparam S_IDLE = 3'd0,
             S_LEADER_MARK = 3'd1,
             S_LEADER_SPACE = 3'd2,
             S_BIT_MARK = 3'd3,
             S_BIT_SPACE = 3'd4,
             S_STOP_BURST = 3'd5;

  reg [2:0] state = S_IDLE;
  reg [20:0] timer = 21'd0;
  reg [4:0] bit_idx = 5'd0;
  reg [31:0] frame = 32'd0;

  always @(posedge i_clk)
  begin
    rx_valid  <= 1'b0;
    rx_repeat <= 1'b0;

    if (timer < 21'h1FFFFF)
      timer <= timer + 21'd1;

    case (state)
      S_IDLE:
      begin
        if (mark_start)
        begin
          timer <= 21'd0;
          state <= S_LEADER_MARK;
        end
      end

      S_LEADER_MARK:
      begin
        if (mark_end)
        begin
          if (timer >= MIN_LEADER_MARK && timer <= MAX_LEADER_MARK)
          begin
            timer <= 21'd0;
            state <= S_LEADER_SPACE;
          end
          else
            state <= S_IDLE;
        end
        else if (timer > MAX_LEADER_MARK)
          state <= S_IDLE;
      end

      S_LEADER_SPACE:
      begin
        if (mark_start)
        begin
          if (timer >= MIN_LEADER_SPACE && timer <= MAX_LEADER_SPACE)
          begin
            timer <= 21'd0;
            bit_idx <= 5'd0;
            state <= S_BIT_MARK;
          end
          else if (timer >= MIN_REPEAT_SPACE && timer <= MAX_REPEAT_SPACE)
          begin
            rx_repeat <= 1'b1;
            state <= S_IDLE;
          end
          else
            state <= S_IDLE;
        end
        else if (timer > MAX_LEADER_SPACE)
          state <= S_IDLE;
      end

      S_BIT_MARK:
      begin
        if (mark_end)
        begin
          if (timer >= MIN_BIT_MARK && timer <= MAX_BIT_MARK)
          begin
            timer <= 21'd0;
            state <= S_BIT_SPACE;
          end
          else
            state <= S_IDLE;
        end
        else if (timer > MAX_BIT_MARK)
          state <= S_IDLE;
      end

      S_BIT_SPACE:
      begin
        if (mark_start)
        begin
          if (timer >= MIN_ZERO_SPACE && timer <= MAX_ZERO_SPACE)
            frame[bit_idx] <= 1'b0;
          else if (timer >= MIN_ONE_SPACE && timer <= MAX_ONE_SPACE)
            frame[bit_idx] <= 1'b1;
          else
          begin
            state <= S_IDLE;
          end

          if ((timer >= MIN_ZERO_SPACE && timer <= MAX_ZERO_SPACE) ||
              (timer >= MIN_ONE_SPACE  && timer <= MAX_ONE_SPACE))
          begin
            timer <= 21'd0;
            if (bit_idx == 5'd31)
              state <= S_STOP_BURST;
            else
            begin
              bit_idx <= bit_idx + 5'd1;
              state <= S_BIT_MARK;
            end
          end
        end
        else if (timer > MAX_ONE_SPACE)
          state <= S_IDLE;
      end

      S_STOP_BURST:
      begin
        if (mark_end)
        begin
          if (timer >= MIN_BIT_MARK && timer <= MAX_BIT_MARK)
          begin
            // Verify inverted checksum for NEC protocol
            if (frame[7:0] == ~frame[15:8] && frame[23:16] == ~frame[31:24])
            begin
              rx_addr <= frame[7:0];
              rx_cmd <= frame[23:16];
              rx_valid <= 1'b1;
            end
          end
          state <= S_IDLE;
        end
        else if (timer > MAX_BIT_MARK)
          state <= S_IDLE;
      end

      default:
        state <= S_IDLE;
    endcase
  end

  assign dbg_state = state;
  assign dbg_bit_idx = bit_idx;

endmodule
