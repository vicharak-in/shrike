// =============================================================================
// servant_shrike.v -- SERV top-level for Shrike Lite (SLG47910 ForgeFPGA)
// Board   : Shrike Lite (SLG47910 + RP2040)
// Tool    : Go Configure Software Hub
//
//   - SPI bootloader FSM 
//   - 4-slice BRAM (BRAM0..3) unified instruction+data RAM via servant_ram
//   - serv_rf_ram left as generic reg[] (576x2-bit, GoHub infers as LUT RAM)
//
// SPI PROTOCOL (Mode 0, MSB-first, 8-bit):
//   0xA0          halt CPU, reset write pointer
//   <N bytes>     firmware image, little-endian words (4 bytes per word)
//   0xA2          release CPU to run
//   0xA3          halt CPU (re-arm before next 0xA0)
//
// BRAM SPLIT:
//   BRAM0..3 = unified IMEM+DMEM (servant_ram, SPI-loaded)
// =============================================================================

`default_nettype none

(* top *) module shrike_top (
  (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
  (* iopad_external_pin *)                 output wire clk_en,

  // SPI program-load interface (RP2040 is controller)
  (* iopad_external_pin *) input  wire spi_sck,
  (* iopad_external_pin *) input  wire spi_ss_n,
  (* iopad_external_pin *) input  wire spi_mosi,

  // GPIO output (replaces original `q` pin)
  (* iopad_external_pin *) output wire q,
  (* iopad_external_pin *) output wire q_en,

  // BRAM0..3: unified instruction+data RAM (auto-routed by GoHub)
  (* iopad_external_pin *) output wire [1:0] BRAM0_RATIO,
  (* iopad_external_pin *) output wire [7:0] BRAM0_DATA_IN,
  (* iopad_external_pin *) output wire       BRAM0_WEN,
  (* iopad_external_pin *) output wire       BRAM0_WCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM0_WRITE_ADDR,
  (* iopad_external_pin *) input  wire [7:0] BRAM0_DATA_OUT,
  (* iopad_external_pin *) output wire       BRAM0_REN,
  (* iopad_external_pin *) output wire       BRAM0_RCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM0_READ_ADDR,

  (* iopad_external_pin *) output wire [1:0] BRAM1_RATIO,
  (* iopad_external_pin *) output wire [7:0] BRAM1_DATA_IN,
  (* iopad_external_pin *) output wire       BRAM1_WEN,
  (* iopad_external_pin *) output wire       BRAM1_WCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM1_WRITE_ADDR,
  (* iopad_external_pin *) input  wire [7:0] BRAM1_DATA_OUT,
  (* iopad_external_pin *) output wire       BRAM1_REN,
  (* iopad_external_pin *) output wire       BRAM1_RCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM1_READ_ADDR,

  (* iopad_external_pin *) output wire [1:0] BRAM2_RATIO,
  (* iopad_external_pin *) output wire [7:0] BRAM2_DATA_IN,
  (* iopad_external_pin *) output wire       BRAM2_WEN,
  (* iopad_external_pin *) output wire       BRAM2_WCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM2_WRITE_ADDR,
  (* iopad_external_pin *) input  wire [7:0] BRAM2_DATA_OUT,
  (* iopad_external_pin *) output wire       BRAM2_REN,
  (* iopad_external_pin *) output wire       BRAM2_RCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM2_READ_ADDR,

  (* iopad_external_pin *) output wire [1:0] BRAM3_RATIO,
  (* iopad_external_pin *) output wire [7:0] BRAM3_DATA_IN,
  (* iopad_external_pin *) output wire       BRAM3_WEN,
  (* iopad_external_pin *) output wire       BRAM3_WCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM3_WRITE_ADDR,
  (* iopad_external_pin *) input  wire [7:0] BRAM3_DATA_OUT,
  (* iopad_external_pin *) output wire       BRAM3_REN,
  (* iopad_external_pin *) output wire       BRAM3_RCLKEN,
  (* iopad_external_pin *) output wire [8:0] BRAM3_READ_ADDR
);

  assign clk_en = 1'b1;
  assign q_en      = 1'b1;

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  parameter memsize        = 128;   // words (32-bit), must match PROG_WORDS below
  parameter reset_strategy = "MINI";
  parameter width          = 1;
  parameter with_csr       = 1;

  localparam aw       = $clog2(memsize);
  localparam csr_regs = with_csr * 4;
  localparam rf_width = width * 2;
  localparam rf_l2d   = $clog2((32 + csr_regs) * 32 / rf_width);


  // ---------------------------------------------------------------------------
  // Power-on reset: hold everything until fabric settles (~16 cycles)
  // ---------------------------------------------------------------------------
  reg [3:0] rst_ctr = 4'hF;
  always @(posedge clk)
    if (rst_ctr != 4'h0) rst_ctr <= rst_ctr - 4'h1;
  wire por_resetn = (rst_ctr == 4'h0);

  // SERV active-high reset
  wire wb_rst = ~por_resetn;

  // ---------------------------------------------------------------------------
  // SPI target (byte receiver, MISO unused)
  // ---------------------------------------------------------------------------
  wire [7:0] spi_rx_data;
  wire       spi_rx_valid;

  spi_target #(.CPOL(1'b0), .CPHA(1'b0), .WIDTH(8), .LSB(1'b0)) u_spi (
    .i_clk          (clk),
    .i_rst_n        (por_resetn),
    .i_enable       (1'b1),
    .i_ss_n         (spi_ss_n),
    .i_sck          (spi_sck),
    .i_mosi         (spi_mosi),
    .o_miso         (),
    .o_miso_oe      (),
    .o_rx_data      (spi_rx_data),
    .o_rx_data_valid(spi_rx_valid),
    .i_tx_data      (8'h00),
    .o_tx_data_hold ()
  );

  // Level -> 1-cycle pulse
  reg spi_rx_valid_d;
  always @(posedge clk)
    if (!por_resetn) spi_rx_valid_d <= 1'b0;
    else             spi_rx_valid_d <= spi_rx_valid;
  wire spi_rx_pulse = spi_rx_valid & ~spi_rx_valid_d;

  // ---------------------------------------------------------------------------
  // Bootloader FSM
  // ---------------------------------------------------------------------------
  localparam integer PROG_WORDS = 128;           // must match memsize
  localparam integer PROG_BYTES = PROG_WORDS * 4;

  localparam [7:0] CMD_LOAD = 8'hA0,
                   CMD_RUN  = 8'hA2,
                   CMD_HALT = 8'hA3;

  reg        cpu_run;
  reg        ld_active;
  reg [8:0]  ld_cnt;       // byte index 0..(PROG_BYTES-1), max 512
  reg        ld_we;
  reg [4:0]  ld_word;      // word index 0..(PROG_WORDS-1) -- bits [8:2] of ld_cnt... but PROG_WORDS=128 needs 7 bits
  reg [1:0]  ld_lane;
  reg [7:0]  ld_byte;

  // Note: ld_word is 7 bits wide to support 128-word image (PROG_WORDS=128)
  // Redefine as 7-bit:
  reg [6:0]  ld_word_idx;

  always @(posedge clk) begin
    ld_we <= 1'b0;
    if (!por_resetn) begin
      cpu_run    <= 1'b0;
      ld_active  <= 1'b0;
      ld_cnt     <= 9'd0;
    end else if (spi_rx_pulse) begin
      if (ld_active) begin
        ld_we       <= 1'b1;
        ld_word_idx <= ld_cnt[8:2];   // word = byte_index / 4
        ld_lane     <= ld_cnt[1:0];   // lane = byte_index % 4
        ld_byte     <= spi_rx_data;
        ld_cnt      <= ld_cnt + 9'd1;
        if (ld_cnt == PROG_BYTES - 1)
          ld_active <= 1'b0;
      end else begin
        case (spi_rx_data)
          CMD_LOAD: begin cpu_run <= 1'b0; ld_active <= 1'b1; ld_cnt <= 9'd0; end
          CMD_RUN:  cpu_run <= 1'b1;
          CMD_HALT: cpu_run <= 1'b0;
          default:  ;
        endcase
      end
    end
  end

  wire cpu_rst = wb_rst | ~cpu_run;

  // ---------------------------------------------------------------------------
  // Wishbone wires
  // ---------------------------------------------------------------------------
  wire [31:0] wb_mem_adr;
  wire [31:0] wb_mem_dat;
  wire [3:0]  wb_mem_sel;
  wire        wb_mem_we;
  wire        wb_mem_stb;
  wire [31:0] wb_mem_rdt;
  wire        wb_mem_ack;

  wire        wb_gpio_dat;
  wire        wb_gpio_we;
  wire        wb_gpio_stb;
  wire        wb_gpio_rdt;

  wire [31:0] wb_timer_dat;
  wire        wb_timer_we;
  wire        wb_timer_stb;
  wire [31:0] wb_timer_rdt;

  wire [31:0] wb_ext_adr;
  wire [31:0] wb_ext_dat;
  wire [3:0]  wb_ext_sel;
  wire        wb_ext_we;
  wire        wb_ext_stb;
  wire [31:0] wb_ext_rdt;
  wire        wb_ext_ack;

  wire [rf_l2d-1:0]   rf_waddr;
  wire [rf_width-1:0] rf_wdata;
  wire                rf_wen;
  wire [rf_l2d-1:0]   rf_raddr;
  wire                rf_ren;
  wire [rf_width-1:0] rf_rdata;

  wire timer_irq;

  // ---------------------------------------------------------------------------
  // servant_mux: routes ext bus to GPIO or Timer
  // ---------------------------------------------------------------------------
  servant_mux servant_mux (
    .i_clk          (clk),
    .i_rst          (cpu_rst & (reset_strategy != "NONE")),
    .i_wb_cpu_adr   (wb_ext_adr),
    .i_wb_cpu_dat   (wb_ext_dat),
    .i_wb_cpu_sel   (wb_ext_sel),
    .i_wb_cpu_we    (wb_ext_we),
    .i_wb_cpu_cyc   (wb_ext_stb),
    .o_wb_cpu_rdt   (wb_ext_rdt),
    .o_wb_cpu_ack   (wb_ext_ack),
    .o_wb_gpio_dat  (wb_gpio_dat),
    .o_wb_gpio_we   (wb_gpio_we),
    .o_wb_gpio_cyc  (wb_gpio_stb),
    .i_wb_gpio_rdt  (wb_gpio_rdt),
    .o_wb_timer_dat (wb_timer_dat),
    .o_wb_timer_we  (wb_timer_we),
    .o_wb_timer_cyc (wb_timer_stb),
    .i_wb_timer_rdt (wb_timer_rdt)
  );

  // ---------------------------------------------------------------------------
  // servant_ram: BRAM0..3 unified IMEM+DMEM + SPI write port
  // ---------------------------------------------------------------------------
  servant_ram #(
    .depth           (memsize),
    .RESET_STRATEGY  (reset_strategy)
  ) ram (
    // SPI loader
    .ld_we           (ld_we),
    .ld_word         (ld_word_idx),        // full 7 bits for 128-word image
    .ld_lane         (ld_lane),
    .ld_byte         (ld_byte),
    // Wishbone
    .i_wb_clk        (clk),
    .i_wb_rst        (cpu_rst),
    .i_wb_adr        (wb_mem_adr[aw-1:2]),
    .i_wb_dat        (wb_mem_dat),
    .i_wb_sel        (wb_mem_sel),
    .i_wb_we         (wb_mem_we),
    .i_wb_cyc        (wb_mem_stb),
    .o_wb_rdt        (wb_mem_rdt),
    .o_wb_ack        (wb_mem_ack),
    // BRAM ports
    .BRAM0_RATIO     (BRAM0_RATIO),   .BRAM0_DATA_IN   (BRAM0_DATA_IN),
    .BRAM0_WEN       (BRAM0_WEN),     .BRAM0_WCLKEN    (BRAM0_WCLKEN),
    .BRAM0_WRITE_ADDR(BRAM0_WRITE_ADDR), .BRAM0_DATA_OUT(BRAM0_DATA_OUT),
    .BRAM0_REN       (BRAM0_REN),     .BRAM0_RCLKEN    (BRAM0_RCLKEN),
    .BRAM0_READ_ADDR (BRAM0_READ_ADDR),
    .BRAM1_RATIO     (BRAM1_RATIO),   .BRAM1_DATA_IN   (BRAM1_DATA_IN),
    .BRAM1_WEN       (BRAM1_WEN),     .BRAM1_WCLKEN    (BRAM1_WCLKEN),
    .BRAM1_WRITE_ADDR(BRAM1_WRITE_ADDR), .BRAM1_DATA_OUT(BRAM1_DATA_OUT),
    .BRAM1_REN       (BRAM1_REN),     .BRAM1_RCLKEN    (BRAM1_RCLKEN),
    .BRAM1_READ_ADDR (BRAM1_READ_ADDR),
    .BRAM2_RATIO     (BRAM2_RATIO),   .BRAM2_DATA_IN   (BRAM2_DATA_IN),
    .BRAM2_WEN       (BRAM2_WEN),     .BRAM2_WCLKEN    (BRAM2_WCLKEN),
    .BRAM2_WRITE_ADDR(BRAM2_WRITE_ADDR), .BRAM2_DATA_OUT(BRAM2_DATA_OUT),
    .BRAM2_REN       (BRAM2_REN),     .BRAM2_RCLKEN    (BRAM2_RCLKEN),
    .BRAM2_READ_ADDR (BRAM2_READ_ADDR),
    .BRAM3_RATIO     (BRAM3_RATIO),   .BRAM3_DATA_IN   (BRAM3_DATA_IN),
    .BRAM3_WEN       (BRAM3_WEN),     .BRAM3_WCLKEN    (BRAM3_WCLKEN),
    .BRAM3_WRITE_ADDR(BRAM3_WRITE_ADDR), .BRAM3_DATA_OUT(BRAM3_DATA_OUT),
    .BRAM3_REN       (BRAM3_REN),     .BRAM3_RCLKEN    (BRAM3_RCLKEN),
    .BRAM3_READ_ADDR (BRAM3_READ_ADDR)
  );

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------
  servant_timer #(
    .RESET_STRATEGY (reset_strategy),
    .WIDTH          (32)
  ) timer (
    .i_clk    (clk),
    .i_rst    (cpu_rst),
    .o_irq    (timer_irq),
    .i_wb_cyc (wb_timer_stb),
    .i_wb_we  (wb_timer_we),
    .i_wb_dat (wb_timer_dat),
    .o_wb_dat (wb_timer_rdt)
  );

  // ---------------------------------------------------------------------------
  // GPIO
  // ---------------------------------------------------------------------------
  servant_gpio gpio (
    .i_wb_clk (clk),
    .i_wb_dat (wb_gpio_dat),
    .i_wb_we  (wb_gpio_we),
    .i_wb_cyc (wb_gpio_stb),
    .o_wb_rdt (wb_gpio_rdt),
    .o_gpio   (q)
  );

  // ---------------------------------------------------------------------------
  // Register file RAM (generic reg[], GoHub infers as LUT RAM)
  // serv_rf_ram: width=2, depth=576 entries 
  // ---------------------------------------------------------------------------
  serv_rf_ram #(
    .width    (rf_width),
    .csr_regs (csr_regs)
  ) rf_ram (
    .i_clk   (clk),
    .i_waddr (rf_waddr),
    .i_wdata (rf_wdata),
    .i_wen   (rf_wen),
    .i_raddr (rf_raddr),
    .i_ren   (rf_ren),
    .o_rdata (rf_rdata)
  );

  // ---------------------------------------------------------------------------
  // SERV CPU wrapper (servile = SERV + RF protocol + I/D bus arbiter)
  // ---------------------------------------------------------------------------
  servile #(
    .width    (width),
    .sim      (1'b0),
    .debug    (1'b0),
    .with_c   (1'b0),
    .with_csr (with_csr[0]),
    .with_mdu (1'b0)
  ) cpu (
    .i_clk        (clk),
    .i_rst        (cpu_rst),
    .i_timer_irq  (timer_irq),

    .o_wb_mem_adr (wb_mem_adr),
    .o_wb_mem_dat (wb_mem_dat),
    .o_wb_mem_sel (wb_mem_sel),
    .o_wb_mem_we  (wb_mem_we),
    .o_wb_mem_stb (wb_mem_stb),
    .i_wb_mem_rdt (wb_mem_rdt),
    .i_wb_mem_ack (wb_mem_ack),

    .o_wb_ext_adr (wb_ext_adr),
    .o_wb_ext_dat (wb_ext_dat),
    .o_wb_ext_sel (wb_ext_sel),
    .o_wb_ext_we  (wb_ext_we),
    .o_wb_ext_stb (wb_ext_stb),
    .i_wb_ext_rdt (wb_ext_rdt),
    .i_wb_ext_ack (wb_ext_ack),

    .o_rf_waddr  (rf_waddr),
    .o_rf_wdata  (rf_wdata),
    .o_rf_wen    (rf_wen),
    .o_rf_raddr  (rf_raddr),
    .o_rf_ren    (rf_ren),
    .i_rf_rdata  (rf_rdata)
  );

endmodule
