`timescale 1ns/1ps
//------------------------------------------------------------
// Module Name : fifo_8x8
//
// Description:
// 8-Deep, 8-Bit First In First Out (FIFO) Buffer.
//
// Features:
// - 8-bit Data Width
// - 8 Entry Storage Depth
// - Independent Read and Write Control
// - Simultaneous Read and Write Support
// - Full and Empty Status Flags
//
// Purpose:
// Buffers data between modules operating at
// different speeds.
//------------------------------------------------------------

module fifo_8x8 (
    input  wire       clk,
    input  wire       rst,

    input  wire       wr_en,
    input  wire       rd_en,

    input  wire [7:0] data_in,
    output reg  [7:0] data_out,

    output wire       full,
    output wire       empty,
    output reg  [3:0] count
);

    reg [7:0] mem [0:7];
    reg [2:0] wr_ptr;
    reg [2:0] rd_ptr;

    assign full  = (count == 4'd8);
    assign empty = (count == 4'd0);

    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr   <= 3'd0;
            rd_ptr   <= 3'd0;
            count    <= 4'd0;
            data_out <= 8'd0;

            for(i=0;i<8;i=i+1)
                mem[i] <= 8'd0;
        end
        else begin
            if (wr_en && !rd_en) begin
                if (!full) begin
                    mem[wr_ptr] <= data_in;
                    wr_ptr <= wr_ptr + 3'd1;
                    count  <= count + 4'd1;
                end
            end

            else if (rd_en && !wr_en)  begin
                if (!empty)  begin
                    data_out <= mem[rd_ptr];
                    rd_ptr <= rd_ptr + 3'd1;
                    count  <= count - 4'd1;
                end
            end

            else if (wr_en && rd_en)  begin
                // Read current FIFO data
                if (!empty)
                    data_out <= mem[rd_ptr];

                if (!full)
                    mem[wr_ptr] <= data_in;

                if (!empty)
                    rd_ptr <= rd_ptr + 3'd1;

                if (!full)
                    wr_ptr <= wr_ptr + 3'd1;

            end
        end
    end

endmodule