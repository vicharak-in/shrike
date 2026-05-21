// =============================================================================
// shrike_picorv32_top.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA + RP2040)
// Tool     : Go Configure Software Hub  (Yosys + Forge PnR)
// License  : GPL-2.0
//
// Top-level wrapper: picorv32 (small RV32I) + nuclear_rom + GPIO MMIO +
// BRAM regfile passthrough.
//
// ARCHITECTURE
//   picorv32 ---mem_bus---> nuclear_rom    (instr fetch, 1-cycle latency)
//   picorv32 ---mem_bus---> gpio_decode    (store to 0x40000000 -> latch)
//   picorv32 <--BRAMx_*---> 8x on-die BRAM (regfile via PICORV32_REGS macro)
//   gpio_latch -----------> GPIO17 / GPIO18 (2-bit result -> RP2040 GPIO15/14)
//
// PROGRAM (loaded from nuclear_rom.v)
//   addi x1, x0, 1       x1 = 1
//   addi x2, x0, 2       x2 = 2
//   add  x3, x1, x2      x3 = 3
//   lui  x4, 0x40000     x4 = 0x40000000 (GPIO base)
//   sw   x3, 0(x4)       drives GPIO17=1, GPIO18=1
//   jal  x0, 0           halt
//
// GPIO PIN MAP (from Shrike-lite pinout doc)
//   FPGA GPIO17 -> RP2040 GPIO15 = result bit 0
//   FPGA GPIO18 -> RP2040 GPIO14 = result bit 1
//   result = (bit1 << 1) | bit0 = 0b11 = 3
//
// IO PLANNER MAPPING
//   clk            -> OSC_CLK    (assign in IO Planner)
//   clk_en         -> OSC_EN     (assign in IO Planner)
//   result_bit*    -> leave UNASSIGNED (Yosys auto-routes to GPIO17/18)
//   BRAMx_*        -> leave UNASSIGNED (Yosys auto-routes to on-die BRAM)
// =============================================================================

(* top *) module shrike_picorv32_top (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *) output wire clk_en,

    // result bit 0 -> FPGA GPIO17 -> RP2040 GPIO15
    (* iopad_external_pin *) output wire result_bit0,
    (* iopad_external_pin *) output wire result_bit0_en,
    // result bit 1 -> FPGA GPIO18 -> RP2040 GPIO14
    (* iopad_external_pin *) output wire result_bit1,
    (* iopad_external_pin *) output wire result_bit1_en,

    // BRAM regfile ports (8 slices, dual-bank). Auto-routed by Yosys to
    // on-die BRAM resources; see picorv32_regs_bram.v for layout.
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

    assign clk_en         = 1'b1;
    assign result_bit0_en = 1'b1;
    assign result_bit1_en = 1'b1;

    // ---------------------------------------------------------------------
    // Power-on reset: hold CPU in reset for 16 cycles after bitstream load.
    // picorv32 uses active-low resetn.
    // ---------------------------------------------------------------------
    reg [3:0] rst_ctr = 4'hF;
    always @(posedge clk)
        if (rst_ctr != 4'h0) rst_ctr <= rst_ctr - 4'h1;
    wire resetn = (rst_ctr == 4'h0);

    // ---------------------------------------------------------------------
    // picorv32 native memory bus
    // ---------------------------------------------------------------------
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata;

    // ---------------------------------------------------------------------
    // picorv32 -- "small" config. Only params that differ from upstream
    // defaults are listed. The fork in src/ contains the SHRIKE PATCH
    // optimisations (carry-split adder, shared adder, BRAM regfile, etc.)
    // ---------------------------------------------------------------------
    picorv32 #(
        .ENABLE_COUNTERS      (0),
        .ENABLE_COUNTERS64    (0),
        .ENABLE_REGS_16_31    (0),
        .ENABLE_REGS_DUALPORT (0),
        .LATCHED_MEM_RDATA    (1),
        .TWO_STAGE_SHIFT      (0),
        .TWO_CYCLE_COMPARE    (0),  // SHRIKE PATCH (P11): try 1-cycle path; FFs at 51% util have room
        .TWO_CYCLE_ALU        (0),  // SHRIKE PATCH (P11): drop alu_*_q stage (eliminates 64 FFs + their pack overhead)
        .CATCH_MISALIGN       (0),
        .CATCH_ILLINSN        (0),
        // SHRIKE PATCH (P12): shrink regfile/decoded_rs widths.
        // With ENABLE_IRQ=0 the IRQ qregs/timer are already DCE'd, but their
        // params still feed regfile_size = 16 + 4*ENABLE_IRQ*ENABLE_IRQ_QREGS
        // and regindex_bits = 4 + ENABLE_IRQ*ENABLE_IRQ_QREGS. Forcing the
        // sub-params to 0 makes the arithmetic produce the same values via a
        // shorter constant-folding chain. Should be a no-op functionally but
        // may help GCH on size inference of decoded_rs / cpuregs.
        .ENABLE_IRQ           (0),
        .ENABLE_IRQ_QREGS     (0),
        .ENABLE_IRQ_TIMER     (0),
        .ENABLE_TRACE         (0),
        .ENABLE_PCPI          (0),
        .ENABLE_MUL           (0),
        .ENABLE_FAST_MUL      (0),
        .ENABLE_DIV           (0),
        .STACKADDR            (32'h0000_007C)
    ) cpu (
        .clk          (clk),
        .resetn       (resetn),
        .trap         (),

        .mem_valid    (mem_valid),
        .mem_instr    (mem_instr),
        .mem_ready    (mem_ready),
        .mem_addr     (mem_addr),
        .mem_wdata    (mem_wdata),
        .mem_wstrb    (mem_wstrb),
        .mem_rdata    (mem_rdata),

        // Look-ahead bus -- unused
        .mem_la_read  (),
        .mem_la_write (),
        .mem_la_addr  (),
        .mem_la_wdata (),
        .mem_la_wstrb (),

        // PCPI extension -- disabled, inputs tied low
        .pcpi_valid   (),
        .pcpi_insn    (),
        .pcpi_rs1     (),
        .pcpi_rs2     (),
        .pcpi_wr      (1'b0),
        .pcpi_rd      (32'd0),
        .pcpi_wait    (1'b0),
        .pcpi_ready   (1'b0),

        // IRQ -- disabled
        .irq          (32'd0),
        .eoi          (),

        // Trace -- disabled
        .trace_valid  (),
        .trace_data   (),

        // BRAM regfile ports (P4)
        .BRAM0_RATIO(BRAM0_RATIO), .BRAM0_DATA_IN(BRAM0_DATA_IN),
        .BRAM0_WEN(BRAM0_WEN), .BRAM0_WCLKEN(BRAM0_WCLKEN),
        .BRAM0_WRITE_ADDR(BRAM0_WRITE_ADDR), .BRAM0_DATA_OUT(BRAM0_DATA_OUT),
        .BRAM0_REN(BRAM0_REN), .BRAM0_RCLKEN(BRAM0_RCLKEN),
        .BRAM0_READ_ADDR(BRAM0_READ_ADDR),

        .BRAM1_RATIO(BRAM1_RATIO), .BRAM1_DATA_IN(BRAM1_DATA_IN),
        .BRAM1_WEN(BRAM1_WEN), .BRAM1_WCLKEN(BRAM1_WCLKEN),
        .BRAM1_WRITE_ADDR(BRAM1_WRITE_ADDR), .BRAM1_DATA_OUT(BRAM1_DATA_OUT),
        .BRAM1_REN(BRAM1_REN), .BRAM1_RCLKEN(BRAM1_RCLKEN),
        .BRAM1_READ_ADDR(BRAM1_READ_ADDR),

        .BRAM2_RATIO(BRAM2_RATIO), .BRAM2_DATA_IN(BRAM2_DATA_IN),
        .BRAM2_WEN(BRAM2_WEN), .BRAM2_WCLKEN(BRAM2_WCLKEN),
        .BRAM2_WRITE_ADDR(BRAM2_WRITE_ADDR), .BRAM2_DATA_OUT(BRAM2_DATA_OUT),
        .BRAM2_REN(BRAM2_REN), .BRAM2_RCLKEN(BRAM2_RCLKEN),
        .BRAM2_READ_ADDR(BRAM2_READ_ADDR),

        .BRAM3_RATIO(BRAM3_RATIO), .BRAM3_DATA_IN(BRAM3_DATA_IN),
        .BRAM3_WEN(BRAM3_WEN), .BRAM3_WCLKEN(BRAM3_WCLKEN),
        .BRAM3_WRITE_ADDR(BRAM3_WRITE_ADDR), .BRAM3_DATA_OUT(BRAM3_DATA_OUT),
        .BRAM3_REN(BRAM3_REN), .BRAM3_RCLKEN(BRAM3_RCLKEN),
        .BRAM3_READ_ADDR(BRAM3_READ_ADDR),

        .BRAM4_RATIO(BRAM4_RATIO), .BRAM4_DATA_IN(BRAM4_DATA_IN),
        .BRAM4_WEN(BRAM4_WEN), .BRAM4_WCLKEN(BRAM4_WCLKEN),
        .BRAM4_WRITE_ADDR(BRAM4_WRITE_ADDR), .BRAM4_DATA_OUT(BRAM4_DATA_OUT),
        .BRAM4_REN(BRAM4_REN), .BRAM4_RCLKEN(BRAM4_RCLKEN),
        .BRAM4_READ_ADDR(BRAM4_READ_ADDR),

        .BRAM5_RATIO(BRAM5_RATIO), .BRAM5_DATA_IN(BRAM5_DATA_IN),
        .BRAM5_WEN(BRAM5_WEN), .BRAM5_WCLKEN(BRAM5_WCLKEN),
        .BRAM5_WRITE_ADDR(BRAM5_WRITE_ADDR), .BRAM5_DATA_OUT(BRAM5_DATA_OUT),
        .BRAM5_REN(BRAM5_REN), .BRAM5_RCLKEN(BRAM5_RCLKEN),
        .BRAM5_READ_ADDR(BRAM5_READ_ADDR),

        .BRAM6_RATIO(BRAM6_RATIO), .BRAM6_DATA_IN(BRAM6_DATA_IN),
        .BRAM6_WEN(BRAM6_WEN), .BRAM6_WCLKEN(BRAM6_WCLKEN),
        .BRAM6_WRITE_ADDR(BRAM6_WRITE_ADDR), .BRAM6_DATA_OUT(BRAM6_DATA_OUT),
        .BRAM6_REN(BRAM6_REN), .BRAM6_RCLKEN(BRAM6_RCLKEN),
        .BRAM6_READ_ADDR(BRAM6_READ_ADDR),

        .BRAM7_RATIO(BRAM7_RATIO), .BRAM7_DATA_IN(BRAM7_DATA_IN),
        .BRAM7_WEN(BRAM7_WEN), .BRAM7_WCLKEN(BRAM7_WCLKEN),
        .BRAM7_WRITE_ADDR(BRAM7_WRITE_ADDR), .BRAM7_DATA_OUT(BRAM7_DATA_OUT),
        .BRAM7_REN(BRAM7_REN), .BRAM7_RCLKEN(BRAM7_RCLKEN),
        .BRAM7_READ_ADDR(BRAM7_READ_ADDR)
    );

    // ---------------------------------------------------------------------
    // Instruction ROM (combinational case() block; see nuclear_rom.v)
    // ---------------------------------------------------------------------
    wire [31:0] rom_data;
    nuclear_rom rom_inst (
        .mem_addr (mem_addr),
        .rom_data (rom_data)
    );

    // ---------------------------------------------------------------------
    // Memory bus decode
    //   * Reads (mem_wstrb == 0): return rom_data, ack next cycle.
    //   * Writes to 0x4xxx_xxxx: latch wdata[1:0] onto the GPIO result.
    //   * Everything else: ack with 0 (keeps CPU from stalling).
    //
    // LATCHED_MEM_RDATA=1: picorv32 reads mem_rdata in the cycle AFTER
    // mem_ready, so a single registered datapath suffices.
    // ---------------------------------------------------------------------
    reg [1:0] gpio_result = 2'b00;
    wire      gpio_hit    = mem_valid && mem_addr[30] && (mem_wstrb != 4'b0);

    always @(posedge clk) begin
        mem_ready <= 1'b0;
        if (!resetn) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;
        end else if (mem_valid && !mem_ready) begin
            if (gpio_hit) begin
                gpio_result <= mem_wdata[1:0];
                mem_rdata   <= 32'd0;
                mem_ready   <= 1'b1;
            end else begin
                mem_rdata   <= rom_data;
                mem_ready   <= 1'b1;
            end
        end
    end

    assign result_bit0 = gpio_result[0];   // FPGA GPIO17 -> RP2040 GPIO15
    assign result_bit1 = gpio_result[1];   // FPGA GPIO18 -> RP2040 GPIO14

endmodule
