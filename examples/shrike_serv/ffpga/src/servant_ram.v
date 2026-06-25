// =============================================================================
// servant_ram.v -- Unified IMEM+DMEM for SERV on Shrike Lite
// DATA_IN  = top output = write data INTO bram  (fabric drives it)
// DATA_OUT = top input  = read data FROM bram   (bram drives it)
// WEN active-low, RATIO=00 (512x8), WCLKEN/RCLKEN/REN tied 0.
// =============================================================================

module servant_ram
  #(parameter depth = 128,
    parameter aw    = $clog2(depth),
    parameter RESET_STRATEGY = "")
  (
   // SPI loader write port
   input  wire        ld_we,
   input  wire [6:0]  ld_word,   // 7-bit for 128-word image
   input  wire [1:0]  ld_lane,
   input  wire [7:0]  ld_byte,

   // Wishbone slave
   input  wire          i_wb_clk,
   input  wire          i_wb_rst,
   input  wire [aw-1:2] i_wb_adr,
   input  wire [31:0]   i_wb_dat,
   input  wire [3:0]    i_wb_sel,
   input  wire          i_wb_we,
   input  wire          i_wb_cyc,
   output reg  [31:0]   o_wb_rdt,
   output reg           o_wb_ack,

   // BRAM0..3
   output wire [1:0] BRAM0_RATIO,
   output wire [7:0] BRAM0_DATA_IN,
   output wire       BRAM0_WEN,
   output wire       BRAM0_WCLKEN,
   output wire [8:0] BRAM0_WRITE_ADDR,
   input  wire [7:0] BRAM0_DATA_OUT,
   output wire       BRAM0_REN,
   output wire       BRAM0_RCLKEN,
   output wire [8:0] BRAM0_READ_ADDR,

   output wire [1:0] BRAM1_RATIO,
   output wire [7:0] BRAM1_DATA_IN,
   output wire       BRAM1_WEN,
   output wire       BRAM1_WCLKEN,
   output wire [8:0] BRAM1_WRITE_ADDR,
   input  wire [7:0] BRAM1_DATA_OUT,
   output wire       BRAM1_REN,
   output wire       BRAM1_RCLKEN,
   output wire [8:0] BRAM1_READ_ADDR,

   output wire [1:0] BRAM2_RATIO,
   output wire [7:0] BRAM2_DATA_IN,
   output wire       BRAM2_WEN,
   output wire       BRAM2_WCLKEN,
   output wire [8:0] BRAM2_WRITE_ADDR,
   input  wire [7:0] BRAM2_DATA_OUT,
   output wire       BRAM2_REN,
   output wire       BRAM2_RCLKEN,
   output wire [8:0] BRAM2_READ_ADDR,

   output wire [1:0] BRAM3_RATIO,
   output wire [7:0] BRAM3_DATA_IN,
   output wire       BRAM3_WEN,
   output wire       BRAM3_WCLKEN,
   output wire [8:0] BRAM3_WRITE_ADDR,
   input  wire [7:0] BRAM3_DATA_OUT,
   output wire       BRAM3_REN,
   output wire       BRAM3_RCLKEN,
   output wire [8:0] BRAM3_READ_ADDR
  );

  // --- 512x8 mode, all clock-enables and REN active-low tied 0 ---
  assign {BRAM0_RATIO, BRAM1_RATIO, BRAM2_RATIO, BRAM3_RATIO} = {4{2'b00}};
  assign {BRAM0_WCLKEN, BRAM1_WCLKEN, BRAM2_WCLKEN, BRAM3_WCLKEN,
          BRAM0_RCLKEN, BRAM1_RCLKEN, BRAM2_RCLKEN, BRAM3_RCLKEN,
          BRAM0_REN,    BRAM1_REN,    BRAM2_REN,    BRAM3_REN} = {12{1'b0}};

  // --- Read port: word address from Wishbone ---
  wire [8:0] rd_addr = {2'b0, i_wb_adr[aw-1:2]};
  assign BRAM0_READ_ADDR = rd_addr;
  assign BRAM1_READ_ADDR = rd_addr;
  assign BRAM2_READ_ADDR = rd_addr;
  assign BRAM3_READ_ADDR = rd_addr;

  // --- Write port: SPI loader during reset, Wishbone during run ---
  wire [8:0] wr_addr = ld_we ? {2'b0, ld_word} : {2'b0, i_wb_adr[aw-1:2]};
  assign BRAM0_WRITE_ADDR = wr_addr;
  assign BRAM1_WRITE_ADDR = wr_addr;
  assign BRAM2_WRITE_ADDR = wr_addr;
  assign BRAM3_WRITE_ADDR = wr_addr;

  // Write data: same byte broadcast to all, WEN picks the lane (picorv32 pattern)
  assign BRAM0_DATA_IN = ld_we ? ld_byte : i_wb_dat[ 7: 0];
  assign BRAM1_DATA_IN = ld_we ? ld_byte : i_wb_dat[15: 8];
  assign BRAM2_DATA_IN = ld_we ? ld_byte : i_wb_dat[23:16];
  assign BRAM3_DATA_IN = ld_we ? ld_byte : i_wb_dat[31:24];

  // WEN active-low: SPI targets one lane per pulse; Wishbone uses sel
  wire wb_write = i_wb_cyc & i_wb_we;
  assign BRAM0_WEN = ld_we ? ~(ld_lane == 2'd0) : ~(wb_write & i_wb_sel[0]);
  assign BRAM1_WEN = ld_we ? ~(ld_lane == 2'd1) : ~(wb_write & i_wb_sel[1]);
  assign BRAM2_WEN = ld_we ? ~(ld_lane == 2'd2) : ~(wb_write & i_wb_sel[2]);
  assign BRAM3_WEN = ld_we ? ~(ld_lane == 2'd3) : ~(wb_write & i_wb_sel[3]);

  // --- Wishbone: uniform 2-cycle latency for both read and write ---
  // (1 cycle to present addr, 1 cycle for BRAM DATA_IN to be valid)
  reg rd_pend;

  always @(posedge i_wb_clk) begin
    o_wb_ack <= 1'b0;
    rd_pend  <= 1'b0;

    if (i_wb_rst && (RESET_STRATEGY != "NONE")) begin
      o_wb_ack <= 1'b0;
      rd_pend  <= 1'b0;
    end else if (i_wb_cyc && !o_wb_ack) begin
      if (!rd_pend) begin
        rd_pend <= 1'b1;
      end else begin
        if (!i_wb_we)
          o_wb_rdt <= {BRAM3_DATA_OUT, BRAM2_DATA_OUT, BRAM1_DATA_OUT, BRAM0_DATA_OUT};
        o_wb_ack <= 1'b1;
      end
    end
  end

endmodule
