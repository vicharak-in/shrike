// =============================================================================
// picorv32_regs_bram.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA)
// License  : GPL-2.0
//
// BRAM-backed PICORV32_REGS implementation. Replaces the 16x32 register file
// (stored as 512 FFs in upstream picorv32) with the SLG47910's on-die BRAM,
// freeing FFs and eliminating the 16:1 read mux for cpuregs.
//
// DUAL-BANK DESIGN
//   The SLG47910 BRAM is synchronous with 1-cycle read latency, while
//   picorv32's PICORV32_REGS interface expects combinational reads (set
//   raddr -> get rdata same cycle). A single BRAM port cannot satisfy this.
//
//   Two banks of 4 BRAM slices each (32-bit wide via byte-lane parallelism):
//     Bank A (BRAM0..3): continuously reads at raddr1 (= decoded_rs1)
//     Bank B (BRAM4..7): continuously reads at raddr2 (= decoded_rs2)
//
//   Picorv32 patch P6 ensures cpuregs_raddr2 is always decoded_rs2 (not
//   gated by ENABLE_REGS_DUALPORT), so Bank B always holds rs2's value.
//
//   With DUALPORT=0, picorv32 routes both rs1 (cpu_state_ld_rs1) and rs2
//   (cpu_state_ld_rs2) reads through cpuregs_rdata1. When in ld_rs2 the
//   raddr1 input is muxed to decoded_rs2 (== raddr2), so an equality test
//   on raddr1==raddr2 cleanly selects Bank B's value:
//
//     raddr1 == raddr2 -> ld_rs2 case -> return Bank B value
//     raddr1 != raddr2 -> ld_rs1 case -> return Bank A value
//
//   When decoded_rs1==decoded_rs2 by coincidence, both banks hold the same
//   value so either selection is correct.
//
// X0 HANDLING
//   RISC-V x0 must read as zero. Reads where raddr==0 are forced to 32'd0
//   at the output. Writes to x0 are prevented upstream by picorv32 (wen is
//   gated by `latched_rd` being non-zero).
//
// RESOURCE BUDGET
//   8 BRAM slices @ 512x8 each (RATIO=00). 16 register entries used out of
//   512 per slice. 32-bit width from 4 slices in parallel per bank.
// =============================================================================

module picorv32_regs_bram (
    input  wire        clk,
    input  wire        wen,
    input  wire [5:0]  waddr,
    input  wire [5:0]  raddr1,
    input  wire [5:0]  raddr2,
    input  wire [31:0] wdata,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,

    // Bank A - reads raddr1 continuously
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
    output wire [8:0] BRAM3_READ_ADDR,

    // Bank B - reads raddr2 continuously
    output wire [1:0] BRAM4_RATIO,
    output wire [7:0] BRAM4_DATA_IN,
    output wire       BRAM4_WEN,
    output wire       BRAM4_WCLKEN,
    output wire [8:0] BRAM4_WRITE_ADDR,
    input  wire [7:0] BRAM4_DATA_OUT,
    output wire       BRAM4_REN,
    output wire       BRAM4_RCLKEN,
    output wire [8:0] BRAM4_READ_ADDR,

    output wire [1:0] BRAM5_RATIO,
    output wire [7:0] BRAM5_DATA_IN,
    output wire       BRAM5_WEN,
    output wire       BRAM5_WCLKEN,
    output wire [8:0] BRAM5_WRITE_ADDR,
    input  wire [7:0] BRAM5_DATA_OUT,
    output wire       BRAM5_REN,
    output wire       BRAM5_RCLKEN,
    output wire [8:0] BRAM5_READ_ADDR,

    output wire [1:0] BRAM6_RATIO,
    output wire [7:0] BRAM6_DATA_IN,
    output wire       BRAM6_WEN,
    output wire       BRAM6_WCLKEN,
    output wire [8:0] BRAM6_WRITE_ADDR,
    input  wire [7:0] BRAM6_DATA_OUT,
    output wire       BRAM6_REN,
    output wire       BRAM6_RCLKEN,
    output wire [8:0] BRAM6_READ_ADDR,

    output wire [1:0] BRAM7_RATIO,
    output wire [7:0] BRAM7_DATA_IN,
    output wire       BRAM7_WEN,
    output wire       BRAM7_WCLKEN,
    output wire [8:0] BRAM7_WRITE_ADDR,
    input  wire [7:0] BRAM7_DATA_OUT,
    output wire       BRAM7_REN,
    output wire       BRAM7_RCLKEN,
    output wire [8:0] BRAM7_READ_ADDR
);

    // --- Constants: 512x8 mode, clock-enables active-low tied 0 ---
    assign {BRAM0_RATIO, BRAM1_RATIO, BRAM2_RATIO, BRAM3_RATIO,
            BRAM4_RATIO, BRAM5_RATIO, BRAM6_RATIO, BRAM7_RATIO} = {8{2'b00}};

    assign {BRAM0_WCLKEN, BRAM1_WCLKEN, BRAM2_WCLKEN, BRAM3_WCLKEN,
            BRAM4_WCLKEN, BRAM5_WCLKEN, BRAM6_WCLKEN, BRAM7_WCLKEN,
            BRAM0_RCLKEN, BRAM1_RCLKEN, BRAM2_RCLKEN, BRAM3_RCLKEN,
            BRAM4_RCLKEN, BRAM5_RCLKEN, BRAM6_RCLKEN, BRAM7_RCLKEN,
            BRAM0_REN,    BRAM1_REN,    BRAM2_REN,    BRAM3_REN,
            BRAM4_REN,    BRAM5_REN,    BRAM6_REN,    BRAM7_REN} = {24{1'b0}};

    // --- Read addresses (9 bits; we only use low 4 for 16 entries) ---
    wire [8:0] raddr1_v = {5'b0, raddr1[3:0]};
    wire [8:0] raddr2_v = {5'b0, raddr2[3:0]};
    wire [8:0] waddr_v  = {5'b0, waddr[3:0]};

    assign BRAM0_READ_ADDR = raddr1_v;
    assign BRAM1_READ_ADDR = raddr1_v;
    assign BRAM2_READ_ADDR = raddr1_v;
    assign BRAM3_READ_ADDR = raddr1_v;
    assign BRAM4_READ_ADDR = raddr2_v;
    assign BRAM5_READ_ADDR = raddr2_v;
    assign BRAM6_READ_ADDR = raddr2_v;
    assign BRAM7_READ_ADDR = raddr2_v;

    // --- Writes: same waddr/wdata to BOTH banks to keep them coherent ---
    assign BRAM0_WRITE_ADDR = waddr_v;
    assign BRAM1_WRITE_ADDR = waddr_v;
    assign BRAM2_WRITE_ADDR = waddr_v;
    assign BRAM3_WRITE_ADDR = waddr_v;
    assign BRAM4_WRITE_ADDR = waddr_v;
    assign BRAM5_WRITE_ADDR = waddr_v;
    assign BRAM6_WRITE_ADDR = waddr_v;
    assign BRAM7_WRITE_ADDR = waddr_v;

    // Byte-lane split of 32-bit wdata
    assign BRAM0_DATA_IN = wdata[ 7: 0];
    assign BRAM1_DATA_IN = wdata[15: 8];
    assign BRAM2_DATA_IN = wdata[23:16];
    assign BRAM3_DATA_IN = wdata[31:24];
    assign BRAM4_DATA_IN = wdata[ 7: 0];
    assign BRAM5_DATA_IN = wdata[15: 8];
    assign BRAM6_DATA_IN = wdata[23:16];
    assign BRAM7_DATA_IN = wdata[31:24];

    // Write enables (active-low)
    assign {BRAM0_WEN, BRAM1_WEN, BRAM2_WEN, BRAM3_WEN,
            BRAM4_WEN, BRAM5_WEN, BRAM6_WEN, BRAM7_WEN} = {8{~wen}};

    // --- Read data: combine 8-bit slices into 32-bit per bank ---
    wire [31:0] bank_a = {BRAM3_DATA_OUT, BRAM2_DATA_OUT, BRAM1_DATA_OUT, BRAM0_DATA_OUT};
    wire [31:0] bank_b = {BRAM7_DATA_OUT, BRAM6_DATA_OUT, BRAM5_DATA_OUT, BRAM4_DATA_OUT};

    // Dual-bank select: raddr1==raddr2 means ld_rs2 case (use Bank B)
    wire same = (raddr1[3:0] == raddr2[3:0]);
    wire [31:0] mux_out = same ? bank_b : bank_a;

    // x0 hardwired to zero per RISC-V spec
    assign rdata1 = (raddr1[3:0] == 4'd0) ? 32'd0 : mux_out;
    assign rdata2 = (raddr2[3:0] == 4'd0) ? 32'd0 : bank_b;

endmodule
