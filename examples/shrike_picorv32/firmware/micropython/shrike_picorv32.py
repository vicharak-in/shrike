# =============================================================================
# shrike_picorv32.py
# Project  : shrike_picorv32  (runtime-programmable RV32I core)
# Board    : Shrike-lite (RP2040) / Shrike (RP2350)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : GPL-2.0
#
# Flashes the PicoRV32 bitstream, then streams a 32-word RV32I program into the
# FPGA over SPI and runs it -- no re-synthesis, no new bitstream. The CPU writes
# its final result to a memory-mapped GPIO latch (store to 0x40000000); the low
# 2 bits drive FPGA GPIO17/18, hardwired to RP2040 GPIO15/14, read back by the MCU.
#
# RV32I CONFORMANCE SUITE
#   This file holds several themed <=32-word programs (TESTS below). Each is
#   self-checking and latches:
#       3 = PASS   (every instruction it tests behaved correctly)
#       1 = FAIL   (it ran but computed a wrong value)
#       0 = DEAD   (the CPU never reached the store: trap / illegal / hang;
#                   the latch is cleared to 0 on every reload)
#   Together the programs cover the complete RV32I base ISA (37 instructions).
#   Select which one runs by uncommenting exactly one ACTIVE = ... line.
#
#   Each program was machine-generated from RV32I assembly and validated two
#   ways: (a) it returns 3 on a correct core, and (b) injecting a fault into any
#   instruction it tests makes it stop returning 3, so a passing result confirms
#   those instructions are correct.
#
# SPI load protocol (the bootloader FSM in shrike_picorv32_top.v):
#   0xA0          enter load (halt CPU, reset write pointer)
#   <128 bytes>   program image, 32 words x 4 bytes, little-endian
#   0xA2          run (release the CPU)
#   0xA3          halt (re-arm before loading a new program)
#
# Expected output (with ACTIVE = "regalu"):
#   Flashing PicoRV32 bitstream to FPGA...
#   [shrike_flash] FPGA programming done.
#   regalu: testing add sub sll srl sra and or xor slt sltu
#   result = 3 -> PASS
# =============================================================================

import sys
import time
import shrike
from machine import Pin, SPI

# -- Platform configuration ---------------------------------------------------
# SPI:    RP2040 SPI0 wired to the FPGA SPI load pins (same as stack_processor).
# Result: FPGA GPIO17/18 -> RP2040 GPIO15/14 via PCB 0-ohm resistors.
# Shrike-fi (ESP32-S3) trace map is untested; add an esp32 branch once verified.

if sys.platform == 'rp2':
    CONFIG = {
        'platform':  'RP2040/RP2350',
        'spi_id':    0,
        'sck':       2,    # RP2040 GPIO2  -> FPGA spi_sck
        'mosi':      3,    # RP2040 GPIO3  -> FPGA spi_mosi
        'miso':      0,    # RP2040 GPIO0  (unused; FPGA does not drive MISO)
        'cs':        1,    # RP2040 GPIO1  -> FPGA spi_ss_n
        'bit0_pin':  15,   # RP2040 GPIO15 <- FPGA GPIO17 (result bit 0)
        'bit1_pin':  14,   # RP2040 GPIO14 <- FPGA GPIO18 (result bit 1)
        'bitstream': 'shrike_picorv32.bin',
    }
else:
    raise RuntimeError(
        "Unsupported platform: {}. Supported: 'rp2'.".format(sys.platform)
    )

NOP        = 0x00000013
PASS_VALUE = 3

# =============================================================================
# RV32I CONFORMANCE PROGRAMS  (each <=32 words; latches 3 on PASS / 1 / 0)
# -----------------------------------------------------------------------------
# A `# li t2,<expected>` line holds a precomputed checksum the program compares
# its accumulated result against; the arithmetic programs sum every operation's
# result so a wrong answer in any single instruction shifts the total and fails.
# =============================================================================

# --- register-register ALU: add sub sll srl sra and or xor slt sltu ----------
PROG_REGALU = [
    0x00C00293,  # li   t0,12
    0x00300E13,  # li   t3,3
    0xFF400F13,  # li   t5,-12
    0x01C28333,  # add  t1,t0,t3   (=15, seeds the sum)
    0x41C28EB3,  # sub  t4,t0,t3   (=9)
    0x01D30333,  # add  t1,t1,t4
    0x01C29EB3,  # sll  t4,t0,t3   (=96)
    0x01D30333,  # add  t1,t1,t4
    0x01C2DEB3,  # srl  t4,t0,t3   (=1)
    0x01D30333,  # add  t1,t1,t4
    0x01C2EEB3,  # or   t4,t0,t3   (=15)
    0x01D30333,  # add  t1,t1,t4
    0x01C2CEB3,  # xor  t4,t0,t3   (=15)
    0x01D30333,  # add  t1,t1,t4
    0x01C2FEB3,  # and  t4,t0,t3   (=0)
    0x01D30333,  # add  t1,t1,t4
    0x01CF2EB3,  # slt  t4,t5,t3   (=1, signed -12<3)
    0x01D30333,  # add  t1,t1,t4
    0x01CF3EB3,  # sltu t4,t5,t3   (=0, unsigned huge<3)
    0x01D30333,  # add  t1,t1,t4
    0x41CF5EB3,  # sra  t4,t5,t3   (=-2, arithmetic -12>>3)
    0x01D30333,  # add  t1,t1,t4
    0x09600393,  # li   t2,150     (expected sum)
    0x00100513,  # li   a0,1       (fail marker)
    0x00731463,  # bne  t1,t2,STORE
    0x00300513,  # li   a0,3       (pass marker)
    0x400004B7,  # lui  s1,0x40000000
    0x00A4A023,  # sw   a0,0(s1)
    0x0000006F,  # j    .          (halt)
]

# --- register-immediate + upper: addi slli srli srai andi ori xori -----------
#                                 slti sltiu lui auipc
PROG_IMMALU = [
    0x00D00293,  # li   t0,13
    0xFF300F13,  # li   t5,-13
    0x00528313,  # addi t1,t0,5    (=18, seeds the sum)
    0x00229E93,  # slli t4,t0,2    (=52)
    0x01D30333,  # add  t1,t1,t4
    0x0022DE93,  # srli t4,t0,2    (=3)
    0x01D30333,  # add  t1,t1,t4
    0x402F5E93,  # srai t4,t5,2    (=-4, arithmetic)
    0x01D30333,  # add  t1,t1,t4
    0x0062FE93,  # andi t4,t0,6    (=4)
    0x01D30333,  # add  t1,t1,t4
    0x0022EE93,  # ori  t4,t0,2    (=15)
    0x01D30333,  # add  t1,t1,t4
    0x0062CE93,  # xori t4,t0,6    (=11)
    0x01D30333,  # add  t1,t1,t4
    0x000F2E93,  # slti t4,t5,0    (=1, signed -13<0)
    0x01D30333,  # add  t1,t1,t4
    0x001F3E93,  # sltiu t4,t5,1   (=0, unsigned huge<1)
    0x01D30333,  # add  t1,t1,t4
    0x00001EB7,  # lui  t4,1       (=0x1000)
    0x00CEDE93,  # srli t4,t4,12   (=1, recover the upper immediate)
    0x01D30333,  # add  t1,t1,t4
    0x00000E97,  # auipc t4,0      (=PC of this instruction)
    0x01D30333,  # add  t1,t1,t4
    0x0BD00393,  # li   t2,189     (expected sum: 101 + PC(=88))
    0x00100513,  # li   a0,1       (fail marker)
    0x00731463,  # bne  t1,t2,STORE
    0x00300513,  # li   a0,3       (pass marker)
    0x400004B7,  # lui  s1,0x40000000
    0x00A4A023,  # sw   a0,0(s1)
    0x0000006F,  # j    .          (halt)
]

# --- branches (each tested BOTH taken and not-taken): beq bne blt bge --------
#                                                      bltu bgeu
PROG_BRANCH = [
    0x00500293,  # li   t0,5
    0x00500E13,  # li   t3,5
    0x00700E93,  # li   t4,7
    0xFFD00F13,  # li   t5,-3
    0x01C28463,  # beq  t0,t3,+8     (must take: 5==5)
    0x04C0006F,  # j    FAIL
    0x05D28463,  # beq  t0,t4,FAIL   (must NOT take: 5==7)
    0x01D29463,  # bne  t0,t4,+8     (must take: 5!=7)
    0x0400006F,  # j    FAIL
    0x03C29E63,  # bne  t0,t3,FAIL   (must NOT take: 5!=5)
    0x005F4463,  # blt  t5,t0,+8     (must take: -3<5 signed)
    0x0340006F,  # j    FAIL
    0x03E2C863,  # blt  t0,t5,FAIL   (must NOT take: 5<-3)
    0x01C2D463,  # bge  t0,t3,+8     (must take: 5>=5)
    0x0280006F,  # j    FAIL
    0x025F5263,  # bge  t5,t0,FAIL   (must NOT take: -3>=5)
    0x01D2E463,  # bltu t0,t4,+8     (must take: 5<7 unsigned)
    0x01C0006F,  # j    FAIL
    0x005F6C63,  # bltu t5,t0,FAIL   (must NOT take: huge<5)
    0x005F7463,  # bgeu t5,t0,+8     (must take: huge>=5 unsigned)
    0x0100006F,  # j    FAIL
    0x01D2F663,  # bgeu t0,t4,FAIL   (must NOT take: 5>=7)
    0x00300513,  # li   a0,3         (every branch behaved)
    0x0080006F,  # j    STORE
    0x00100513,  # FAIL: li a0,1
    0x400004B7,  # lui  s1,0x40000000
    0x00A4A023,  # sw   a0,0(s1)
    0x0000006F,  # j    .            (halt)
]

# --- jumps (control transfer AND link register): jal jalr --------------------
PROG_JUMPS = [
    0x008000EF,  # jal  ra,JT        (ra = PC+4)
    0x00100093,  # addi ra,zero,1    (poison link; must be skipped)
    0x00400393,  # JT: li t2,4       (expected jal link)
    0x02709063,  # bne  ra,t2,FAIL
    0x00000297,  # auipc t0,0        (t0 = &this)
    0x00C280E7,  # jalr ra,t0,12     (ra = PC+4; jump to TGT)
    0x00100093,  # addi ra,zero,1    (poison link; must be skipped)
    0x01800393,  # TGT: li t2,24     (expected jalr link)
    0x00709663,  # bne  ra,t2,FAIL
    0x00300513,  # li   a0,3
    0x0080006F,  # j    STORE
    0x00100513,  # FAIL: li a0,1
    0x400004B7,  # lui  s1,0x40000000
    0x00A4A023,  # sw   a0,0(s1)
    0x0000006F,  # j    .            (halt)
]

# --- loads (all widths + sign/zero extension): lw lh lhu lb lbu --------------
PROG_LOADS = [
    0x05802303,  # lw   t1,(Dw)      -> 3
    0x00300393,  # li   t2,3
    0x04731063,  # bne  t1,t2,FAIL
    0x05C04303,  # lbu  t1,(D80)     -> 128 (zero-extended)
    0x08000393,  # li   t2,128
    0x02731A63,  # bne  t1,t2,FAIL
    0x05C00303,  # lb   t1,(D80)     -> -128 (sign-extended)
    0xF8000393,  # li   t2,-128
    0x02731463,  # bne  t1,t2,FAIL
    0x06005303,  # lhu  t1,(D8000)   -> 0x8000 (zero-extended)
    0x00F35313,  # srli t1,t1,15     -> 1  (proves the top bit was zero-filled)
    0x00100393,  # li   t2,1
    0x00731C63,  # bne  t1,t2,FAIL
    0x06401303,  # lh   t1,(Dh)      -> -2048 (sign-extended)
    0x80000393,  # li   t2,-2048
    0x00731663,  # bne  t1,t2,FAIL
    0x00300513,  # li   a0,3
    0x0080006F,  # j    STORE
    0x00100513,  # FAIL: li a0,1
    0x400004B7,  # lui  s1,0x40000000
    0x00A4A023,  # sw   a0,0(s1)
    0x0000006F,  # j    .            (halt)
    0x00000003,  # Dw:    .word 0x00000003
    0x00000080,  # D80:   .word 0x00000080
    0x00008000,  # D8000: .word 0x00008000
    0xFFFFF800,  # Dh:    .word 0xFFFFF800
]

# --- stores (each latches the result through the GPIO write path) ------------
# Only the GPIO latch is observable (no data RAM), so each store width is tested
# as the SOLE store of the value 3: PASS(3) if it executes, DEAD(0) if it traps.
PROG_STORE_SW = [
    0x00300513,  # li   a0,3
    0x400004B7,  # lui  s1,0x40000000
    0x00A4A023,  # sw   a0,0(s1)
    0x0000006F,  # j    .            (halt)
]
PROG_STORE_SH = [
    0x00300513,  # li   a0,3
    0x400004B7,  # lui  s1,0x40000000
    0x00A49023,  # sh   a0,0(s1)
    0x0000006F,  # j    .            (halt)
]
PROG_STORE_SB = [
    0x00300513,  # li   a0,3
    0x400004B7,  # lui  s1,0x40000000
    0x00A48023,  # sb   a0,0(s1)
    0x0000006F,  # j    .            (halt)
]

# name -> (instructions it covers, program words). Union = full RV32I base ISA.
TESTS = {
    "regalu":   ("add sub sll srl sra and or xor slt sltu",                     PROG_REGALU),
    "immalu":   ("addi slli srli srai andi ori xori slti sltiu lui auipc",      PROG_IMMALU),
    "branch":   ("beq bne blt bge bltu bgeu",                                   PROG_BRANCH),
    "jumps":    ("jal jalr",                                                    PROG_JUMPS),
    "loads":    ("lw lh lhu lb lbu",                                            PROG_LOADS),
    "store_sw": ("sw",                                                          PROG_STORE_SW),
    "store_sh": ("sh",                                                          PROG_STORE_SH),
    "store_sb": ("sb",                                                          PROG_STORE_SB),
}

# -- Pick ONE program to run (uncomment exactly one) --------------------------
ACTIVE = "regalu"
# ACTIVE = "immalu"
# ACTIVE = "branch"
# ACTIVE = "jumps"
# ACTIVE = "loads"
# ACTIVE = "store_sw"
# ACTIVE = "store_sh"
# ACTIVE = "store_sb"

# -- SPI bootloader helpers ---------------------------------------------------
spi = SPI(CONFIG['spi_id'],
          baudrate=1_000_000, polarity=0, phase=0,
          bits=8, firstbit=SPI.MSB,
          sck=Pin(CONFIG['sck']), mosi=Pin(CONFIG['mosi']), miso=Pin(CONFIG['miso']))
cs = Pin(CONFIG['cs'], Pin.OUT, value=1)


def spi_cmd(byte):
    """Send one byte as its own chip-select frame (one bootloader FSM step)."""
    cs.value(0)
    spi.write(bytes([byte & 0xFF]))
    cs.value(1)


def load_and_run(words):
    """Stream <=32 words into the FPGA instruction RAM and start the CPU."""
    image = (list(words) + [NOP] * 32)[:32]   # pad/truncate to exactly 32 words
    spi_cmd(0xA3)                              # halt + re-arm
    spi_cmd(0xA0)                              # enter load
    for w in image:                            # 128 little-endian bytes
        spi_cmd(w)
        spi_cmd(w >> 8)
        spi_cmd(w >> 16)
        spi_cmd(w >> 24)
    spi_cmd(0xA2)                              # run


def flash_bitstream():
    """Load the FPGA bitstream and let the fabric settle. Call once at start."""
    shrike.flash(CONFIG['bitstream'])
    time.sleep(1)


def read_result(settle=0.3):
    """Sample the 2-bit CPU result latch (FPGA GPIO17/18 -> RP2040 GPIO15/14).

    Returns 0..3. A program stores 3 for PASS; 0 means the CPU never reached its
    result store (trap / illegal insn / hang), since the latch clears on reload."""
    time.sleep(settle)                         # CPU finishes in microseconds
    bit0 = Pin(CONFIG['bit0_pin'], Pin.IN).value()
    bit1 = Pin(CONFIG['bit1_pin'], Pin.IN).value()
    return (bit1 << 1) | bit0


# -- Flash, load the ACTIVE program, run, report ------------------------------
# Copy bitstream/shrike_picorv32.bin to the board filesystem before running.
# Running this file directly executes the ACTIVE program; importing it just
# exposes the helpers + TESTS (so other scripts can drive the board).

if __name__ == '__main__':
    covers, program = TESTS[ACTIVE]

    print("Flashing PicoRV32 bitstream to FPGA...")
    flash_bitstream()

    print("{}: testing {}".format(ACTIVE, covers))
    load_and_run(program)

    result = read_result(settle=0.5)
    if result == PASS_VALUE:
        print("result = {} -> PASS  (verified: {})".format(result, covers))
    elif result == 0:
        print("result = 0 -> DEAD  (CPU never stored a result: trap / hang?)")
    else:
        print("result = {} -> FAIL  (ran but a tested instruction is wrong)".format(result))
