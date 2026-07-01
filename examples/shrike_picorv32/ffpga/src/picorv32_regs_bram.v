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
// the regfile as four 512x8 BRAM slices.
//
// FOUR-SLICE LAYOUT (32 registers, 5-bit-addressed)
//   All 32 registers live in BRAM0..3 -- one byte lane per slice, addressed by
//   the 5-bit register index [4:0] (entries 0..31 of the 512-deep slice):
//       BRAM0 = bits [ 7: 0]   BRAM1 = bits [15: 8]
//       BRAM2 = bits [23:16]   BRAM3 = bits [31:24]
//   READ : all four slices are read at raddr1[4:0]; {BRAM3..0}_DATA_OUT is the
//          32-bit word. With ENABLE_REGS_DUALPORT=0 picorv32 sequences the rs1
//          and rs2 reads onto raddr1 across cycles, so one read port suffices.
//   WRITE: all four slices are written at waddr[4:0] with one wen.
//
//   WHY 4 SLICES: a 32x32 register file needs only 4 byte-lane slices when
//   driven by a full 5-bit address (entries 0..31). This leaves BRAM4..7 for the
//   SPI-loaded instruction RAM (picorv32_imem_bram.v), so the core stays
//   runtime-programmable while still fitting the fabric.
//
// X0 HANDLING
//   RISC-V x0 must read as zero. Reads where raddr[4:0]==0 are forced to 32'd0
//   at the output. Writes to x0 are prevented upstream by picorv32 (wen is
//   gated by `latched_rd` being non-zero).
//
// RESOURCE BUDGET
//   4 BRAM slices @ 512x8 each (RATIO=00). 32 register entries used out of the
//   512 per slice; 32-bit width comes from 4 slices in parallel.
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

    // Register file = BRAM0..3, one byte lane each, 5-bit addressed (x0..x31)
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
    output wire [8:0] BRAM3_READ_ADDR
);

    // --- Constants: 512x8 mode; clock-enables/read-enable active-low tied 0 ---
    assign {BRAM0_RATIO, BRAM1_RATIO, BRAM2_RATIO, BRAM3_RATIO} = {4{2'b00}};
    assign {BRAM0_WCLKEN, BRAM1_WCLKEN, BRAM2_WCLKEN, BRAM3_WCLKEN,
            BRAM0_RCLKEN, BRAM1_RCLKEN, BRAM2_RCLKEN, BRAM3_RCLKEN,
            BRAM0_REN,    BRAM1_REN,    BRAM2_REN,    BRAM3_REN} = {12{1'b0}};

    // --- 5-bit register index drives all four slices (entries 0..31) ---
    wire [8:0] raddr_5b = {4'b0, raddr1[4:0]};
    wire [8:0] waddr_5b = {4'b0, waddr[4:0]};

    assign BRAM0_READ_ADDR = raddr_5b;
    assign BRAM1_READ_ADDR = raddr_5b;
    assign BRAM2_READ_ADDR = raddr_5b;
    assign BRAM3_READ_ADDR = raddr_5b;

    assign BRAM0_WRITE_ADDR = waddr_5b;
    assign BRAM1_WRITE_ADDR = waddr_5b;
    assign BRAM2_WRITE_ADDR = waddr_5b;
    assign BRAM3_WRITE_ADDR = waddr_5b;

    // --- Write data: one byte lane per slice ---
    assign BRAM0_DATA_IN = wdata[ 7: 0];
    assign BRAM1_DATA_IN = wdata[15: 8];
    assign BRAM2_DATA_IN = wdata[23:16];
    assign BRAM3_DATA_IN = wdata[31:24];

    // --- Write enable (active-low), all four slices written together ---
    assign {BRAM0_WEN, BRAM1_WEN, BRAM2_WEN, BRAM3_WEN} = {4{~wen}};

    // --- Read data: assemble the 32-bit word from the four byte lanes ---
    wire [31:0] rd = {BRAM3_DATA_OUT, BRAM2_DATA_OUT, BRAM1_DATA_OUT, BRAM0_DATA_OUT};

    // x0 hardwired to zero per RISC-V spec.
    assign rdata1 = (raddr1[4:0] == 5'd0) ? 32'd0 : rd;
    // rdata2 is unused with ENABLE_REGS_DUALPORT=0 (picorv32 takes rs2 from the
    // sequenced rs1 read). Driven here only for interface completeness.
    assign rdata2 = (raddr2[4:0] == 5'd0) ? 32'd0 : rd;

endmodule
