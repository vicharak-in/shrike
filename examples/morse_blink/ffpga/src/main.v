(* top *) module blink #(
    parameter CLK = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) input rx,
    (* iopad_external_pin *) output LED,
    (* iopad_external_pin *) output LED_en,
    (* iopad_external_pin *) output clk_en
);

	// oe pins
    assign LED_en = 1'b1;
    assign clk_en = 1'b1;

    // uart initialization, uart rx module is taken from official shrike examples
    wire[7:0] data;
    wire data_valid;

    uart_rx #(
        .CLK(CLK),
        .BAUD_RATE(BAUD_RATE)
    ) U_uart_rx (
        .i_Clock(clk),
        .i_RX_Serial(rx),
        .o_RX_DV(data_valid),
        .o_RX_Byte(data)
    );


    reg [7:0] morse_pattern;
    reg [3:0] morse_len;
    localparam integer DOT_TIME  = CLK / 5;     // ~200ms @ 50MHz
    localparam integer DASH_TIME = (CLK / 5) * 3;

   
    localparam IDLE = 2'd0, ON = 2'd1, OFF = 2'd2;

    reg [1:0] state;
    reg [31:0] counter;
    reg [3:0] index;	
    reg led_reg;

    assign LED = led_reg;

    wire curr_is_dash = morse_pattern[morse_len - 1 - index];
    wire [31:0] curr_on_time = curr_is_dash ? DASH_TIME : DOT_TIME;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                led_reg <= 1'b0;
                counter <= 32'd0;
                index   <= 4'd0;

                if (data_valid) begin
      				
                    case (data)
                        "A","a": begin morse_pattern <= 8'b0000_0001; morse_len <= 4'd2; end // .-
                        "B","b": begin morse_pattern <= 8'b0000_1000; morse_len <= 4'd4; end // -...
                        "C","c": begin morse_pattern <= 8'b0000_1010; morse_len <= 4'd4; end // -.-.
                        "D","d": begin morse_pattern <= 8'b0000_0100; morse_len <= 4'd3; end // -..
                        "E","e": begin morse_pattern <= 8'b0000_0000; morse_len <= 4'd1; end // .
                        "F","f": begin morse_pattern <= 8'b0000_0010; morse_len <= 4'd4; end // ..-.
                        "G","g": begin morse_pattern <= 8'b0000_0110; morse_len <= 4'd3; end // --.
                        "H","h": begin morse_pattern <= 8'b0000_0000; morse_len <= 4'd4; end // ....
                        "I","i": begin morse_pattern <= 8'b0000_0000; morse_len <= 4'd2; end // ..
                        "J","j": begin morse_pattern <= 8'b0000_0111; morse_len <= 4'd4; end // .---
                        "K","k": begin morse_pattern <= 8'b0000_0101; morse_len <= 4'd3; end // -.-
                        "L","l": begin morse_pattern <= 8'b0000_0100; morse_len <= 4'd4; end // .-..
                        "M","m": begin morse_pattern <= 8'b0000_0011; morse_len <= 4'd2; end // --
                        "N","n": begin morse_pattern <= 8'b0000_0010; morse_len <= 4'd2; end // -.
                        "O","o": begin morse_pattern <= 8'b0000_0111; morse_len <= 4'd3; end // ---
                        "P","p": begin morse_pattern <= 8'b0000_0110; morse_len <= 4'd4; end // .--.
                        "Q","q": begin morse_pattern <= 8'b0000_1101; morse_len <= 4'd4; end // --.-
                        "R","r": begin morse_pattern <= 8'b0000_0010; morse_len <= 4'd3; end // .-.
                        "S","s": begin morse_pattern <= 8'b0000_0000; morse_len <= 4'd3; end // ...
                        "T","t": begin morse_pattern <= 8'b0000_0001; morse_len <= 4'd1; end // -
                        "U","u": begin morse_pattern <= 8'b0000_0001; morse_len <= 4'd3; end // ..-
                        "V","v": begin morse_pattern <= 8'b0000_0001; morse_len <= 4'd4; end // ...-
                        "W","w": begin morse_pattern <= 8'b0000_0011; morse_len <= 4'd3; end // .--
                        "X","x": begin morse_pattern <= 8'b0000_1001; morse_len <= 4'd4; end // -..-
                        "Y","y": begin morse_pattern <= 8'b0000_1011; morse_len <= 4'd4; end // -.--
                        "Z","z": begin morse_pattern <= 8'b0000_1100; morse_len <= 4'd4; end // --..
                        "0": begin morse_pattern <= 8'b0001_1111; morse_len <= 4'd5; end // -----
                        "1": begin morse_pattern <= 8'b0000_1111; morse_len <= 4'd5; end // .----
                        "2": begin morse_pattern <= 8'b0000_0111; morse_len <= 4'd5; end // ..---
                        "3": begin morse_pattern <= 8'b0000_0011; morse_len <= 4'd5; end // ...--
                        "4": begin morse_pattern <= 8'b0000_0001; morse_len <= 4'd5; end // ....-
                        "5": begin morse_pattern <= 8'b0000_0000; morse_len <= 4'd5; end // .....
                        "6": begin morse_pattern <= 8'b0001_0000; morse_len <= 4'd5; end // -....
                        "7": begin morse_pattern <= 8'b0001_1000; morse_len <= 4'd5; end // --...
                        "8": begin morse_pattern <= 8'b0001_1100; morse_len <= 4'd5; end // ---..
                        "9": begin morse_pattern <= 8'b0001_1110; morse_len <= 4'd5; end // ----.
                        default: begin morse_pattern <= 8'd0; morse_len <= 4'd0; end // unsupported character basically
                    	endcase

					// so basically morse_pattern actually will update at the end of cycle so im just resorting to this 
					// i thought i could just remove this since the fsm will turn it off anyway but 
					// my point is to make sure led on only when curr_on_time > 0, which won't be true otherwise
                    	case (data)
                        "A","a","B","b","C","c","D","d","E","e","F","f","G","g","H","h","I","i",
                        "J","j","K","k","L","l","M","m","N","n","O","o","P","p","Q","q","R","r",
                        "S","s","T","t","U","u","V","v","W","w","X","x","Y","y","Z","z",
                        "0","1","2","3","4","5","6","7","8","9":
                            state <= ON;
                        default:
                            state <= IDLE;
                    endcase
                end
            end

            ON: begin
                led_reg <= 1'b1;
                counter <= counter + 32'd1;

                if (counter >= curr_on_time) begin
                    counter <= 32'd0;
                    state   <= OFF;
                end
            end

            OFF: begin
                led_reg <= 1'b0;
                counter <= counter + 32'd1;

                // mid signal gap = 1 dot
                if (counter >= DOT_TIME) begin
                    counter <= 32'd0;

                    if (index + 1 >= morse_len) begin
                        index <= 4'd0;
                        state <= IDLE;
                    end else begin
                        index <= index + 4'd1;
                        state <= ON;
                    end
                end
            end

            default: state <= IDLE;
        endcase
    end

    initial begin
        state         = IDLE;
        counter       = 32'd0;
        index         = 4'd0;
        led_reg       = 1'b0;
        morse_pattern = 8'd0;
        morse_len     = 4'd0;
    end

endmodule