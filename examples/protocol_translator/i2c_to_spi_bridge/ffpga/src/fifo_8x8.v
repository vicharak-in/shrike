`timescale 1ns/1ps
//------------------------------------------------------------
// Module : fifo_8x8
//
// Description:
// 8-bit wide, 8-entry synchronous FIFO.
//
// Supports simultaneous read and write operations
// with full and empty status flags.
//
//------------------------------------------------------------
module fifo_8x8(
    input wire clk,
    input wire rst,

    input wire wr_en,
    input wire rd_en,
    input wire [7:0] data_in,
    output reg [7:0] data_out,

    output wire full,
    output wire empty,
    output reg [3:0] count
);

    reg [7:0] mem [0:7];
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;
    assign empty = (count == 0);
    assign full  = (count == 8);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count <= 0;
        data_out <= 0;
    end
    else begin
        case ({wr_en && !full, rd_en && !empty})
        2'b10: begin
            mem[wr_ptr] <= data_in;
            wr_ptr <= wr_ptr + 1'b1;
            count <= count + 1'b1;
        end
        2'b01: begin
            data_out <= mem[rd_ptr];
            rd_ptr <= rd_ptr + 1'b1;
            count <= count - 1'b1;
        end
        2'b11: begin
            mem[wr_ptr] <= data_in;
            data_out <= mem[rd_ptr];
            wr_ptr <= wr_ptr + 1'b1;
            rd_ptr <= rd_ptr + 1'b1;
            count <= count;
        end
        default: begin
        end
        endcase
    end
end
endmodule