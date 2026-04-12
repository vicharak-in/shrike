// =============================================================================
// nuclear_rom.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA)
// License  : GPL-2.0
//
// Zero-wait-state combinational instruction ROM for SERV.
//
// WHY case() INSTEAD OF $readmemh
//   The Forge FPGA toolchain cannot initialise BRAM from a hex file.
//   Attempting to use $readmemh causes Yosys to fall back to RAMSRL primitives
//   (shift-register LUT RAM).  A 128-byte ROM implemented in RAMSRL consumes
//   800+ CLB LUTs and crashes the compiler with a resource overflow.
//
//   A case() block is pure combinational logic — Yosys maps it to a small
//   LUT mux tree.  No BRAM, no RAMSRL, no crash.
//   See docs/toolchain_failures.md for the full analysis.
//
// PROGRAM  (RV32I, no CSR, no interrupts)
//
//   word  address  hex         assembly
//   0     0x00     00100093    addi  x1, x0, 1
//   1     0x04     00200113    addi  x2, x0, 2
//   2     0x08     002081B3    add   x3, x1, x2    ; x3 = 3
//   3     0x0C     40000237    lui   x4, 0x40000   ; x4 = 0x40000000
//   4     0x10     00322023    sw    x3, 0(x4)     ; write result to GPIO
//   5     0x14     0000006F    jal   x0, 0         ; halt
//
// INTERFACE  (SERV ibus — Wishbone-compatible, read-only)
//   i_adr [31:0]  byte address from SERV program counter
//   i_cyc         bus cycle valid from SERV
//   o_dat [31:0]  instruction word returned (combinational, same cycle)
//   o_ack         acknowledge (tied to i_cyc — zero wait states)
// =============================================================================

module nuclear_rom (
    input  wire [31:0] i_adr,
    input  wire        i_cyc,
    output reg  [31:0] o_dat,
    output wire        o_ack
);

  // Acknowledge in the same cycle — SERV never stalls on instruction fetch.
  assign o_ack = i_cyc;

  // Word-addressed decode: i_adr[4:2] gives word index 0–5.
  // i_adr[1:0] is always 0 for aligned 32-bit fetches (SERV guarantee).
  always @(*) begin
    case (i_adr[4:2])
      3'd0 : o_dat = 32'h00100093;   // addi  x1, x0, 1
      3'd1 : o_dat = 32'h00200113;   // addi  x2, x0, 2
      3'd2 : o_dat = 32'h002081B3;   // add   x3, x1, x2
      3'd3 : o_dat = 32'h40000237;   // lui   x4, 0x40000
      3'd4 : o_dat = 32'h00322023;   // sw    x3, 0(x4)
      3'd5 : o_dat = 32'h0000006F;   // jal   x0, 0  (halt)
      default : o_dat = 32'h00000013; // nop  (addi x0, x0, 0)
    endcase
  end

endmodule
