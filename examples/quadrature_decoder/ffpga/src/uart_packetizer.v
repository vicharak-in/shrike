module uart_packetizer (
    input               clk,

    input [15:0]        position,
    input [15:0]        speed,
    input [15:0]        angle,
    input               direction,
    input               data_valid,

    // UART interface
    input               uart_busy,
    output reg          uart_dv,
    output reg [7:0]    uart_byte
);

reg [1:0] state = 0;
reg [55:0] data_reg = 0;
reg [2:0] byte_num = 0;

always @(posedge clk) begin
    case (state)
        0: begin
            uart_dv <= 0;

            if (data_valid) begin
                state <= 1;
                byte_num <= 0;
                data_reg <= {position, speed, angle, 7'b0, direction};
            end
        end

        1: begin
            if (!uart_busy) begin
                uart_byte <= 8'hAA;
                uart_dv   <= 1;
                byte_num  <= 0;
                state     <= 2;
            end
        end

        2: begin
            uart_dv <= 0;

            if (byte_num < 7) begin
                state <= 3;
            end else begin
                state <= 0;
            end
        end

        3: begin
            if (!uart_busy) begin
                uart_byte <= data_reg[((7 - byte_num) * 8) - 1 -: 8];
                uart_dv   <= 1;
                byte_num  <= byte_num + 1;
                state     <= 2;
            end
        end
    endcase
end

endmodule