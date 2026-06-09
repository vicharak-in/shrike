// =============================================================================
// picorv32_imem_bram.v  --  runtime-loadable instruction RAM (BRAM4..7)
// Board   : Shrike / Shrike-Lite / Shrike-fi  (Renesas SLG47910 ForgeFPGA)
// License : GPL-2.0
//
// A writable 32-word x 32-bit instruction memory built from BRAM4..7 (the
// register file occupies BRAM0..3, see picorv32_regs_bram.v). It makes the core
// RUNTIME-PROGRAMMABLE: the host MCU streams a program into these slices over
// SPI while the CPU is held in reset, then releases the CPU to run it --
// no re-synthesis, no new bitstream.
//
// FOUR-SLICE LAYOUT (32 words, one byte lane per slice)
//       BRAM4 = insn[ 7: 0]   BRAM5 = insn[15: 8]
//       BRAM6 = insn[23:16]   BRAM7 = insn[31:24]
//
//   READ  (CPU fetch): all four slices are read at the word index mem_addr[6:2]
//         (entries 0..31). The SLG47910 BRAM read is SYNCHRONOUS, so `insn` is
//         valid one cycle after the address is presented; the top-level fetch
//         FSM inserts a 1-cycle wait-state before asserting mem_ready.
//   WRITE (SPI load): one byte at a time. The loader presents ld_word/ld_lane/
//         ld_byte and pulses ld_we; only the targeted lane's WEN fires, so the
//         32-bit word is filled across four single-byte writes.
//
//   The BRAM write and read ports are physically independent, and load vs run
//   are mutually exclusive in time (CPU is held in reset during load), so no
//   port arbitration is needed.
//
// RESOURCE BUDGET
//   4 BRAM slices @ 512x8 (RATIO=00). 32 words used out of 512; widening the
//   program means widening PC_W in picorv32.v (see README) -- the depth is here.
// =============================================================================

module picorv32_imem_bram (
    input  wire        clk,

    // CPU instruction-fetch read port (synchronous, 1-cycle latency)
    input  wire [31:0] mem_addr,    // word index = mem_addr[6:2]
    output wire [31:0] insn,        // registered BRAM read data

    // SPI loader write port (one byte lane per ld_we pulse)
    input  wire        ld_we,       // write strobe (1 cycle)
    input  wire [4:0]  ld_word,     // destination word index 0..31
    input  wire [1:0]  ld_lane,     // byte lane 0..3
    input  wire [7:0]  ld_byte,     // data byte

    // Instruction RAM = BRAM4..7, one byte lane each
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

    // --- Constants: 512x8 mode; clock-enables/read-enable active-low tied 0 ---
    assign {BRAM4_RATIO, BRAM5_RATIO, BRAM6_RATIO, BRAM7_RATIO} = {4{2'b00}};
    assign {BRAM4_WCLKEN, BRAM5_WCLKEN, BRAM6_WCLKEN, BRAM7_WCLKEN,
            BRAM4_RCLKEN, BRAM5_RCLKEN, BRAM6_RCLKEN, BRAM7_RCLKEN,
            BRAM4_REN,    BRAM5_REN,    BRAM6_REN,    BRAM7_REN} = {12{1'b0}};

    // --- Read port: word index from the fetch address (entries 0..31) ---
    wire [8:0] read_addr = {4'b0, mem_addr[6:2]};
    assign BRAM4_READ_ADDR = read_addr;
    assign BRAM5_READ_ADDR = read_addr;
    assign BRAM6_READ_ADDR = read_addr;
    assign BRAM7_READ_ADDR = read_addr;

    assign insn = {BRAM7_DATA_OUT, BRAM6_DATA_OUT, BRAM5_DATA_OUT, BRAM4_DATA_OUT};

    // --- Write port: loader presents one byte to the addressed word ---
    wire [8:0] write_addr = {4'b0, ld_word};
    assign BRAM4_WRITE_ADDR = write_addr;
    assign BRAM5_WRITE_ADDR = write_addr;
    assign BRAM6_WRITE_ADDR = write_addr;
    assign BRAM7_WRITE_ADDR = write_addr;

    // Same byte broadcast to all lanes; WEN picks the lane actually written.
    assign BRAM4_DATA_IN = ld_byte;
    assign BRAM5_DATA_IN = ld_byte;
    assign BRAM6_DATA_IN = ld_byte;
    assign BRAM7_DATA_IN = ld_byte;

    // WEN active-low: fire only the slice matching the current byte lane.
    assign BRAM4_WEN = ~(ld_we && (ld_lane == 2'd0));
    assign BRAM5_WEN = ~(ld_we && (ld_lane == 2'd1));
    assign BRAM6_WEN = ~(ld_we && (ld_lane == 2'd2));
    assign BRAM7_WEN = ~(ld_we && (ld_lane == 2'd3));

endmodule
