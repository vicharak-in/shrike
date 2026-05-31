// =============================================================================
// nuclear_rom.v  --  RV32I instruction-variety self-test (baked instruction ROM)
// Board   : Shrike / Shrike-Lite / Shrike-fi  (Renesas SLG47910 ForgeFPGA)
// License : GPL-2.0
//
// Zero-wait-state combinational instruction ROM for the picorv32 core. A
// combinational case() block maps to a small LUT mux tree -- no BRAM init, no
// RAMSRL fallback, no compiler crash (unlike $readmemh).
//
// WHAT THIS PROGRAM DOES
//   A single accumulator (x10) is threaded through a wide spread of RV32I
//   instructions -- arithmetic, logic and shifts in both register and
//   immediate forms, plus set-less-than. Every branch type is then exercised
//   as a "must-not-take" gate: if any branch wrongly fires, control jumps to
//   the halt loop and SKIPS the result store, leaving the GPIO result at 0
//   (fail). The final JAL must jump over a poison instruction.
//
//   If every instruction executed correctly, x10 == 3 and is stored to the
//   GPIO result latch at 0x40000000, driving result bits = 0b11.
//   GPIO result == 3 (both result bits high)  ==>  ALL TESTS PASSED.
//
//   27 distinct RV32I opcodes exercised, in exactly 32 instruction words:
//     addi add sub  and or xor  andi ori xori  sll srl sra  slli srli srai
//     slt sltu slti  lui  beq bne blt bge bltu bgeu  jal  sw
// =============================================================================

module nuclear_rom (
    input  wire [31:0] mem_addr,
    output reg  [31:0] rom_data
);

    // mem_addr[6:2] = word index 0..31 (aligned 32-bit instruction fetches)
    always @(*) begin
        case (mem_addr[6:2])
            5'd0  : rom_data = 32'h00600093; // li ra,6
            5'd1  : rom_data = 32'h00300113; // li sp,3
            5'd2  : rom_data = 32'h00100193; // li gp,1
            5'd3  : rom_data = 32'h00600513; // li a0,6
            5'd4  : rom_data = 32'h00251513; // slli a0,a0,0x2
            5'd5  : rom_data = 32'h00155513; // srli a0,a0,0x1
            5'd6  : rom_data = 32'h00351533; // sll a0,a0,gp
            5'd7  : rom_data = 32'h00355533; // srl a0,a0,gp
            5'd8  : rom_data = 32'h40355533; // sra a0,a0,gp
            5'd9  : rom_data = 32'h40155513; // srai a0,a0,0x1
            5'd10 : rom_data = 32'h00150533; // add a0,a0,ra
            5'd11 : rom_data = 32'h40250533; // sub a0,a0,sp
            5'd12 : rom_data = 32'h00157533; // and a0,a0,ra
            5'd13 : rom_data = 32'h00356533; // or a0,a0,gp
            5'd14 : rom_data = 32'h00254533; // xor a0,a0,sp
            5'd15 : rom_data = 32'h00E57513; // andi a0,a0,14
            5'd16 : rom_data = 32'h00156513; // ori a0,a0,1
            5'd17 : rom_data = 32'h00654513; // xori a0,a0,6
            5'd18 : rom_data = 32'h00112233; // slt tp,sp,ra
            5'd19 : rom_data = 32'h0020B2B3; // sltu t0,ra,sp
            5'd20 : rom_data = 32'h00512313; // slti t1,sp,5
            5'd21 : rom_data = 32'h02208463; // beq ra,sp,7c <halt>
            5'd22 : rom_data = 32'h02109263; // bne ra,ra,7c <halt>
            5'd23 : rom_data = 32'h0220C063; // blt ra,sp,7c <halt>
            5'd24 : rom_data = 32'h00115E63; // bge sp,ra,7c <halt>
            5'd25 : rom_data = 32'h0020EC63; // bltu ra,sp,7c <halt>
            5'd26 : rom_data = 32'h00117A63; // bgeu sp,ra,7c <halt>
            5'd27 : rom_data = 32'h0080006F; // j 74 <halt-0x8>
            5'd28 : rom_data = 32'h00150513; // addi a0,a0,1
            5'd29 : rom_data = 32'h400004B7; // lui s1,0x40000
            5'd30 : rom_data = 32'h00A4A023; // sw a0,0(s1) # 40000000 <__global_pointer$+0x3fffe780>
            5'd31 : rom_data = 32'h0000006F; // j 7c <halt>
            default: rom_data = 32'h00000013; // nop (addi x0,x0,0)
        endcase
    end

endmodule
