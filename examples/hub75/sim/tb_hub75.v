// tb_hub75.v  -  Self-checking testbench for the parameterised HUB75 driver
//
// Strategy: this bench is a *virtual HUB75 panel*. It watches only the real
// external pins (hub_rgb / hub_addr / hub_clk / hub_lat / hub_oe_n), exactly
// as a physical panel would:
//   1. sample the 6 colour bits on every rising edge of hub_clk into a line
//      shift buffer (one entry per column),
//   2. on each latch, remember that line + its row address,
//   3. measure how many cycles hub_oe_n stays low (lit) for that line — that
//      is the bit-plane weight (DISP_BASE << plane),
//   4. accumulate bit*weight per pixel/channel over exactly one full frame.
//
// The recovered brightness (acc / DISP_BASE) must equal the BPP-bit value the
// framebuffer was loaded with. The bench reads the SAME hex image as expected
// data and reports PASS/FAIL plus a visual dump.
//
// Frame boundaries are found from the panel pins alone (counting latched
// lines); no design internals are needed.
//
// Run:  see sim/Makefile  or  sim/run_sim.ps1

`timescale 1ns/1ps
`default_nettype none

module tb_hub75;

  // geometry / colour (override from the command line with
  // -DP_COLS=.. -DP_ROWS=.. -DP_BPP=.. ; keep in sync with the image)
  `ifndef P_COLS
`define P_COLS 8
`endif
          `ifndef P_ROWS
`define P_ROWS 8
`endif
          `ifndef P_BPP
`define P_BPP 4
`endif
          localparam integer COLS = `P_COLS;
  localparam integer ROWS = `P_ROWS;
  localparam integer BPP = `P_BPP;
  localparam integer DISP_BASE = 1;

  function integer clog2;
    input integer value;
    integer v;
    begin
      v = value - 1;
      for (clog2 = 0; v > 0; clog2 = clog2 + 1)
        v = v >> 1;
    end
  endfunction

  localparam integer SCAN = ROWS / 2;
  localparam integer ADDR_BITS = clog2(ROWS/2);
  localparam integer PIX_BITS = 3 * BPP;
  localparam integer MAXV = (1 << BPP) - 1;
  localparam integer FRAME_LINES = BPP * SCAN; // latched lines per frame

  // clock / reset
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  always #10 clk = ~clk; // 50 MHz (20 ns period)

  // DUT interface
  wire clk_en;
  wire [5:0] hub_rgb;
  wire [ADDR_BITS-1:0] hub_addr;
  wire hub_clk, hub_lat, hub_oe_n;
  wire [5:0] hub_rgb_oe;
  wire [ADDR_BITS-1:0] hub_addr_oe;
  wire hub_clk_oe, hub_lat_oe, hub_oe_n_oe;

  hub75_top #(
              .COLS(COLS), .ROWS(ROWS), .BPP(BPP), .DISP_BASE(DISP_BASE)
            ) dut (
              .clk(clk), .rst_n(rst_n), .clk_en(clk_en),
              .hub_rgb(hub_rgb), .hub_addr(hub_addr),
              .hub_clk(hub_clk), .hub_lat(hub_lat), .hub_oe_n(hub_oe_n),
              .hub_rgb_oe(hub_rgb_oe), .hub_addr_oe(hub_addr_oe),
              .hub_clk_oe(hub_clk_oe), .hub_lat_oe(hub_lat_oe),
              .hub_oe_n_oe(hub_oe_n_oe)
            );

  // ---- expected image (same file the framebuffer was preloaded with) ----
  reg [PIX_BITS-1:0] exp_mem [0:ROWS*COLS-1];
  initial
    $readmemh(`HUB75_INIT_FILE, exp_mem);

  // ---- virtual-panel decode state ----
  reg [5:0] cap [0:COLS-1]; // colour bits captured this line
  reg [5:0] pend [0:COLS-1]; // line awaiting its display measurement
  integer capcol;
  reg [7:0] pend_addr;
  reg have_pending;
  integer oe_low_count;
  integer commit_count;
  reg prev_hclk, prev_lat;
  integer done;

  // recovered brightness accumulators, flat index (row*COLS+col)*3 + ch
  integer acc [0:ROWS*COLS*3-1];

  function integer aidx;
    input integer row;
    input integer col;
    input integer ch;
    aidx = (row*COLS + col)*3 + ch;
  endfunction

  integer i;
  initial
  begin
    capcol = 0;
    have_pending = 0;
    oe_low_count = 0;
    commit_count = 0;
    prev_hclk = 0;
    prev_lat = 0;
    done = 0;
    for (i = 0; i < ROWS*COLS*3; i = i + 1)
      acc[i] = 0;
  end

  // one clean synchronous "panel receiver"
  integer c;
  always @(posedge clk)
  begin
    if (rst_n && !done)
    begin
      // (1) sample a shifted pixel on rising hub_clk
      if (hub_clk && !prev_hclk)
      begin
        if (capcol < COLS)
          cap[capcol] = hub_rgb;
        capcol = capcol + 1;
      end

      // (2) integrate lit time of the currently-displayed line
      if (!hub_oe_n)
        oe_low_count = oe_low_count + 1;

      // (3) on latch: commit the previous line, load the new one
      if (hub_lat && !prev_lat)
      begin
        if (have_pending)
        begin
          for (c = 0; c < COLS; c = c + 1)
          begin
            // upper half -> row = pend_addr ; {b1,g1,r1} = pend[2:0]
            acc[aidx(pend_addr, c, 0)] = acc[aidx(pend_addr, c, 0)] + pend[c][0]*oe_low_count; // R
            acc[aidx(pend_addr, c, 1)] = acc[aidx(pend_addr, c, 1)] + pend[c][1]*oe_low_count; // G
            acc[aidx(pend_addr, c, 2)] = acc[aidx(pend_addr, c, 2)] + pend[c][2]*oe_low_count; // B
            // lower half -> row = pend_addr+SCAN ; {b2,g2,r2} = pend[5:3]
            acc[aidx(pend_addr+SCAN, c, 0)] = acc[aidx(pend_addr+SCAN, c, 0)] + pend[c][3]*oe_low_count; // R
            acc[aidx(pend_addr+SCAN, c, 1)] = acc[aidx(pend_addr+SCAN, c, 1)] + pend[c][4]*oe_low_count; // G
            acc[aidx(pend_addr+SCAN, c, 2)] = acc[aidx(pend_addr+SCAN, c, 2)] + pend[c][5]*oe_low_count; // B
          end
          commit_count = commit_count + 1;
          if (commit_count == FRAME_LINES)
          begin
            done = 1;
            evaluate;
          end
        end
        // load freshly-shifted line as the new pending line
        for (c = 0; c < COLS; c = c + 1)
          pend[c] = cap[c];
        pend_addr = hub_addr;
        have_pending = 1;
        oe_low_count = 0;
        capcol = 0;
      end

      prev_hclk = hub_clk;
      prev_lat = hub_lat;
    end
  end

  // ---- compare recovered frame to the expected image ----
  task evaluate;
    integer r, col2, ch;
    integer got, expv, errors;
    reg [PIX_BITS-1:0] e;
    begin
      errors = 0;
      $display("");
      $display("=== HUB75 %0dx%0d, BPP=%0d, DISP_BASE=%0d : recovered vs expected ===",
               COLS, ROWS, BPP, DISP_BASE);
      for (r = 0; r < ROWS; r = r + 1)
      begin
        for (col2 = 0; col2 < COLS; col2 = col2 + 1)
        begin
          e = exp_mem[r*COLS + col2];
          for (ch = 0; ch < 3; ch = ch + 1)
          begin
            got  = acc[aidx(r,col2,ch)] / DISP_BASE;
            // expected channel: ch0=R[MSBs],ch1=G,ch2=B[LSBs]
            case (ch)
              0:
                expv = e[3*BPP-1 -: BPP]; // R
              1:
                expv = e[2*BPP-1 -: BPP]; // G
              2:
                expv = e[1*BPP-1 -: BPP]; // B
            endcase
            if (got !== expv)
            begin
              errors = errors + 1;
              $display("  MISMATCH (r=%0d,c=%0d,%s) got=%0d exp=%0d",
                       r, col2,
                       (ch==0)?"R":(ch==1)?"G":"B", got, expv);
            end
          end
        end
      end

      // visual dump
      $display("");
      $display("--- EXPECTED (RGB hex per pixel) ---");
      dump_expected;
      $display("--- RECOVERED (RGB hex per pixel) ---");
      dump_recovered;
      $display("--- ASCII (dominant colour, '.'=off) ---");
      dump_ascii;

      $display("");
      if (errors == 0)
        $display("RESULT: PASS  (all %0d pixels x 3 channels match)",
                 ROWS*COLS);
      else
        $display("RESULT: FAIL  (%0d channel mismatches)", errors);
      $display("");
      $finish;
    end
  endtask

  task dump_expected;
    integer r, col2;
    reg [PIX_BITS-1:0] e;
    begin
      for (r=0;r<ROWS;r=r+1)
      begin
        $write("  ");
        for (col2=0;col2<COLS;col2=col2+1)
        begin
          e = exp_mem[r*COLS+col2];
          $write("%h%h%h ", e[3*BPP-1 -: BPP], e[2*BPP-1 -: BPP], e[1*BPP-1 -: BPP]);
        end
        $write("\n");
      end
    end
  endtask

  task dump_recovered;
    integer r, col2;
    begin
      for (r=0;r<ROWS;r=r+1)
      begin
        $write("  ");
        for (col2=0;col2<COLS;col2=col2+1)
          $write("%0h%0h%0h ", (acc[aidx(r,col2,0)]/DISP_BASE) & MAXV,
                 (acc[aidx(r,col2,1)]/DISP_BASE) & MAXV,
                 (acc[aidx(r,col2,2)]/DISP_BASE) & MAXV);
        $write("\n");
      end
    end
  endtask

  task dump_ascii;
    integer r, col2, R, G, B;
    reg [7:0] ch;
    begin
      for (r=0;r<ROWS;r=r+1)
      begin
        $write("  ");
        for (col2=0;col2<COLS;col2=col2+1)
        begin
          R = acc[aidx(r,col2,0)]/DISP_BASE;
          G = acc[aidx(r,col2,1)]/DISP_BASE;
          B = acc[aidx(r,col2,2)]/DISP_BASE;
          if (R==0 && G==0 && B==0)
            ch = ".";
          else if (R>=G && R>=B)
            ch = "R";
          else if (G>=R && G>=B)
            ch = "G";
          else
            ch = "B";
          $write("%s", ch);
        end
        $write("\n");
      end
    end
  endtask

  // ---- stimulus + safety timeout + waveforms ----
  initial
  begin
    $dumpfile("tb_hub75.vcd");
    $dumpvars(0, tb_hub75);
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;                       // release reset

    // generous cap: a few frames worth of cycles
    #(FRAME_LINES * (2*COLS + 4 + (DISP_BASE<<BPP)) * 20 * 4);
    if (!done)
    begin
      $display("RESULT: FAIL  (timeout: only %0d/%0d lines committed)",
               commit_count, FRAME_LINES);
      $finish;
    end
  end

endmodule

`default_nettype wire
