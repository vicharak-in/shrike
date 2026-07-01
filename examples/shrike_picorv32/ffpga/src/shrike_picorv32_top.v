// =============================================================================
// shrike_picorv32_top.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA + RP2040)
// Tool     : Go Configure Software Hub  (Yosys + Forge PnR)
//
// picorv32 (full 32 regs, 4-slice BRAM regfile, read-latency fix) as a
// RUNTIME-PROGRAMMABLE core. The host MCU streams a program into the BRAM
// instruction RAM over SPI while the CPU is held in reset, then releases it to
// run -- no re-synthesis, no new bitstream. Result is read back on GPIO17/18.
//
// BRAM SPLIT: BRAM0..3 = register file (picorv32_regs_bram, 5-bit addr),
//             BRAM4..7 = instruction RAM (picorv32_imem_bram, SPI-loaded).
//
// SPI LOAD PROTOCOL (Mode 0, MSB-first, 8-bit; reuse spi_target.v):
//   0xA0          enter load: halt CPU, reset write pointer
//   <128 bytes>   program image, little-endian words (32 words x 4 bytes)
//   0xA2          run: release the CPU
//   0xA3          halt: hold the CPU in reset (re-arm before a new 0xA0)
//
// IO PLANNER: assign clk->OSC_CLK, clk_en->OSC_EN, and spi_sck/spi_ss_n/
//   spi_mosi to the GPIOs wired to the MCU SPI (same pins as the stack_processor
//   example). Leave result_bit0/1 (+_en) and all BRAMx_* unassigned -- Yosys
//   auto-routes the result bits to GPIO17/18 and the BRAM ports to on-die BRAM.
// =============================================================================

(* top *) module shrike_picorv32_top (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *) output wire clk_en,

    // SPI program-load interface (MCU is the controller)
    (* iopad_external_pin *) input  wire spi_sck,
    (* iopad_external_pin *) input  wire spi_ss_n,
    (* iopad_external_pin *) input  wire spi_mosi,

    // CPU result readback (auto-routed to GPIO17/18 -> RP2040 GPIO15/14)
    (* iopad_external_pin *) output wire result_bit0,
    (* iopad_external_pin *) output wire result_bit0_en,
    (* iopad_external_pin *) output wire result_bit1,
    (* iopad_external_pin *) output wire result_bit1_en,

    // Register file (BRAM0..3) + instruction RAM (BRAM4..7), auto-routed
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

    // --- Power-on reset: holds SPI + loader until the fabric settles ---
    reg [3:0] rst_ctr = 4'hF;
    always @(posedge clk)
        if (rst_ctr != 4'h0) rst_ctr <= rst_ctr - 4'h1;
    wire por_resetn = (rst_ctr == 4'h0);

    // -------------------------------------------------------------------------
    // SPI target (program-load ingress). MISO unused -- result comes back on
    // the GPIO result pins, so the FPGA never drives the SPI bus.
    // -------------------------------------------------------------------------
    wire [7:0] spi_rx_data;
    wire       spi_rx_valid;

    spi_target #(.CPOL(1'b0), .CPHA(1'b0), .WIDTH(8), .LSB(1'b0)) u_spi (
        .i_clk(clk), .i_rst_n(por_resetn), .i_enable(1'b1),
        .i_ss_n(spi_ss_n), .i_sck(spi_sck), .i_mosi(spi_mosi),
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
    // Bootloader FSM: command dispatch + program streaming into the imem.
    // -------------------------------------------------------------------------
    localparam integer PROG_BYTES = 128;          // 32 words x 4 bytes (PC_W=7)
    localparam [7:0] CMD_LOAD = 8'hA0,             // halt + reset write pointer
                     CMD_RUN  = 8'hA2,             // release CPU
                     CMD_HALT = 8'hA3;             // hold CPU in reset

    reg        cpu_run;       // 1 = CPU released to run the loaded program
    reg        ld_active;     // 1 = streaming program bytes into imem
    reg [6:0]  ld_cnt;        // byte index 0..127
    reg        ld_we;         // 1-cycle imem write strobe
    reg [4:0]  ld_word;       // imem word index 0..31
    reg [1:0]  ld_lane;       // byte lane 0..3
    reg [7:0]  ld_byte;       // byte to write

    always @(posedge clk) begin
        ld_we <= 1'b0;
        if (!por_resetn) begin
            cpu_run   <= 1'b0;
            ld_active <= 1'b0;
            ld_cnt    <= 7'd0;
        end else if (spi_rx_pulse) begin
            if (ld_active) begin
                // streaming: write one byte lane of the current word
                ld_we   <= 1'b1;
                ld_word <= ld_cnt[6:2];
                ld_lane <= ld_cnt[1:0];
                ld_byte <= spi_rx_data;
                ld_cnt  <= ld_cnt + 7'd1;
                if (ld_cnt == PROG_BYTES-1)
                    ld_active <= 1'b0;             // image complete -> back to IDLE
            end else begin
                case (spi_rx_data)
                    CMD_LOAD: begin cpu_run <= 1'b0; ld_active <= 1'b1; ld_cnt <= 7'd0; end
                    CMD_RUN:  cpu_run <= 1'b1;
                    CMD_HALT: cpu_run <= 1'b0;
                    default:  ; // ignore unknown bytes
                endcase
            end
        end
    end

    // CPU runs only after power-on AND an explicit 0xA2 from the host.
    wire cpu_resetn = por_resetn & cpu_run;

    // -------------------------------------------------------------------------
    // picorv32 core (register file in BRAM0..3)
    // -------------------------------------------------------------------------
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata;

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
        .STACKADDR            (32'h0000_007C)
    ) cpu (
        .clk(clk), .resetn(cpu_resetn), .trap(),
        .mem_valid(mem_valid), .mem_instr(mem_instr),
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

    // -------------------------------------------------------------------------
    // Instruction RAM (BRAM4..7) -- read by the CPU, written by the loader
    // -------------------------------------------------------------------------
    wire [31:0] insn;
    picorv32_imem_bram imem (
        .clk(clk),
        .mem_addr(mem_addr), .insn(insn),
        .ld_we(ld_we), .ld_word(ld_word), .ld_lane(ld_lane), .ld_byte(ld_byte),
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
    // Memory bus: instruction fetch (1-cycle BRAM read wait-state) + GPIO latch
    // -------------------------------------------------------------------------
    reg [1:0] gpio_result;
    reg       fetch_pend;       // 1 = imem address presented, data valid next cycle
    wire      gpio_hit = mem_valid && mem_addr[30] && (mem_wstrb != 4'b0);

    always @(posedge clk) begin
        mem_ready <= 1'b0;
        if (!cpu_resetn) begin
            mem_ready   <= 1'b0;
            mem_rdata   <= 32'd0;
            fetch_pend  <= 1'b0;
            gpio_result <= 2'b00;          // clear stale result on (re)load
        end else if (mem_valid && !mem_ready) begin
            if (gpio_hit) begin
                gpio_result <= mem_wdata[1:0];
                mem_ready   <= 1'b1;
                fetch_pend  <= 1'b0;
            end else if (!fetch_pend) begin
                fetch_pend  <= 1'b1;       // wait one cycle for the synchronous BRAM read
            end else begin
                mem_rdata   <= insn;       // imem DATA_OUT now valid
                mem_ready   <= 1'b1;
                fetch_pend  <= 1'b0;
            end
        end else begin
            fetch_pend <= 1'b0;
        end
    end

    assign result_bit0 = gpio_result[0];
    assign result_bit1 = gpio_result[1];

endmodule
