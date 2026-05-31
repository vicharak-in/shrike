// =============================================================================
// shrike_picorv32_top.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA + RP2040)
// Tool     : Go Configure Software Hub  (Yosys + Forge PnR)
//
// picorv32 (full 32 regs, BRAM regfile, read-latency fix) + 32-word self-test ROM.
// GPIO17/18 readback. PC_W=7 (128-byte limit) -> fits the test program exactly.
// IO PLANNER: assign only clk->OSC_CLK, clk_en->OSC_EN. BRAM+result auto.
// =============================================================================

(* top *) module shrike_picorv32_top (
    (* iopad_external_pin, clkbuf_inhibit *) input  wire clk,
    (* iopad_external_pin *) output wire clk_en,

    (* iopad_external_pin *) output wire result_bit0,
    (* iopad_external_pin *) output wire result_bit0_en,
    (* iopad_external_pin *) output wire result_bit1,
    (* iopad_external_pin *) output wire result_bit1_en,

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

    reg [3:0] rst_ctr = 4'hF;
    always @(posedge clk)
        if (rst_ctr != 4'h0) rst_ctr <= rst_ctr - 4'h1;
    wire resetn = (rst_ctr == 4'h0);

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
        .clk(clk), .resetn(resetn), .trap(),
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

    wire [31:0] rom_data;
    nuclear_rom rom_inst (.mem_addr(mem_addr), .rom_data(rom_data));

    reg [1:0] gpio_result = 2'b00;
    wire      gpio_hit    = mem_valid && mem_addr[30] && (mem_wstrb != 4'b0);

    always @(posedge clk) begin
        mem_ready <= 1'b0;
        if (!resetn) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;
        end else if (mem_valid && !mem_ready) begin
            if (gpio_hit)
                gpio_result <= mem_wdata[1:0];
            else
                mem_rdata   <= rom_data;
            mem_ready <= 1'b1;
        end
    end

    assign result_bit0 = gpio_result[0];
    assign result_bit1 = gpio_result[1];

endmodule
