(* top *) module pmod_led( 
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output [7:0] led_pmod,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) output [7:0] led_en
);

  assign clk_en = 1'b1;
  assign led_en = 8'b11111111;

  reg [31:0] counter;
  reg [2:0] pattern_select = 0;
  reg [7:0] led;
  reg [31:0] pattern_timer;

  // Extra state for complex patterns
  reg [2:0] bounce_pos = 0;
  reg bounce_dir = 0;

  reg [7:0] snake_mask = 8'b00000001;

  reg [2:0] breath_level = 0;
  reg breath_dir = 0;

  always @(posedge clk) begin
    counter <= counter + 1;
    pattern_timer <= pattern_timer + 1;

    // Switch pattern every ~1.5 seconds
    if (pattern_timer >= 75_000_000) begin
      pattern_timer <= 0;
      pattern_select <= pattern_select + 1;
    end

    case (pattern_select)
      3'd0: begin
        // Pattern 0: Blink all LEDs
        if (counter >= 25_000_000) begin
          led <= ~led;
          counter <= 0;
        end
      end

      3'd1: begin
        // Pattern 1: Left shift
        if (counter >= 10_000_000) begin
          led <= (led == 0) ? 8'b00000001 : led << 1;
          counter <= 0;
        end
      end

      3'd2: begin
        // Pattern 2: Right shift
        if (counter >= 10_000_000) begin
          led <= (led == 0) ? 8'b10000000 : led >> 1;
          counter <= 0;
        end
      end

      3'd3: begin
        // Pattern 3: Alternating pattern
        if (counter >= 25_000_000) begin
          led <= (led == 8'b10101010) ? 8'b01010101 : 8'b10101010;
          counter <= 0;
        end
      end

      3'd4: begin
        // Pattern 4: Fill from edges inward
        if (counter >= 15_000_000) begin
          case (led)
            8'b00000000: led <= 8'b10000001;
            8'b10000001: led <= 8'b11000011;
            8'b11000011: led <= 8'b11100111;
            8'b11100111: led <= 8'b11111111;
            default:     led <= 8'b00000000;
          endcase
          counter <= 0;
        end
      end

      3'd5: begin
        // Pattern 5: Snake effect
        if (counter >= 10_000_000) begin
          if (snake_mask == 8'b11111111)
            snake_mask <= 8'b00000001;
          else
            snake_mask <= (snake_mask << 1) | 1;
          led <= snake_mask;
          counter <= 0;
        end
      end

      3'd6: begin
        // Pattern 6: Bounce (ping-pong)
        if (counter >= 8_000_000) begin
          if (!bounce_dir) begin
            if (bounce_pos < 7)
              bounce_pos <= bounce_pos + 1;
            else
              bounce_dir <= 1;
          end else begin
            if (bounce_pos > 0)
              bounce_pos <= bounce_pos - 1;
            else
              bounce_dir <= 0;
          end
          led <= 8'b00000001 << bounce_pos;
          counter <= 0;
        end
      end

      3'd7: begin
        // Pattern 7: Breathing effect (fake PWM, LED fill pattern)
        if (counter >= 20_000_000) begin
          if (!breath_dir) begin
            if (breath_level < 8)
              breath_level <= breath_level + 1;
            else
              breath_dir <= 1;
          end else begin
            if (breath_level > 0)
              breath_level <= breath_level - 1;
            else
              breath_dir <= 0;
          end
          led <= (1 << breath_level) - 1;
          counter <= 0;
        end
      end

      default: begin
        // Reset all
        pattern_select <= 0;
        counter <= 0;
        led <= 8'b00000000;
        snake_mask <= 8'b00000001;
        bounce_pos <= 0;
        breath_level <= 0;
      end
    endcase
  end

  assign led_pmod = led;

endmodule