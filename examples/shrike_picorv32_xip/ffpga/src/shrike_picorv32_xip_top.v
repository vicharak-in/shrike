// =============================================================================
// shrike_picorv32_xip_top.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA + RP2040)
// Tool     : Go Configure Software Hub  (Yosys + Forge PnR)
//
// XIP top: picorv32 (full RV32I, 32 regs, 4-slice BRAM register
// file, PC_W=16) executing IN PLACE from a 64 KB external SPI RAM emulated by
// the RP2040 (MichaelBell/spi-ram-emu). The FPGA is the SPI MASTER. There is
// no instruction BRAM, no loader, and ZERO address decode: the XIP master is
// the only bus device and uses mem_addr[15:0] raw — any high address bits
// alias into the 64 KB space.
//
// IO contract lives in FIRMWARE (no hardware support needed):
//   console = store the byte to ext-RAM word 0xF000
//   status  = store 123456789 to ext-RAM word 0xF004 on PASS
// The RP2040 owns the RAM and hooks completed SPI write frames that start at
// those words; code+data sit below 0xF000, stack descends from 0x10000.
//
// PINS (Shrike-Lite, FPGA side):
//   GPIO3 = spi_sck  out   GPIO4 = spi_mosi out   GPIO5 = spi_cs_n out
//   GPIO6 = spi_miso in    GPIO18 = run in (RP2040 GPIO14)
//   GPIO17 = dbg out (RP2040 GPIO15): CPU trap flag
//
// BOOT/CONTENTION: the same 4 wires carry the FPGA configuration stream before
// user logic starts, and the RP2040 drives them until it flips to RAM-emu
// mode. While `run` is low the SPI pads are kept Hi-Z (output enables gated
// by run) and the CPU+master are held in reset; the RP2040 raises run only
// after the emulator is live. Aliveness at bring-up = SCK/CS activity the
// moment run rises (the master fetching IS the heartbeat); dbg goes high when
// the CPU traps (ebreak).
// =============================================================================

(* top *)
module shrike_picorv32_xip_top (
    (* iopad_external_pin, clkbuf_inhibit *) input  clk,   // PLL_CLK, 25 MHz
    (* iopad_external_pin *) output clk_en,                // OSC enable (PLL reference)

    // PLL: 50 MHz overclocks this design (Fmax 46); run the fabric at 25 MHz
    (* iopad_external_pin *) output        pll_en,
    (* iopad_external_pin *) output        pll_bypass,
    (* iopad_external_pin *) output        pll_clk_selection,
    (* iopad_external_pin *) output [5:0]  pll_refdiv,
    (* iopad_external_pin *) output [11:0] pll_fbdiv,
    (* iopad_external_pin *) output [2:0]  pll_postdiv1,
    (* iopad_external_pin *) output [2:0]  pll_postdiv2,

    (* iopad_external_pin *) output spi_sck,
    (* iopad_external_pin *) output spi_sck_en,
    (* iopad_external_pin *) output spi_mosi,
    (* iopad_external_pin *) output spi_mosi_en,
    (* iopad_external_pin *) output spi_cs_n,
    (* iopad_external_pin *) output spi_cs_n_en,
    (* iopad_external_pin *) input  spi_miso,

    (* iopad_external_pin *) input  run,
    (* iopad_external_pin *) output dbg,
    (* iopad_external_pin *) output dbg_en,

    // Register file BRAM0..3 (wired through the core, see picorv32_regs_bram.v)
    (* iopad_external_pin *) output [1:0] BRAM0_RATIO,
    (* iopad_external_pin *) output [7:0] BRAM0_DATA_IN,
    (* iopad_external_pin *) output       BRAM0_WEN,
    (* iopad_external_pin *) output       BRAM0_WCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM0_WRITE_ADDR,
    (* iopad_external_pin *) input  [7:0] BRAM0_DATA_OUT,
    (* iopad_external_pin *) output       BRAM0_REN,
    (* iopad_external_pin *) output       BRAM0_RCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM0_READ_ADDR,

    (* iopad_external_pin *) output [1:0] BRAM1_RATIO,
    (* iopad_external_pin *) output [7:0] BRAM1_DATA_IN,
    (* iopad_external_pin *) output       BRAM1_WEN,
    (* iopad_external_pin *) output       BRAM1_WCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM1_WRITE_ADDR,
    (* iopad_external_pin *) input  [7:0] BRAM1_DATA_OUT,
    (* iopad_external_pin *) output       BRAM1_REN,
    (* iopad_external_pin *) output       BRAM1_RCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM1_READ_ADDR,

    (* iopad_external_pin *) output [1:0] BRAM2_RATIO,
    (* iopad_external_pin *) output [7:0] BRAM2_DATA_IN,
    (* iopad_external_pin *) output       BRAM2_WEN,
    (* iopad_external_pin *) output       BRAM2_WCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM2_WRITE_ADDR,
    (* iopad_external_pin *) input  [7:0] BRAM2_DATA_OUT,
    (* iopad_external_pin *) output       BRAM2_REN,
    (* iopad_external_pin *) output       BRAM2_RCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM2_READ_ADDR,

    (* iopad_external_pin *) output [1:0] BRAM3_RATIO,
    (* iopad_external_pin *) output [7:0] BRAM3_DATA_IN,
    (* iopad_external_pin *) output       BRAM3_WEN,
    (* iopad_external_pin *) output       BRAM3_WCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM3_WRITE_ADDR,
    (* iopad_external_pin *) input  [7:0] BRAM3_DATA_OUT,
    (* iopad_external_pin *) output       BRAM3_REN,
    (* iopad_external_pin *) output       BRAM3_RCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM3_READ_ADDR
);
    assign clk_en = 1'b1;

    // Fout = 50 * FBDIV / (REFDIV * POSTDIV1 * POSTDIV2) = 50*21/(1*7*6) = 25 MHz
    assign pll_en            = 1'b1;
    assign pll_bypass        = 1'b0;
    assign pll_clk_selection = 1'b0;   // reference = internal OSC
    assign pll_refdiv        = 6'd1;
    assign pll_fbdiv         = 12'd21;
    assign pll_postdiv1      = 3'd7;
    assign pll_postdiv2      = 3'd6;

    // ---- power-on reset + run gating ----
    reg [1:0] rst_ctr = 2'h3;
    always @(posedge clk)
        if (rst_ctr != 0) rst_ctr <= rst_ctr - 1'b1;
    wire por_resetn = (rst_ctr == 0);
    wire sys_resetn = por_resetn & run;

    // SPI pads stay Hi-Z until the RP2040 says go (config-wire contention guard)
    assign spi_sck_en  = run;
    assign spi_mosi_en = run;
    assign spi_cs_n_en = run;

    // ---- debug pin: CPU trap flag ----
    wire trap;
    assign dbg    = trap;
    assign dbg_en = 1'b1;

    // ---- picorv32 core (register file in BRAM0..3) ----
    wire        mem_valid;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 1:0] mem_wstrb;
    wire [31:0] mem_rdata;

    picorv32 #(
        .ENABLE_COUNTERS      (0),
        .ENABLE_COUNTERS64    (0),
        .ENABLE_REGS_16_31    (1),
        .ENABLE_REGS_DUALPORT (0),
        .LATCHED_MEM_RDATA    (1),
        .TWO_STAGE_SHIFT      (0),
        .TWO_CYCLE_COMPARE    (0),
        .TWO_CYCLE_ALU        (0),
        .CATCH_MISALIGN       (0),
        .CATCH_ILLINSN        (0),
        .ENABLE_IRQ           (0),
        .ENABLE_IRQ_QREGS     (0),
        .ENABLE_IRQ_TIMER     (0),
        .ENABLE_TRACE         (0),
        .ENABLE_PCPI          (0),
        .ENABLE_MUL           (0),
        .ENABLE_FAST_MUL      (0),
        .ENABLE_DIV           (0),
        .STACKADDR            (32'h0001_0000)
    ) cpu (
        .clk(clk), .resetn(sys_resetn), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(),
        .mem_ready(mem_ready), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .mem_la_read(), .mem_la_write(), .mem_la_addr(),
        .mem_la_wdata(), .mem_la_wstrb(),
        .pcpi_valid(), .pcpi_insn(), .pcpi_rs1(), .pcpi_rs2(),
        .pcpi_wr(1'b0), .pcpi_rd(32'd0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
        .irq(32'd0), .eoi(), .trace_valid(), .trace_data(),
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
        .BRAM3_REN(BRAM3_REN), .BRAM3_RCLKEN(BRAM3_RCLKEN), .BRAM3_READ_ADDR(BRAM3_READ_ADDR)
    );

    // ---- the XIP master IS the bus: no decode, mem_addr[15:0] raw ----
    spi_xip_master xip (
        .clk(clk), .resetn(sys_resetn),
        .mem_valid(mem_valid), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb), .mem_rdata(mem_rdata),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_mosi(spi_mosi), .spi_miso(spi_miso)
    );

endmodule
