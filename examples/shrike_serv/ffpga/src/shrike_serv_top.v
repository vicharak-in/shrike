// =============================================================================
// shrike_serv_top.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA + RP2040)
// Tool     : Go Configure Software Hub  (Yosys + Forge PnR)
//
// SERV (Olof Kindgren's bit-serial RV32I) as a RUNTIME-PROGRAMMABLE core: the
// host MCU streams a program into the 4 KB BRAM over SPI while the core is held
// in reset, then releases it -- no re-synthesis, no new bitstream. ONE bitstream
// runs three things by loading a different program each time:
//   * the rv32ui conformance suite  -- each test stores its verdict, read back
//     on the GPIO result pins
//   * compiled C programs           -- same result-pin pass/fail
//   * an interactive UART monitor   -- a serv> shell you talk to from a laptop
//
// MEMORY: SERV keeps its register file in DISTRIBUTED RAM (serv_rf_ram), so all
// eight BRAM slices form one unified 4 KB program+data memory (serv_mem_bram).
// The core's wb_mem bus reads it with a 1-cycle synchronous wait-state.
//
// MEMORY-MAPPED I/O (wb_ext, 0x4000_0000 region; decode on adr[4:2]):
//   0x4000_0000  result latch -- store: low 2 bits -> GPIO17/18 (suite / C flow)
//                                bit1 = PASS (value==1), bit0 = done (any store)
//   0x4000_0010  UART data    -- write = TX a byte; read = last RX byte
//   0x4000_0014  UART status  -- bit0 = RX byte valid, bit1 = TX busy
//   0x4000_0018  LED          -- bit0 -> FPGA GPIO16 (on-board FPGA LED)
//   0x4000_001C  cycles       -- free-running 24-bit cycle counter (read)
// The result latch and the UART live at different addresses, so a conformance
// test's pass/fail store never collides with the monitor's UART traffic.
//
// SPI LOAD PROTOCOL (Mode 0, MSB-first, 8-bit; reuse spi_target.v):
//   0xA0  enter load (halt core, reset write pointer)
//   4096 bytes  program image, little-endian, zero-padded to the fixed length
//   0xA2  run (release the core)     0xA3  halt (re-arm before a new 0xA0)
//
// UART BUS (board's dedicated FPGA<->RP2040 UART pins, 115200 8N1):
//   FPGA pin 4 = TX (-> RP2040 GPIO1, its UART0 RX)
//   FPGA pin 6 = RX (<- RP2040 GPIO0, its UART0 TX)
// Pin 4 is shared with the SPI load chip-select: it is the SPI slave select
// (input) while the core is held in reset for loading, and becomes the UART TX
// (output, o_uart_tx_oe = cpu_run) once the core is released. The host mirrors
// this: GPIO1 is the SPI CS during load, then its UART0 RX during run. Demos
// that do not use the UART simply never drive it (it idles high).
//
// CLOCKING: fabric runs from the PLL at 25 MHz (50 MHz OSC overclocks SERV;
//   tool Fmax for this design is ~38.6 MHz, so 25 MHz keeps ~1.5x margin).
//   clk = PLL_CLK; clk_en keeps the OSC alive as the PLL reference; the pll_*
//   control pins enable and program the PLL from fabric logic (Renesas AN-003).
//
// IO PLANNER: every BRAM0-7 port and both bank clock feeds MUST be pinned, plus
//   result_bit0/1(+en), pin 4 (i_spi_ss / o_uart_tx / o_uart_tx_oe on one pad),
//   pin 6 (i_uart_rx) and GPIO16 (o_led). Un-pinned BRAM is placed but never
//   wired (writes lost, reads junk, no warning); result pins on interior IOBs
//   read as floating.
// =============================================================================

(* top *) module shrike_serv_top (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,   // PLL_CLK, 25 MHz
    (* iopad_external_pin *) output wire clk_en,                // OSC enable (PLL reference)

    // PLL: 50 MHz overclocks this design; run the fabric at 25 MHz
    (* iopad_external_pin *) output wire        pll_en,
    (* iopad_external_pin *) output wire        pll_bypass,
    (* iopad_external_pin *) output wire        pll_clk_selection,
    (* iopad_external_pin *) output wire [5:0]  pll_refdiv,
    (* iopad_external_pin *) output wire [11:0] pll_fbdiv,
    (* iopad_external_pin *) output wire [2:0]  pll_postdiv1,
    (* iopad_external_pin *) output wire [2:0]  pll_postdiv2,

    // SPI program-load (pins 3/5 + the shared pin 4 select). MCU is controller.
    (* iopad_external_pin *) input  wire spi_sck,   // FPGA pin 3
    (* iopad_external_pin *) input  wire spi_mosi,  // FPGA pin 5

    // FPGA pin 4: SPI select (input) while loading, UART TX (output) while running
    (* iopad_external_pin *) input  wire i_spi_ss,      // pin 4 as SPI slave select
    (* iopad_external_pin *) output wire o_uart_tx,     // pin 4 as UART TX
    (* iopad_external_pin *) output wire o_uart_tx_oe,  // drive pin 4 only when running

    // FPGA pin 6: UART RX (from RP2040 UART0 TX)
    (* iopad_external_pin *) input  wire i_uart_rx,

    // CPU result readback (suite / C flow) -> GPIO17/18 -> RP2040 GPIO15/14
    (* iopad_external_pin *) output wire result_bit0,
    (* iopad_external_pin *) output wire result_bit0_en,
    (* iopad_external_pin *) output wire result_bit1,
    (* iopad_external_pin *) output wire result_bit1_en,

    // FPGA GPIO16: on-board FPGA LED
    (* iopad_external_pin *) output wire o_led,
    (* iopad_external_pin *) output wire o_led_oe,

    // Unified 4 KB memory across BRAM0..7, auto-routed
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
    (* iopad_external_pin *) output wire [8:0] BRAM3_READ_ADDR,
    (* iopad_external_pin *) output wire [1:0] BRAM4_RATIO,
    (* iopad_external_pin *) output wire [7:0] BRAM4_DATA_IN,
    (* iopad_external_pin *) output wire       BRAM4_WEN,
    (* iopad_external_pin *) output wire       BRAM4_WCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM4_WRITE_ADDR,
    (* iopad_external_pin *) input  wire [7:0] BRAM4_DATA_OUT,
    (* iopad_external_pin *) output wire       BRAM4_REN,
    (* iopad_external_pin *) output wire       BRAM4_RCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM4_READ_ADDR,
    (* iopad_external_pin *) output wire [1:0] BRAM5_RATIO,
    (* iopad_external_pin *) output wire [7:0] BRAM5_DATA_IN,
    (* iopad_external_pin *) output wire       BRAM5_WEN,
    (* iopad_external_pin *) output wire       BRAM5_WCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM5_WRITE_ADDR,
    (* iopad_external_pin *) input  wire [7:0] BRAM5_DATA_OUT,
    (* iopad_external_pin *) output wire       BRAM5_REN,
    (* iopad_external_pin *) output wire       BRAM5_RCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM5_READ_ADDR,
    (* iopad_external_pin *) output wire [1:0] BRAM6_RATIO,
    (* iopad_external_pin *) output wire [7:0] BRAM6_DATA_IN,
    (* iopad_external_pin *) output wire       BRAM6_WEN,
    (* iopad_external_pin *) output wire       BRAM6_WCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM6_WRITE_ADDR,
    (* iopad_external_pin *) input  wire [7:0] BRAM6_DATA_OUT,
    (* iopad_external_pin *) output wire       BRAM6_REN,
    (* iopad_external_pin *) output wire       BRAM6_RCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM6_READ_ADDR,
    (* iopad_external_pin *) output wire [1:0] BRAM7_RATIO,
    (* iopad_external_pin *) output wire [7:0] BRAM7_DATA_IN,
    (* iopad_external_pin *) output wire       BRAM7_WEN,
    (* iopad_external_pin *) output wire       BRAM7_WCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM7_WRITE_ADDR,
    (* iopad_external_pin *) input  wire [7:0] BRAM7_DATA_OUT,
    (* iopad_external_pin *) output wire       BRAM7_REN,
    (* iopad_external_pin *) output wire       BRAM7_RCLKEN,
    (* iopad_external_pin *) output wire [8:0] BRAM7_READ_ADDR
);

    localparam integer CLK_HZ = 25_000_000;
    localparam integer BAUD   = 115200;

    assign clk_en            = 1'b1;
    // Fout = 50 * FBDIV / (REFDIV * POSTDIV1 * POSTDIV2) = 50*21/(1*7*6) = 25 MHz
    assign pll_en            = 1'b1;
    assign pll_bypass        = 1'b0;
    assign pll_clk_selection = 1'b0;   // reference = internal OSC
    assign pll_refdiv        = 6'd1;
    assign pll_fbdiv         = 12'd21;
    assign pll_postdiv1      = 3'd7;
    assign pll_postdiv2      = 3'd6;
    assign result_bit0_en    = 1'b1;
    assign result_bit1_en    = 1'b1;
    assign o_led_oe          = 1'b1;

    // --- SERV regfile geometry (width=1, with_csr=1): 36 regs, 2-bit RF lanes ---
    localparam integer RF_WIDTH = 2;
    localparam integer RF_L2D   = 10;   // clog2(36*32/2) = clog2(576)

    // --- Power-on reset: holds SPI + loader until the fabric settles ---
    reg [3:0] rst_ctr = 4'hF;
    always @(posedge clk)
        if (rst_ctr != 4'h0) rst_ctr <= rst_ctr - 4'h1;
    wire por_resetn = (rst_ctr == 4'h0);

    // -------------------------------------------------------------------------
    // SPI target (program-load ingress). Disabled once the core runs, so pin 4
    // is free to become the UART TX. MISO unused.
    // -------------------------------------------------------------------------
    wire [7:0] spi_rx_data;
    wire       spi_rx_valid;

    reg cpu_run;   // declared early: gates the SPI target and the pin-4 direction

    spi_target #(.CPOL(1'b0), .CPHA(1'b0), .WIDTH(8), .LSB(1'b0)) u_spi (
        .i_clk(clk), .i_rst_n(por_resetn), .i_enable(~cpu_run),
        .i_ss_n(i_spi_ss), .i_sck(spi_sck), .i_mosi(spi_mosi),
        .o_miso(), .o_miso_oe(),
        .o_rx_data(spi_rx_data), .o_rx_data_valid(spi_rx_valid),
        .i_tx_data(8'h00), .o_tx_data_hold()
    );

    // Edge-detect the byte-valid level into a 1-cycle receive pulse.
    reg spi_rx_valid_d;
    always @(posedge clk)
        if (!por_resetn) spi_rx_valid_d <= 1'b0;
        else             spi_rx_valid_d <= spi_rx_valid;
    wire spi_rx_pulse = spi_rx_valid & ~spi_rx_valid_d;

    // -------------------------------------------------------------------------
    // Bootloader FSM: command dispatch + program streaming into the memory.
    // -------------------------------------------------------------------------
    localparam integer PROG_BYTES = 4096;          // 1024 words x 4 bytes (full 4 KB)
    localparam [7:0] CMD_LOAD = 8'hA0,             // halt + reset write pointer
                     CMD_RUN  = 8'hA2,             // release core
                     CMD_HALT = 8'hA3;             // hold core in reset

    reg         ld_active;    // 1 = streaming program bytes into memory
    reg [12:0]  ld_cnt;       // byte index 0..4095
    reg         ld_we;        // 1-cycle memory write strobe
    reg [9:0]   ld_word;      // memory word index 0..1023
    reg [1:0]   ld_lane;      // byte lane 0..3
    reg [7:0]   ld_byte;      // byte to write

    always @(posedge clk) begin
        ld_we <= 1'b0;
        if (!por_resetn) begin
            cpu_run   <= 1'b0;
            ld_active <= 1'b0;
            ld_cnt    <= 13'd0;
        end else if (spi_rx_pulse) begin
            if (ld_active) begin
                ld_we   <= 1'b1;
                ld_word <= ld_cnt[11:2];
                ld_lane <= ld_cnt[1:0];
                ld_byte <= spi_rx_data;
                ld_cnt  <= ld_cnt + 13'd1;
                if (ld_cnt == PROG_BYTES-1)
                    ld_active <= 1'b0;             // image complete -> back to IDLE
            end else begin
                case (spi_rx_data)
                    CMD_LOAD: begin cpu_run <= 1'b0; ld_active <= 1'b1; ld_cnt <= 13'd0; end
                    CMD_RUN:  cpu_run <= 1'b1;
                    CMD_HALT: cpu_run <= 1'b0;
                    default:  ; // ignore unknown bytes
                endcase
            end
        end
    end

    // servile's reset is active-high.
    wire cpu_rst = ~(por_resetn & cpu_run);

    // -------------------------------------------------------------------------
    // SERV core (servile: core + arbiter + mux + rf interface)
    // -------------------------------------------------------------------------
    wire [31:0] mem_adr, mem_dat;
    wire [3:0]  mem_sel;
    wire        mem_we, mem_stb;
    wire [31:0] mem_rdt;
    reg         mem_ack;

    wire [31:0] ext_adr, ext_dat;
    wire [3:0]  ext_sel;
    wire        ext_we, ext_stb;
    reg  [31:0] ext_rdt;
    reg         ext_ack;

    wire [RF_L2D-1:0]   rf_waddr, rf_raddr;
    wire [RF_WIDTH-1:0] rf_wdata, rf_rdata;
    wire                rf_wen, rf_ren;

    servile #(
        .width          (1),
        .reset_pc       (32'h0000_0000),
        .reset_strategy ("MINI"),
        .sim            (1'b0),
        .debug          (1'b0),
        .with_c         (1'b0),
        .with_csr       (1'b1),
        .with_mdu       (1'b0)
    ) cpu (
        .i_clk        (clk),
        .i_rst        (cpu_rst),
        .i_timer_irq  (1'b0),
        .o_wb_mem_adr (mem_adr), .o_wb_mem_dat (mem_dat), .o_wb_mem_sel (mem_sel),
        .o_wb_mem_we  (mem_we),  .o_wb_mem_stb (mem_stb),
        .i_wb_mem_rdt (mem_rdt), .i_wb_mem_ack (mem_ack),
        .o_wb_ext_adr (ext_adr), .o_wb_ext_dat (ext_dat), .o_wb_ext_sel (ext_sel),
        .o_wb_ext_we  (ext_we),  .o_wb_ext_stb (ext_stb),
        .i_wb_ext_rdt (ext_rdt), .i_wb_ext_ack (ext_ack),
        .o_rf_waddr   (rf_waddr), .o_rf_wdata (rf_wdata), .o_rf_wen (rf_wen),
        .o_rf_raddr   (rf_raddr), .o_rf_ren   (rf_ren),   .i_rf_rdata (rf_rdata)
    );

    // Register file in distributed RAM (frees all 8 BRAM slices for memory).
    serv_rf_ram #(.width(RF_WIDTH), .csr_regs(4)) rf_ram (
        .i_clk   (clk),
        .i_waddr (rf_waddr), .i_wdata (rf_wdata), .i_wen (rf_wen),
        .i_raddr (rf_raddr), .i_ren   (rf_ren),   .o_rdata (rf_rdata)
    );

    // -------------------------------------------------------------------------
    // Unified 4 KB memory (BRAM0..7) -- read/written by the core, loaded by SPI
    // -------------------------------------------------------------------------
    serv_mem_bram mem (
        .clk(clk),
        .i_addr(mem_adr), .i_wdata(mem_dat), .i_sel(mem_sel),
        .i_we(mem_we), .i_stb(mem_stb), .o_rdata(mem_rdt),
        .ld_we(ld_we), .ld_word(ld_word), .ld_lane(ld_lane), .ld_byte(ld_byte),
        .BRAM0_RATIO(BRAM0_RATIO), .BRAM0_DATA_IN(BRAM0_DATA_IN),
        .BRAM0_WEN(BRAM0_WEN), .BRAM0_WCLKEN(BRAM0_WCLKEN),
        .BRAM0_WRITE_ADDR(BRAM0_WRITE_ADDR), .BRAM0_DATA_OUT(BRAM0_DATA_OUT),
        .BRAM0_REN(BRAM0_REN), .BRAM0_RCLKEN(BRAM0_RCLKEN), .BRAM0_READ_ADDR(BRAM0_READ_ADDR),
        .BRAM1_RATIO(BRAM1_RATIO), .BRAM1_DATA_IN(BRAM1_DATA_IN),
        .BRAM1_WEN(BRAM1_WEN), .BRAM1_WCLKEN(BRAM1_WCLKEN),
        .BRAM1_WRITE_ADDR(BRAM1_WRITE_ADDR), .BRAM1_DATA_OUT(BRAM1_DATA_OUT),
        .BRAM1_REN(BRAM1_REN), .BRAM1_RCLKEN(BRAM1_RCLKEN), .BRAM1_READ_ADDR(BRAM1_READ_ADDR),
        .BRAM2_RATIO(BRAM2_RATIO), .BRAM2_DATA_IN(BRAM2_DATA_IN),
        .BRAM2_WEN(BRAM2_WEN), .BRAM2_WCLKEN(BRAM2_WCLKEN),
        .BRAM2_WRITE_ADDR(BRAM2_WRITE_ADDR), .BRAM2_DATA_OUT(BRAM2_DATA_OUT),
        .BRAM2_REN(BRAM2_REN), .BRAM2_RCLKEN(BRAM2_RCLKEN), .BRAM2_READ_ADDR(BRAM2_READ_ADDR),
        .BRAM3_RATIO(BRAM3_RATIO), .BRAM3_DATA_IN(BRAM3_DATA_IN),
        .BRAM3_WEN(BRAM3_WEN), .BRAM3_WCLKEN(BRAM3_WCLKEN),
        .BRAM3_WRITE_ADDR(BRAM3_WRITE_ADDR), .BRAM3_DATA_OUT(BRAM3_DATA_OUT),
        .BRAM3_REN(BRAM3_REN), .BRAM3_RCLKEN(BRAM3_RCLKEN), .BRAM3_READ_ADDR(BRAM3_READ_ADDR),
        .BRAM4_RATIO(BRAM4_RATIO), .BRAM4_DATA_IN(BRAM4_DATA_IN),
        .BRAM4_WEN(BRAM4_WEN), .BRAM4_WCLKEN(BRAM4_WCLKEN),
        .BRAM4_WRITE_ADDR(BRAM4_WRITE_ADDR), .BRAM4_DATA_OUT(BRAM4_DATA_OUT),
        .BRAM4_REN(BRAM4_REN), .BRAM4_RCLKEN(BRAM4_RCLKEN), .BRAM4_READ_ADDR(BRAM4_READ_ADDR),
        .BRAM5_RATIO(BRAM5_RATIO), .BRAM5_DATA_IN(BRAM5_DATA_IN),
        .BRAM5_WEN(BRAM5_WEN), .BRAM5_WCLKEN(BRAM5_WCLKEN),
        .BRAM5_WRITE_ADDR(BRAM5_WRITE_ADDR), .BRAM5_DATA_OUT(BRAM5_DATA_OUT),
        .BRAM5_REN(BRAM5_REN), .BRAM5_RCLKEN(BRAM5_RCLKEN), .BRAM5_READ_ADDR(BRAM5_READ_ADDR),
        .BRAM6_RATIO(BRAM6_RATIO), .BRAM6_DATA_IN(BRAM6_DATA_IN),
        .BRAM6_WEN(BRAM6_WEN), .BRAM6_WCLKEN(BRAM6_WCLKEN),
        .BRAM6_WRITE_ADDR(BRAM6_WRITE_ADDR), .BRAM6_DATA_OUT(BRAM6_DATA_OUT),
        .BRAM6_REN(BRAM6_REN), .BRAM6_RCLKEN(BRAM6_RCLKEN), .BRAM6_READ_ADDR(BRAM6_READ_ADDR),
        .BRAM7_RATIO(BRAM7_RATIO), .BRAM7_DATA_IN(BRAM7_DATA_IN),
        .BRAM7_WEN(BRAM7_WEN), .BRAM7_WCLKEN(BRAM7_WCLKEN),
        .BRAM7_WRITE_ADDR(BRAM7_WRITE_ADDR), .BRAM7_DATA_OUT(BRAM7_DATA_OUT),
        .BRAM7_REN(BRAM7_REN), .BRAM7_RCLKEN(BRAM7_RCLKEN), .BRAM7_READ_ADDR(BRAM7_READ_ADDR)
    );

    // -------------------------------------------------------------------------
    // UART cores (115200 8N1). RX samples pin 6 continuously; TX drives pin 4
    // (enabled only while the core runs). Both are clocked at 25 MHz.
    // -------------------------------------------------------------------------
    wire       rx_dv;
    wire [7:0] rx_byte;
    uart_rx #(.CLK(CLK_HZ), .BAUD_RATE(BAUD)) u_rx (
        .i_Clock(clk), .i_RX_Serial(i_uart_rx),
        .o_RX_DV(rx_dv), .o_RX_Byte(rx_byte)
    );

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_done;
    uart_tx #(.IN_CLK_HZ(CLK_HZ), .DATA_FRAME(8), .BAUD_RATE(BAUD),
              .OVERSAMPLING_MODE(16), .STOP_BIT(1), .LSB(1'b0)) u_tx (
        .i_clk(clk), .i_rst(cpu_rst),
        .o_tx(o_uart_tx), .i_tx_data(tx_data), .i_tx_start(tx_start),
        .o_tx_done(tx_done)
    );
    assign o_uart_tx_oe = cpu_run;   // pin 4 is UART TX only while running

    // -------------------------------------------------------------------------
    // wb_ext MMIO: result latch + UART data/status + LED + cycle counter.
    //   decode on adr[4:2]:  0 result | 4 uart-data | 5 uart-status | 6 led | 7 cycles
    //   1-cycle ack matches the servile handshake.
    // -------------------------------------------------------------------------
    reg  [1:0]  gpio_result;
    reg  [7:0]  rx_data;
    reg         rx_valid;
    reg         tx_busy;
    reg         led_reg;
    reg  [23:0] cyc_cnt;                       // 24-bit: times up to 0.67s at 25 MHz

    wire        ext_wr  = ext_stb & ext_we  & ~ext_ack;   // 1-cycle write event
    wire        ext_rd  = ext_stb & ~ext_we & ~ext_ack;   // 1-cycle read event
    wire [2:0]  ext_reg = ext_adr[4:2];

    always @(posedge clk) begin
        tx_start <= 1'b0;
        cyc_cnt  <= cyc_cnt + 24'd1;
        if (cpu_rst) begin
            mem_ack     <= 1'b0;
            ext_ack     <= 1'b0;
            gpio_result <= 2'b00;              // clear stale result on (re)load
            rx_valid    <= 1'b0;
            tx_busy     <= 1'b0;
            led_reg     <= 1'b0;
            cyc_cnt     <= 24'd0;
        end else begin
            mem_ack <= mem_stb & ~mem_ack;    // BRAM read data valid the ack cycle
            ext_ack <= ext_stb & ~ext_ack;

            // result latch (0x4000_0000): bit1 = PASS (==1), bit0 = done
            if (ext_wr & (ext_reg == 3'd0))
                gpio_result <= {(ext_dat == 32'd1), 1'b1};

            // UART RX capture (rx_dv wins over a same-cycle read clear)
            if (rx_dv)                            rx_valid <= 1'b1;
            else if (ext_rd & (ext_reg == 3'd4))  rx_valid <= 1'b0;
            if (rx_dv)                            rx_data  <= rx_byte;

            // UART TX: launch a byte when the CPU writes uart-data and TX idle
            if (ext_wr & (ext_reg == 3'd4) & ~tx_busy) begin
                tx_data  <= ext_dat[7:0];
                tx_start <= 1'b1;
                tx_busy  <= 1'b1;
            end
            if (tx_done) tx_busy <= 1'b0;

            // LED register (0x4000_0018)
            if (ext_wr & (ext_reg == 3'd6)) led_reg <= ext_dat[0];
        end
    end

    always @(*) begin
        case (ext_reg)
            3'd4:    ext_rdt = {24'b0, rx_data};
            3'd5:    ext_rdt = {30'b0, tx_busy, rx_valid};
            3'd7:    ext_rdt = {8'b0, cyc_cnt};
            default: ext_rdt = 32'b0;
        endcase
    end

    assign result_bit0 = gpio_result[0];
    assign result_bit1 = gpio_result[1];
    assign o_led       = led_reg;

endmodule
