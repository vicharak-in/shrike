// =============================================================================
// nuclear_rom.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA)
// License  : GPL-2.0
//
// Zero-wait-state combinational instruction ROM for picorv32.
//
// WHY case() INSTEAD OF $readmemh
//   Forge cannot initialise BRAM from a hex file; Yosys falls back to
//   RAMSRL primitives which consume ~800 LUTs for a small ROM and crash
//   the compiler. A combinational case() block maps to a small LUT mux
//   tree -- no BRAM, no RAMSRL, no crash.
//
// PROGRAM (RV32I, computes 1 + 2 = 3, latches result on GPIO MMIO):
//
//   word  byte_addr  hex         assembly
//   0     0x00       00100093    addi  x1, x0, 1
//   1     0x04       00200113    addi  x2, x0, 2
//   2     0x08       002081B3    add   x3, x1, x2
//   3     0x0C       40000237    lui   x4, 0x40000
//   4     0x10       00322023    sw    x3, 0(x4)
//   5     0x14       0000006F    jal   x0, 0  (halt)
// =============================================================================

module nuclear_rom (
    input  wire [31:0] mem_addr,
    output reg  [31:0] rom_data
);

    // mem_addr[5:2] gives word index 0..15 (aligned 32-bit fetches)
    always @(*) begin
        case (mem_addr[5:2])
            4'd0    : rom_data = 32'h00100093; // addi x1, x0, 1
            4'd1    : rom_data = 32'h00200113; // addi x2, x0, 2
            4'd2    : rom_data = 32'h002081B3; // add  x3, x1, x2
            4'd3    : rom_data = 32'h40000237; // lui  x4, 0x40000
            4'd4    : rom_data = 32'h00322023; // sw   x3, 0(x4)
            4'd5    : rom_data = 32'h0000006F; // jal  x0, 0
            default : rom_data = 32'h00000013; // nop
        endcase
    end

endmodule
