// main.v  -  Parameterised HUB75 RGB-LED-matrix controller
// Target : Renesas SLG47910V ForgeFPGA on the Vicharak Shrike-fi board
//          (1120 5-input LUTs, 50 MHz internal oscillator, 32 kbit BRAM)
// Flow   : Renesas Go Configure Software Hub -> ForgeFPGA -> synthesise
//          -> IO planner -> Generate Bitstream. Paste THIS file into main.v.
//
// One ForgeFPGA drives ONE panel. Default build targets an 8x8 RGB panel;
// change the parameters on hub75_top for other geometries (see PINOUT.md
// and README.md for the pin budget and BRAM limits for larger panels).
//
// Colour : BPP bits per channel via Binary-Code-Modulation (BCM). Default 4
//          bits -> 12-bit / 4096-colour. Set BPP=1 for 8-colour, up to 8.
//
// This file is self-contained (top + driver + framebuffer) so it drops
// straight into the single-buffer Go Configure editor AND compiles as-is for
// simulation (see sim/). Verilog-2001, no SystemVerilog.

(* top *) module hub75_top #(
    parameter integer COLS = 8, // panel width  (pixels)
    parameter integer ROWS = 8, // panel height (pixels), even, >= 4
    parameter integer BPP = 4, // colour bits per channel (1..8)
    parameter integer DISP_BASE = 1 // LSB bit-plane display cycles
    // (raise on hardware for brightness)
  ) (
    (* iopad_external_pin, clkbuf_inhibit *) input wire clk,
    (* iopad_external_pin *) input wire rst_n, // active-low; may map to FPGA_CORE_READY (no GPIO cost)
    (* iopad_external_pin *) output wire clk_en, // -> OSC_EN
    (* iopad_external_pin *) output wire [5:0] hub_rgb, // {b2,g2,r2, b1,g1,r1}
    (* iopad_external_pin *) output wire [$clog2(ROWS/2)-1:0] hub_addr, // row select A,B,C,D,E...
    (* iopad_external_pin *) output wire hub_clk, // shift clock
    (* iopad_external_pin *) output wire hub_lat, // latch / strobe
    (* iopad_external_pin *) output wire hub_oe_n, // output enable, ACTIVE LOW
    (* iopad_external_pin *) output wire [5:0] hub_rgb_oe,
    (* iopad_external_pin *) output wire [$clog2(ROWS/2)-1:0] hub_addr_oe,
    (* iopad_external_pin *) output wire hub_clk_oe,
    (* iopad_external_pin *) output wire hub_lat_oe,
    (* iopad_external_pin *) output wire hub_oe_n_oe
  );
  localparam integer ADDR_BITS = $clog2(ROWS/2);
  localparam integer PIX_BITS = 3 * BPP;
  localparam integer FB_ABITS = $clog2(ROWS*COLS);

  // oscillator + all pad output-enables always on
  assign clk_en = 1'b1;
  assign hub_rgb_oe = {6{1'b1}};
  assign hub_addr_oe = {ADDR_BITS{1'b1}};
  assign hub_clk_oe = 1'b1;
  assign hub_lat_oe = 1'b1;
  assign hub_oe_n_oe = 1'b1;

  wire rst = ~rst_n; // internal active-high reset

  // Framebuffer write port.
  //   Simulation: preloaded from a hex image via $readmemh (we stays 0).
  //   Hardware   : hook the ESP32-S3 SPI target (spi_target.v) here, e.g.
  //        spi_target u_spi(.clk(clk), .sck(spi_sck), .mosi(spi_mosi),
  //                         .ss(spi_ss), .wr_en(we), .wr_addr(waddr),
  //                         .wr_data(wdata));
  //   (add spi_sck/mosi/ss as top-level input pins and pack the 12-bit
  //    pixels into the byte stream, or widen spi_target to PIX_BITS.)

  wire we = 1'b0;
  wire [FB_ABITS-1:0] waddr = {FB_ABITS{1'b0}};
  wire [PIX_BITS-1:0] wdata = {PIX_BITS{1'b0}};

  wire [FB_ABITS-1:0] raddr_u, raddr_l;
  wire [PIX_BITS-1:0] rdata_u, rdata_l;

  hub75_framebuffer #(
                      .COLS (COLS),
                      .ROWS (ROWS),
                      .BPP (BPP)
                    ) u_fb (
                      .clk (clk),
                      .we (we),
                      .waddr (waddr),
                      .wdata (wdata),
                      .raddr_u (raddr_u),
                      .rdata_u (rdata_u),
                      .raddr_l (raddr_l),
                      .rdata_l (rdata_l)
                    );

  hub75_driver #(
                 .COLS (COLS),
                 .ROWS (ROWS),
                 .BPP (BPP),
                 .DISP_BASE (DISP_BASE)
               ) u_drv (
                 .clk (clk),
                 .rst (rst),
                 .raddr_u (raddr_u),
                 .rdata_u (rdata_u),
                 .raddr_l (raddr_l),
                 .rdata_l (rdata_l),
                 .hub_rgb (hub_rgb),
                 .hub_addr (hub_addr),
                 .hub_clk (hub_clk),
                 .hub_lat (hub_lat),
                 .hub_oe_n (hub_oe_n)
               );

endmodule


// DRIVER : scan + Binary-Code-Modulation
//
// The panel is split into an upper half (rows 0..SCAN-1) and a lower half
// (rows SCAN..ROWS-1), SCAN = ROWS/2. A row address selects one row of each
// half; R1/G1/B1 carry the upper pixel, R2/G2/B2 the lower pixel.
//
// For each bit-plane p (0..BPP-1) and each row address r, the COLS pixels are
// shifted out (bit p of each channel), latched, then displayed for
// DISP_BASE*2^p clock cycles. Summed over planes the on-time of a channel is
// proportional to its BPP-bit value => linear brightness.

module hub75_driver #(
    parameter integer COLS = 8,
    parameter integer ROWS = 8,
    parameter integer BPP = 4,
    parameter integer DISP_BASE = 1
  ) (
    input wire clk,
    input wire rst, // active-high, synchronous

    // external framebuffer, asynchronous dual read
    output wire [$clog2(ROWS * COLS) - 1:0] raddr_u,
    input wire [3 * BPP - 1:0] rdata_u,
    output wire [$clog2(ROWS * COLS) - 1:0] raddr_l,
    input wire [3 * BPP - 1:0] rdata_l,

    // HUB75 panel signals
    output reg [5:0] hub_rgb, // {b2,g2,r2, b1,g1,r1}
    output reg [$clog2(ROWS / 2) - 1:0] hub_addr,
    output reg hub_clk,
    output reg hub_lat,
    output reg hub_oe_n // ACTIVE LOW
  );
  localparam integer SCAN = ROWS / 2;
  localparam integer ADDR_BITS = $clog2(ROWS / 2);
  localparam integer COL_BITS = $clog2(COLS);
  localparam integer PL_BITS = (BPP > 1) ? $clog2(BPP) : 1;
  localparam integer DISP_W = $clog2(DISP_BASE * (1 << BPP)) + 1;

  localparam [1:0] S_SHIFT = 2'd0;
  localparam [1:0] S_LATCH = 2'd1;
  localparam [1:0] S_DISPLAY = 2'd2;

  reg [1:0] state;
  reg phase; // 0 = data setup, 1 = clk-high
  reg [COL_BITS:0] col; // 0 .. COLS-1
  reg [ADDR_BITS:0] row; // 0 .. SCAN-1
  reg [PL_BITS:0] plane; // 0 .. BPP-1
  reg [DISP_W-1:0] disp_cnt;

  // pixel word layout: {R[BPP], G[BPP], B[BPP]}  (R is MSBs)
  assign raddr_u = row[ADDR_BITS - 1:0] * COLS + col[COL_BITS - 1:0];
  assign raddr_l = (row[ADDR_BITS-1:0]+SCAN)  * COLS + col[COL_BITS-1:0];

  wire r1_bit = rdata_u[2*BPP + plane];
  wire g1_bit = rdata_u[1*BPP + plane];
  wire b1_bit = rdata_u[0*BPP + plane];
  wire r2_bit = rdata_l[2*BPP + plane];
  wire g2_bit = rdata_l[1*BPP + plane];
  wire b2_bit = rdata_l[0*BPP + plane];

  always @(posedge clk)
  begin
    if (rst)
    begin
      state <= S_SHIFT;
      phase <= 1'b0;
      col <= 0;
      row <= 0;
      plane <= 0;
      disp_cnt <= 0;
      hub_rgb <= 6'b0;
      hub_addr <= 0;
      hub_clk <= 1'b0;
      hub_lat <= 1'b0;
      hub_oe_n <= 1'b1;
    end
    else
    begin
      hub_lat <= 1'b0; // default: no latch
      case (state)
        //shift COLS pixels of current (plane,row) into the panel
        S_SHIFT:
        begin
          hub_oe_n <= 1'b1; // blank while shifting
          if (phase == 1'b0)
          begin
            hub_clk <= 1'b0; // data-setup, clock low
            hub_rgb <= {b2_bit, g2_bit, r2_bit, b1_bit, g1_bit, r1_bit};
            phase <= 1'b1;
          end
          else
          begin
            hub_clk <= 1'b1; // rising edge shifts data in
            phase <= 1'b0;
            if (col == COLS-1)
            begin
              col <= 0;
              state <= S_LATCH;
            end
            else
            begin
              col <= col + 1'b1;
            end
          end
        end

        // --- latch the line and drive its row address ---
        S_LATCH:
        begin
          hub_clk <= 1'b0;
          hub_oe_n <= 1'b1;
          hub_addr <= row[ADDR_BITS-1:0];
          hub_lat <= 1'b1; // one-cycle strobe
          disp_cnt <= (DISP_BASE << plane);
          state <= S_DISPLAY;
        end

        // --- display for exactly DISP_BASE*2^plane lit cycles ---
        // disp_cnt is "lit cycles remaining"; it was loaded with the full
        // weight in S_LATCH, so counting down to 0 yields exactly that
        // many cycles of hub_oe_n low (the LSB plane still lights once).
        S_DISPLAY:
        begin
          if (disp_cnt == 0)
          begin
            hub_oe_n <= 1'b1; // blank, then advance
            if (row == SCAN-1)
            begin
              row <= 0;
              if (plane == BPP-1)
                plane <= 0;
              else
                plane <= plane + 1'b1;
            end
            else
            begin
              row <= row + 1'b1;
            end
            phase <= 1'b0;
            state <= S_SHIFT;
          end
          else
          begin
            hub_oe_n <= 1'b0;          // lit
            disp_cnt <= disp_cnt - 1'b1;
          end
        end

        default:
          state <= S_SHIFT;
      endcase
    end
  end
endmodule

// FRAMEBUFFER : COLS*ROWS words of 3*BPP bits, one sync write + two async
// reads (upper/lower half). Small panels map to distributed RAM; large panels
// map to the 32 kbit BRAM. For simulation it is preloaded with a hex image.

module hub75_framebuffer #(
    parameter integer COLS = 8,
    parameter integer ROWS = 8,
    parameter integer BPP = 4
  ) (
    input wire clk,
    // write port (ESP32-S3 SPI target on hardware)
    input wire we,
    input wire [$clog2(ROWS*COLS)-1:0] waddr,
    input wire [3*BPP-1:0] wdata,
    // dual asynchronous read (upper / lower half)
    input wire [$clog2(ROWS*COLS)-1:0] raddr_u,
    output wire [3*BPP-1:0] rdata_u,
    input wire [$clog2(ROWS*COLS)-1:0] raddr_l,
    output wire [3*BPP-1:0] rdata_l
  );
  localparam integer DEPTH = ROWS * COLS;
  localparam integer W = 3 * BPP;

  reg [W-1:0] mem [0:DEPTH-1];

`ifdef HUB75_SIM_INIT

  initial
    $readmemh(`HUB75_INIT_FILE, mem);
`endif

  always @(posedge clk)
    if (we)
      mem[waddr] <= wdata;

  assign rdata_u = mem[raddr_u];
  assign rdata_l = mem[raddr_l];
endmodule
