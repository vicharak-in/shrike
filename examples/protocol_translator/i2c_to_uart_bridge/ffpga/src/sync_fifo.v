`timescale 1ns/1ps
//------------------------------------------------------------
// Module : sync_fifo
//
// Small synchronous FIFO used to decouple the two independent
// directions of a bidirectional bridge so a burst on one side
// is not dropped while the other side drains.
//
//   * First-word-fall-through: o_rdata always shows the head.
//   * Simultaneous read+write in the same cycle is supported.
//   * Writes while full and reads while empty are ignored.
//
// DEPTH must be a power of two and AWID = log2(DEPTH).
//------------------------------------------------------------

module sync_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16,
    parameter AWID  = 4
)(
    input  wire             i_clk,
    input  wire             i_wr,
    input  wire [WIDTH-1:0] i_wdata,
    input  wire             i_rd,
    output wire [WIDTH-1:0] o_rdata,
    output wire             o_empty,
    output wire             o_full
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AWID-1:0]  wptr  = {AWID{1'b0}};
    reg [AWID-1:0]  rptr  = {AWID{1'b0}};
    reg [AWID:0]    count = {(AWID+1){1'b0}};

    assign o_empty = (count == 0);
    assign o_full  = (count == DEPTH);
    assign o_rdata = mem[rptr];

    wire do_wr = i_wr && !o_full;
    wire do_rd = i_rd && !o_empty;

    always @(posedge i_clk) begin
        if (do_wr) begin
            mem[wptr] <= i_wdata;
            wptr <= wptr + 1'b1;
        end
        if (do_rd) begin
            rptr <= rptr + 1'b1;
        end
        case ({do_wr, do_rd})
            2'b10:   count <= count + 1'b1;
            2'b01:   count <= count - 1'b1;
            default: count <= count;
        endcase
    end
endmodule
