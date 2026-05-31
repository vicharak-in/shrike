// =============================================================================
// picorv32_regs_bram.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA)
// License  : GPL-2.0
//
// BRAM-backed PICORV32_REGS implementation. Replaces the full 32x32 register
// file (stored as ~1024 FFs in upstream picorv32) with the SLG47910's on-die
// BRAM, freeing the FFs and eliminating the 32:1 read mux for cpuregs. This is
// what lets a full RV32I core (all 32 registers) fit the fabric.
//
// The SLG47910 BRAM read is SYNCHRONOUS (1-cycle registered read), but
// picorv32's PICORV32_REGS interface expects a combinational read (set raddr
// -> get rdata the same cycle). The core's read-latency wait-state
// (RS_READ_LATENCY=2 in picorv32.v, correctness fix CF1) bridges that gap by
// stalling until the registered read data is valid; this module just exposes
// the regfile as eight 512x8 BRAM slices.
//
// LOW/HIGH SPLIT (32 registers, 4-bit-addressed)
//   The 32 registers are split across two sets of 4 slices each, every slice
//   contributing one byte lane of the 32-bit word:
//     Low  set (BRAM0..3): x0 .. x15   (selected when addr bit [4] == 0)
//     High set (BRAM4..7): x16 .. x31  (selected when addr bit [4] == 1)
//
//   READ : both sets are addressed by raddr1[3:0] every cycle; the output mux
//          picks the low or high set on raddr1[4]. picorv32 sequences the rs1
//          and rs2 reads on raddr1 across cycles (DUALPORT=0), so a single
//          read address feeds both. raddr2 is exposed for completeness and
//          drives rdata2 with the same low/high mux on raddr2[4].
//   WRITE : waddr[3:0] addresses both sets; waddr[4] gates which set's WEN
//          fires, so only the targeted half is written.
//
//   All BRAM addresses are 4 bits [3:0] -- the design never relies on the
//   synthesiser routing address bit [4] into the BRAM; bit [4] only steers
//   the fabric write-enable gating and the read output mux.
//
// X0 HANDLING
//   RISC-V x0 must read as zero. Reads where raddr[4:0]==0 are forced to 32'd0
//   at the output. Writes to x0 are prevented upstream by picorv32 (wen is
//   gated by `latched_rd` being non-zero).
//
// RESOURCE BUDGET
//   8 BRAM slices @ 512x8 each (RATIO=00). 32 register entries used out of the
//   512 per slice; 32-bit width comes from 4 slices in parallel per set.
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

    // Low set (x0..x15) - byte lanes 0..3, addressed by raddr1[3:0]
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

    // High set (x16..x31) - byte lanes 0..3, addressed by raddr1[3:0]
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

    // --- 32-register split: BRAM0-3 = x0-x15 (low), BRAM4-7 = x16-x31 (high).
    // All BRAM addresses are 4-bit [3:0] — avoids relying on the synthesiser routing bit[4].
    // raddr[4] selects which physical bank set to read; fabric mux selects output.
    // In DUALPORT=0, both rs1 and rs2 reads come through raddr1 (different cycles);
    // raddr2 only selects the rdata2 output mux below.
    wire [8:0] raddr1_4b = {5'b0, raddr1[3:0]};  // 4-bit address, low half
    wire [8:0] waddr_4b  = {5'b0, waddr[3:0]};

    // Both sets read at raddr1[3:0]; output mux selects based on raddr1[4]
    assign BRAM0_READ_ADDR = raddr1_4b;  // x0-x15 reads
    assign BRAM1_READ_ADDR = raddr1_4b;
    assign BRAM2_READ_ADDR = raddr1_4b;
    assign BRAM3_READ_ADDR = raddr1_4b;
    assign BRAM4_READ_ADDR = raddr1_4b;  // x16-x31 reads (same slot, different WEN)
    assign BRAM5_READ_ADDR = raddr1_4b;
    assign BRAM6_READ_ADDR = raddr1_4b;
    assign BRAM7_READ_ADDR = raddr1_4b;

    // Write: only the correct half gets written based on waddr[4]
    assign BRAM0_WRITE_ADDR = waddr_4b;
    assign BRAM1_WRITE_ADDR = waddr_4b;
    assign BRAM2_WRITE_ADDR = waddr_4b;
    assign BRAM3_WRITE_ADDR = waddr_4b;
    assign BRAM4_WRITE_ADDR = waddr_4b;
    assign BRAM5_WRITE_ADDR = waddr_4b;
    assign BRAM6_WRITE_ADDR = waddr_4b;
    assign BRAM7_WRITE_ADDR = waddr_4b;

    // Write data (same for both halves; WEN gates which half is written)
    assign BRAM0_DATA_IN = wdata[ 7: 0];
    assign BRAM1_DATA_IN = wdata[15: 8];
    assign BRAM2_DATA_IN = wdata[23:16];
    assign BRAM3_DATA_IN = wdata[31:24];
    assign BRAM4_DATA_IN = wdata[ 7: 0];
    assign BRAM5_DATA_IN = wdata[15: 8];
    assign BRAM6_DATA_IN = wdata[23:16];
    assign BRAM7_DATA_IN = wdata[31:24];

    // Write enables: BRAM0-3 for x0-x15 (waddr[4]=0), BRAM4-7 for x16-x31 (waddr[4]=1)
    wire wen_lo = wen && !waddr[4];  // write to low half
    wire wen_hi = wen &&  waddr[4];  // write to high half
    assign {BRAM0_WEN, BRAM1_WEN, BRAM2_WEN, BRAM3_WEN} = {4{~wen_lo}};
    assign {BRAM4_WEN, BRAM5_WEN, BRAM6_WEN, BRAM7_WEN} = {4{~wen_hi}};

    // Read data from each physical half
    wire [31:0] bank_lo = {BRAM3_DATA_OUT, BRAM2_DATA_OUT, BRAM1_DATA_OUT, BRAM0_DATA_OUT};
    wire [31:0] bank_hi = {BRAM7_DATA_OUT, BRAM6_DATA_OUT, BRAM5_DATA_OUT, BRAM4_DATA_OUT};

    // Select the rs1 read output: raddr1[4] picks which physical half holds the result
    wire [31:0] mux_out = raddr1[4] ? bank_hi : bank_lo;

    // x0 hardwired to zero per RISC-V spec; use raddr1[4:0]==0 check
    assign rdata1 = (raddr1[4:0] == 5'd0) ? 32'd0 : mux_out;
    assign rdata2 = (raddr2[4:0] == 5'd0) ? 32'd0 : (raddr2[4] ? bank_hi : bank_lo);

endmodule
