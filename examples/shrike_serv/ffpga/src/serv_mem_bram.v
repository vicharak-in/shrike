// =============================================================================
// serv_mem_bram.v  --  unified 4 KB program+data memory from all 8 BRAM slices
// Board   : Shrike / Shrike-Lite / Shrike-fi  (Renesas SLG47910 ForgeFPGA)
//
// SERV keeps its register file in distributed RAM (serv_rf_ram), so ALL eight
// BRAM slices are free for a single unified memory. This gives 1024 words x
// 32-bit = 4 KB holding program, data, signature and stack together -- enough
// to run any single rv32ui test (largest ~3.9 KB), loaded at runtime over SPI.
//
// TWO-BANK LAYOUT (1024 words, one byte lane per slice, bank = word_idx[9])
//       bank 0 (words   0..511): BRAM0=[7:0] BRAM1=[15:8] BRAM2=[23:16] BRAM3=[31:24]
//       bank 1 (words 512..1023): BRAM4=[7:0] BRAM5=[15:8] BRAM6=[23:16] BRAM7=[31:24]
//
//   READ  (CPU): the byte address selects word_idx = i_addr[11:2]. The low 9
//         bits address the slice (0..511); word_idx[9] selects the bank. BRAM
//         reads are SYNCHRONOUS (data valid one cycle after the address), so the
//         bank select is registered to line up with the returned data, and the
//         top-level wb_mem handshake asserts ack one cycle after stb.
//   WRITE (CPU store OR SPI loader): one byte lane at a time. A CPU store fires
//         the lanes named by i_sel with i_wdata split across the four slices of
//         the addressed bank; the loader broadcasts one byte and fires the one
//         slice picked by ld_word[9]/ld_lane. CPU-run and SPI-load are mutually
//         exclusive in time (the core is held in reset during load), so the
//         single write port needs no arbitration.
// =============================================================================
`default_nettype none

module serv_mem_bram (
    input  wire        clk,

    // CPU memory port (word access via the wb_mem bus)
    input  wire [31:0] i_addr,       // byte address; word_idx = i_addr[11:2]
    input  wire [31:0] i_wdata,
    input  wire [3:0]  i_sel,        // byte lane enables (store)
    input  wire        i_we,         // 1 = store, 0 = load
    input  wire        i_stb,        // access strobe (address valid)
    output wire [31:0] o_rdata,      // registered read data (1-cycle latency)

    // SPI loader write port (one byte lane per ld_we pulse)
    input  wire        ld_we,        // write strobe (1 cycle)
    input  wire [9:0]  ld_word,      // destination word index 0..1023
    input  wire [1:0]  ld_lane,      // byte lane 0..3
    input  wire [7:0]  ld_byte,      // data byte

    // Eight 512x8 BRAM slices (bank 0 = 0..3, bank 1 = 4..7)
    output wire [1:0] BRAM0_RATIO, output wire [7:0] BRAM0_DATA_IN,
    output wire       BRAM0_WEN,    output wire       BRAM0_WCLKEN,
    output wire [8:0] BRAM0_WRITE_ADDR, input wire [7:0] BRAM0_DATA_OUT,
    output wire       BRAM0_REN,    output wire       BRAM0_RCLKEN,
    output wire [8:0] BRAM0_READ_ADDR,
    output wire [1:0] BRAM1_RATIO, output wire [7:0] BRAM1_DATA_IN,
    output wire       BRAM1_WEN,    output wire       BRAM1_WCLKEN,
    output wire [8:0] BRAM1_WRITE_ADDR, input wire [7:0] BRAM1_DATA_OUT,
    output wire       BRAM1_REN,    output wire       BRAM1_RCLKEN,
    output wire [8:0] BRAM1_READ_ADDR,
    output wire [1:0] BRAM2_RATIO, output wire [7:0] BRAM2_DATA_IN,
    output wire       BRAM2_WEN,    output wire       BRAM2_WCLKEN,
    output wire [8:0] BRAM2_WRITE_ADDR, input wire [7:0] BRAM2_DATA_OUT,
    output wire       BRAM2_REN,    output wire       BRAM2_RCLKEN,
    output wire [8:0] BRAM2_READ_ADDR,
    output wire [1:0] BRAM3_RATIO, output wire [7:0] BRAM3_DATA_IN,
    output wire       BRAM3_WEN,    output wire       BRAM3_WCLKEN,
    output wire [8:0] BRAM3_WRITE_ADDR, input wire [7:0] BRAM3_DATA_OUT,
    output wire       BRAM3_REN,    output wire       BRAM3_RCLKEN,
    output wire [8:0] BRAM3_READ_ADDR,
    output wire [1:0] BRAM4_RATIO, output wire [7:0] BRAM4_DATA_IN,
    output wire       BRAM4_WEN,    output wire       BRAM4_WCLKEN,
    output wire [8:0] BRAM4_WRITE_ADDR, input wire [7:0] BRAM4_DATA_OUT,
    output wire       BRAM4_REN,    output wire       BRAM4_RCLKEN,
    output wire [8:0] BRAM4_READ_ADDR,
    output wire [1:0] BRAM5_RATIO, output wire [7:0] BRAM5_DATA_IN,
    output wire       BRAM5_WEN,    output wire       BRAM5_WCLKEN,
    output wire [8:0] BRAM5_WRITE_ADDR, input wire [7:0] BRAM5_DATA_OUT,
    output wire       BRAM5_REN,    output wire       BRAM5_RCLKEN,
    output wire [8:0] BRAM5_READ_ADDR,
    output wire [1:0] BRAM6_RATIO, output wire [7:0] BRAM6_DATA_IN,
    output wire       BRAM6_WEN,    output wire       BRAM6_WCLKEN,
    output wire [8:0] BRAM6_WRITE_ADDR, input wire [7:0] BRAM6_DATA_OUT,
    output wire       BRAM6_REN,    output wire       BRAM6_RCLKEN,
    output wire [8:0] BRAM6_READ_ADDR,
    output wire [1:0] BRAM7_RATIO, output wire [7:0] BRAM7_DATA_IN,
    output wire       BRAM7_WEN,    output wire       BRAM7_WCLKEN,
    output wire [8:0] BRAM7_WRITE_ADDR, input wire [7:0] BRAM7_DATA_OUT,
    output wire       BRAM7_REN,    output wire       BRAM7_RCLKEN,
    output wire [8:0] BRAM7_READ_ADDR
);

    // --- Constants: 512x8 mode; clock-/read-enables active-low tied 0 ---
    assign {BRAM0_RATIO,BRAM1_RATIO,BRAM2_RATIO,BRAM3_RATIO,
            BRAM4_RATIO,BRAM5_RATIO,BRAM6_RATIO,BRAM7_RATIO} = {8{2'b00}};
    assign {BRAM0_WCLKEN,BRAM1_WCLKEN,BRAM2_WCLKEN,BRAM3_WCLKEN,
            BRAM4_WCLKEN,BRAM5_WCLKEN,BRAM6_WCLKEN,BRAM7_WCLKEN,
            BRAM0_RCLKEN,BRAM1_RCLKEN,BRAM2_RCLKEN,BRAM3_RCLKEN,
            BRAM4_RCLKEN,BRAM5_RCLKEN,BRAM6_RCLKEN,BRAM7_RCLKEN,
            BRAM0_REN,BRAM1_REN,BRAM2_REN,BRAM3_REN,
            BRAM4_REN,BRAM5_REN,BRAM6_REN,BRAM7_REN} = {24{1'b0}};

    // --- Read port: same 9-bit slice address to all slices; bank picks 4-of-8 ---
    wire [8:0] read_addr = i_addr[10:2];
    assign {BRAM0_READ_ADDR,BRAM1_READ_ADDR,BRAM2_READ_ADDR,BRAM3_READ_ADDR,
            BRAM4_READ_ADDR,BRAM5_READ_ADDR,BRAM6_READ_ADDR,BRAM7_READ_ADDR}
           = {8{read_addr}};

    reg bank_r;                               // registered to match read latency
    always @(posedge clk) bank_r <= i_addr[11];
    assign o_rdata = bank_r
        ? {BRAM7_DATA_OUT,BRAM6_DATA_OUT,BRAM5_DATA_OUT,BRAM4_DATA_OUT}
        : {BRAM3_DATA_OUT,BRAM2_DATA_OUT,BRAM1_DATA_OUT,BRAM0_DATA_OUT};

    // --- Write port: loader byte (broadcast) or CPU store (lane-split) ---
    wire [8:0] write_addr = ld_we ? ld_word[8:0] : i_addr[10:2];
    assign {BRAM0_WRITE_ADDR,BRAM1_WRITE_ADDR,BRAM2_WRITE_ADDR,BRAM3_WRITE_ADDR,
            BRAM4_WRITE_ADDR,BRAM5_WRITE_ADDR,BRAM6_WRITE_ADDR,BRAM7_WRITE_ADDR}
           = {8{write_addr}};

    assign BRAM0_DATA_IN = ld_we ? ld_byte : i_wdata[ 7: 0];
    assign BRAM1_DATA_IN = ld_we ? ld_byte : i_wdata[15: 8];
    assign BRAM2_DATA_IN = ld_we ? ld_byte : i_wdata[23:16];
    assign BRAM3_DATA_IN = ld_we ? ld_byte : i_wdata[31:24];
    assign BRAM4_DATA_IN = ld_we ? ld_byte : i_wdata[ 7: 0];
    assign BRAM5_DATA_IN = ld_we ? ld_byte : i_wdata[15: 8];
    assign BRAM6_DATA_IN = ld_we ? ld_byte : i_wdata[23:16];
    assign BRAM7_DATA_IN = ld_we ? ld_byte : i_wdata[31:24];

    // WEN active-low: fire the one slice a loader byte targets, or the CPU-store
    // lanes of the addressed bank. bank = word_idx[9] = i_addr[11]/ld_word[9].
    wire cpu_wr = i_stb & i_we;
    assign BRAM0_WEN = ~((ld_we & ~ld_word[9] & (ld_lane==2'd0)) | (cpu_wr & ~i_addr[11] & i_sel[0]));
    assign BRAM1_WEN = ~((ld_we & ~ld_word[9] & (ld_lane==2'd1)) | (cpu_wr & ~i_addr[11] & i_sel[1]));
    assign BRAM2_WEN = ~((ld_we & ~ld_word[9] & (ld_lane==2'd2)) | (cpu_wr & ~i_addr[11] & i_sel[2]));
    assign BRAM3_WEN = ~((ld_we & ~ld_word[9] & (ld_lane==2'd3)) | (cpu_wr & ~i_addr[11] & i_sel[3]));
    assign BRAM4_WEN = ~((ld_we &  ld_word[9] & (ld_lane==2'd0)) | (cpu_wr &  i_addr[11] & i_sel[0]));
    assign BRAM5_WEN = ~((ld_we &  ld_word[9] & (ld_lane==2'd1)) | (cpu_wr &  i_addr[11] & i_sel[1]));
    assign BRAM6_WEN = ~((ld_we &  ld_word[9] & (ld_lane==2'd2)) | (cpu_wr &  i_addr[11] & i_sel[2]));
    assign BRAM7_WEN = ~((ld_we &  ld_word[9] & (ld_lane==2'd3)) | (cpu_wr &  i_addr[11] & i_sel[3]));

endmodule
`default_nettype wire
