module alu_8bit (
    input  [7:0] a_reg,
    input  [7:0] data_in,
    input  [4:0] opcode,
    output reg [7:0] out,
    output wire zero
);
    always @(*) begin
        case (opcode)
            5'h01: out = data_in;               // LDA
            5'h02: out = a_reg + data_in;       // ADD
            5'h03: out = a_reg - data_in;       // SUB
            5'h04: out = a_reg & data_in;       // AND
            5'h05: out = a_reg | data_in;       // OR
            5'h06: out = a_reg ^ data_in;       // XOR
            5'h07: out = a_reg << 1;            // LSL
            5'h08: out = a_reg >> 1;            // LSR
            5'h09: out = {a_reg[6:0], a_reg[7]};// ROL
            5'h0A: out = {a_reg[0], a_reg[7:1]};// ROR
            5'h0B: out = a_reg + 1'b1;          // INC
            5'h0C: out = a_reg - 1'b1;          // DEC
            default: out = a_reg;
        endcase
    end
    assign zero = (out == 8'b0);
endmodule
