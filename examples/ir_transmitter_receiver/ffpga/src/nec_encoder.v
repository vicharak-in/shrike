// -----------------------------------------------------------------------------
// Module: nec_encoder
// Description: Encodes address and command bytes into the NEC IR protocol format.
//              Generates the 'mod_enable' signal which dictates when the 38kHz
//              carrier should burst to form marks and spaces.
// -----------------------------------------------------------------------------
module nec_encoder (
    input i_clk,
    input [7:0] addr,
    input [7:0] cmd,
    input is_repeat,
    input send,
    output reg mod_enable = 1'b0,
    output reg busy = 1'b0
  );

  // Timing constants for NEC protocol (based on 50MHz clock)
  localparam T_LEADER_BURST = 21'd450000,
             T_LEADER_SPACE = 21'd225000,
             T_REPEAT_SPACE = 21'd112500,
             T_BIT_BURST = 21'd28125,
             T_ZERO_SPACE = 21'd28125,
             T_ONE_SPACE = 21'd84375,
             T_STOP_BURST = 21'd28125,
             T_FRAME_GAP = 21'd2000000;

  // State machine states
  localparam S_IDLE = 3'd0,
             S_LEADER_BURST = 3'd1,
             S_LEADER_SPACE = 3'd2,
             S_REPEAT_SPACE = 3'd3,
             S_BIT_BURST = 3'd4,
             S_BIT_SPACE = 3'd5,
             S_STOP_BURST = 3'd6,
             S_FRAME_GAP = 3'd7;

  reg [2:0] state = S_IDLE;
  reg [20:0] timer = 21'd0;
  reg [4:0] bit_idx = 5'd0;
  reg [31:0] frame = 32'd0;
  reg rep = 1'b0;

  always @(posedge i_clk)
  begin
    case (state)
      S_IDLE:
      begin
        mod_enable <= 1'b0;
        busy <= 1'b0;
        if (send)
        begin
          rep <= is_repeat;
          // Frame includes inverted bits for error checking
          frame <= {~cmd, cmd, ~addr, addr};
          timer <= 21'd0;
          bit_idx <= 5'd0;
          busy <= 1'b1;
          state <= S_LEADER_BURST;
        end
      end

      S_LEADER_BURST:
      begin
        mod_enable <= 1'b1;
        if (timer == T_LEADER_BURST - 1)
        begin
          timer <= 21'd0;
          state <= rep ? S_REPEAT_SPACE : S_LEADER_SPACE;
        end
        else
          timer <= timer + 21'd1;
      end

      S_LEADER_SPACE:
      begin
        mod_enable <= 1'b0;
        if (timer == T_LEADER_SPACE - 1)
        begin
          timer <= 21'd0;
          state <= S_BIT_BURST;
        end
        else
          timer <= timer + 21'd1;
      end

      S_REPEAT_SPACE:
      begin
        mod_enable <= 1'b0;
        if (timer == T_REPEAT_SPACE - 1)
        begin
          timer <= 21'd0;
          state <= S_STOP_BURST;
        end
        else
          timer <= timer + 21'd1;
      end

      S_BIT_BURST:
      begin
        mod_enable <= 1'b1;
        if (timer == T_BIT_BURST - 1)
        begin
          timer <= 21'd0;
          state <= S_BIT_SPACE;
        end
        else
          timer <= timer + 21'd1;
      end

      S_BIT_SPACE:
      begin
        mod_enable <= 1'b0;
        if (timer == (frame[bit_idx] ? T_ONE_SPACE : T_ZERO_SPACE) - 1)
        begin
          timer <= 21'd0;
          if (bit_idx == 5'd31)
            state <= S_STOP_BURST;
          else
          begin
            bit_idx <= bit_idx + 5'd1;
            state <= S_BIT_BURST;
          end
        end
        else
          timer <= timer + 21'd1;
      end

      S_STOP_BURST:
      begin
        mod_enable <= 1'b1;
        if (timer == T_STOP_BURST - 1)
        begin
          mod_enable <= 1'b0;
          timer <= 21'd0;
          state <= S_FRAME_GAP;
        end
        else
          timer <= timer + 21'd1;
      end

      S_FRAME_GAP:
      begin
        mod_enable <= 1'b0;
        if (timer == T_FRAME_GAP - 1)
        begin
          busy <= 1'b0;
          timer <= 21'd0;
          state <= S_IDLE;
        end
        else
          timer <= timer + 21'd1;
      end

      default:
        state <= S_IDLE;
    endcase
  end

endmodule
