module lifo_bram #(
  parameter DEPTH = 256,         // stack depth
  parameter ADDR_W = 8           // log2(DEPTH)
)(
  input        clk,
  input        nReset,

  input  [3:0] DIN,
  input        WE,               // push
  input        RE,               // pop
  output reg [3:0] DOUT,

  output reg       LIFO_full,
  output reg       LIFO_empty,

  // BRAM interface
  output [1:0] BRAM0_RATIO,

  output reg [7:0] BRAM0_DATA_IN,
  output reg       BRAM0_WEN,
  output           BRAM0_WCLKEN,
  output reg [8:0] BRAM0_WRITE_ADDR,

  input  [3:0] BRAM0_DATA_OUT,
  output reg       BRAM0_REN,
  output           BRAM0_RCLKEN,
  output reg [8:0] BRAM0_READ_ADDR
);

  // stack pointer
  reg [ADDR_W:0] sp;   // stack pointer (0 = empty)

  assign BRAM0_RATIO = 2'b00;
  assign BRAM0_WCLKEN = 1'b0;
  assign BRAM0_RCLKEN = 1'b0;


  always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
      sp          <= 0;
      LIFO_empty  <= 1'b1;
      LIFO_full   <= 1'b0;
    end else begin

      // PUSH
      if (WE && !LIFO_full) begin
        sp <= sp + 1;
      end

      // POP
      else if (RE && !LIFO_empty) begin
        sp <= sp - 1;
      end

      // Status flags
      LIFO_empty <= (sp == 0);
      LIFO_full  <= (sp == DEPTH);

    end
  end


  // BRAM WRITE (push)
  always @(posedge clk) begin
    BRAM0_DATA_IN    <= {4'b0000, DIN};
    BRAM0_WRITE_ADDR <= sp;
    BRAM0_WEN        <= !(WE && !LIFO_full);
  end


  // BRAM READ (pop)
  always @(posedge clk) begin
    BRAM0_READ_ADDR <= sp - 1; 
    DOUT            <= BRAM0_DATA_OUT;
    BRAM0_REN       <= !(RE && !LIFO_empty);
  end

endmodule