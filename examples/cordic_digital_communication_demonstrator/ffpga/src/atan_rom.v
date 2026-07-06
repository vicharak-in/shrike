module atan_rom (
    input  wire [2:0] addr,
    output reg signed [9:0] atan_val
);

always @(*) begin
    case(addr)

        3'd0 : atan_val = 10'd201;
        3'd1 : atan_val = 10'd119;
        3'd2 : atan_val = 10'd63;
        3'd3 : atan_val = 10'd32;
        3'd4 : atan_val = 10'd16;
        3'd5 : atan_val = 10'd8;
        3'd6 : atan_val = 10'd4;
        3'd7 : atan_val = 10'd2;

        default : atan_val = 10'd0;

    endcase
end

endmodule