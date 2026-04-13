// =============================================================================
// serv_shrike_top.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA  +  RP2040)
// Tool     : Go Configure Software Hub  (Yosys + Forge PNR)
// Author   : See repository contributors
// License  : GPL-2.0
//
// Top-level wrapper connecting SERV RISC-V CPU, Nuclear ROM, and GPIO output.
//
// ARCHITECTURE
//   serv_rf_top ──ibus──► nuclear_rom      (instruction fetch, zero wait)
//   serv_rf_top ──dbus──► gpio_decode      (store to 0x40000000 → GPIO latch)
//   gpio_decode ─────────► GPIO17 / GPIO18 (2-bit result → RP2040 GPIO15/14)
//
// PROGRAM EXECUTED BY SERV
//   addi x1, x0, 1        x1 = 1
//   addi x2, x0, 2        x2 = 2
//   add  x3, x1, x2       x3 = 3
//   lui  x4, 0x40000      x4 = 0x40000000  (GPIO base)
//   sw   x3, 0(x4)        drives GPIO17=1, GPIO18=1
//   jal  x0, 0            halt
//
// GPIO PIN MAP  (from official Shrike-lite pinout documentation)
//   FPGA GPIO17 → RP2040 GPIO15 = result bit 0
//   FPGA GPIO18 → RP2040 GPIO14 = result bit 1
//   result = (bit1 << 1) | bit0 = 0b11 = 3
//
// IO MAPPING FOR GO CONFIGURE IO PLANNER
//   clk            → OSC_CLK
//   clk_en         → OSC_EN
//   result_bit0    → GPIO17_OUT
//   result_bit0_en → GPIO17_OE
//   result_bit1    → GPIO18_OUT
//   result_bit1_en → GPIO18_OE
// =============================================================================

(* top *) module serv_shrike_top (
    // Internal 50 MHz oscillator clock
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,

    // Oscillator enable — must be driven high
    (* iopad_external_pin *) output wire clk_en,

    // result bit 0 → FPGA GPIO17 → RP2040 GPIO15
    (* iopad_external_pin *) output wire result_bit0,
    (* iopad_external_pin *) output wire result_bit0_en,

    // result bit 1 → FPGA GPIO18 → RP2040 GPIO14
    (* iopad_external_pin *) output wire result_bit1,
    (* iopad_external_pin *) output wire result_bit1_en
);

  assign clk_en         = 1'b1;
  assign result_bit0_en = 1'b1;
  assign result_bit1_en = 1'b1;

  // Power-on reset: hold SERV in reset for 16 cycles after bitstream load.
  // Ensures oscillator is stable before the CPU begins fetching instructions.
  reg [3:0] rst_ctr = 4'hF;
  always @(posedge clk) begin
    if (rst_ctr != 4'h0) rst_ctr <= rst_ctr - 4'h1;
  end
  wire rst = (rst_ctr != 4'h0);

  // Instruction bus (Wishbone-compatible, read-only)
  wire [31:0] ibus_adr;
  wire        ibus_cyc;
  wire [31:0] ibus_rdt;
  wire        ibus_ack;

  // Data bus (Wishbone-compatible, store-only in this design)
  wire [31:0] dbus_adr;
  wire [31:0] dbus_dat;
  wire [3:0]  dbus_sel;
  wire        dbus_we;
  wire        dbus_cyc;
  wire [31:0] dbus_rdt;
  wire        dbus_ack;

  // MDU interface tie-off (present in serv_rf_top even with WITH_CSR=0)
  wire        mdu_valid;

  // ---------------------------------------------------------------------------
  // SERV CPU — instantiating serv_rf_top which includes the register file.
  // serv_rf_top internally uses serv_rf_ram_shrike (NOT serv_rf_ram).
  // Update the serv_rf_top.v instantiation of serv_rf_ram to use
  // serv_rf_ram_shrike with DEPTH=16 before synthesising.
  // ---------------------------------------------------------------------------
  serv_rf_top #(
    .RESET_PC (32'h00000000),
    .WITH_CSR (0)
  ) cpu (
    .clk         (clk),
    .i_rst       (rst),
    .i_timer_irq (1'b0),

    .o_ibus_adr  (ibus_adr),
    .o_ibus_cyc  (ibus_cyc),
    .i_ibus_rdt  (ibus_rdt),
    .i_ibus_ack  (ibus_ack),

    .o_dbus_adr  (dbus_adr),
    .o_dbus_dat  (dbus_dat),
    .o_dbus_sel  (dbus_sel),
    .o_dbus_we   (dbus_we),
    .o_dbus_cyc  (dbus_cyc),
    .i_dbus_rdt  (dbus_rdt),
    .i_dbus_ack  (dbus_ack),

    .o_ext_funct3 (),
    .i_ext_ready  (1'b0),
    .i_ext_rd     (32'd0),
    .o_ext_rs1    (),
    .o_ext_rs2    (),
    .o_mdu_valid  (mdu_valid)
  );

  // ---------------------------------------------------------------------------
  // Nuclear ROM — combinational instruction memory.
  // Pure case() logic, no BRAM, no RAMSRL.
  // See docs/toolchain_failures.md for why $readmemh cannot be used here.
  // ---------------------------------------------------------------------------
  nuclear_rom rom (
    .i_adr (ibus_adr),
    .i_cyc (ibus_cyc),
    .o_dat (ibus_rdt),
    .o_ack (ibus_ack)
  );

  // ---------------------------------------------------------------------------
  // GPIO output register — memory-mapped at 0x40000000.
  // Triggered when SERV executes: sw x3, 0(x4) with x4=0x40000000, x3=3.
  // Latches dbus_dat[1:0] = 0b11 permanently onto the GPIO pins.
  // ---------------------------------------------------------------------------
  wire gpio_hit = dbus_cyc & dbus_we & (dbus_adr == 32'h40000000);

  reg [1:0] gpio_result = 2'b00;
  always @(posedge clk) begin
    if (gpio_hit) gpio_result <= dbus_dat[1:0];
  end

  assign result_bit0 = gpio_result[0];   // FPGA GPIO17 → RP2040 GPIO15
  assign result_bit1 = gpio_result[1];   // FPGA GPIO18 → RP2040 GPIO14

  // Data bus always-ack: no reads in this design, rdt tied to zero.
  assign dbus_rdt = 32'h00000000;
  assign dbus_ack = dbus_cyc;

endmodule
