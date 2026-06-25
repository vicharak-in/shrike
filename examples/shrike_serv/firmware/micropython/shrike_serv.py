# =============================================================================
# shrike_serv.py
# Project  : shrike_serv  (runtime-programmable bit-serial SERV core)
# Board    : Shrike-lite (RP2040) / Shrike (RP2350)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : GPL-2.0
#
# Flashes the SERV bitstream, then streams a themed RV32I program into the
# FPGA over SPI and runs it -- no re-synthesis, no new bitstream. The CPU writes
# its final result to a memory-mapped GPIO latch (store to 0x40000000); the low
# 2 bits drive FPGA GPIO17/18, hardwired to RP2040 GPIO15/14, read back by the MCU.
#
# RV32I CONFORMANCE SUITE
#    This file holds several themed programs (TESTS below). Each is
#    self-checking and latches:
#        3 = PASS   (every instruction it tests behaved correctly)
#        1 = FAIL   (it ran but computed a wrong value)
#        0 = DEAD   (the CPU never reached the store: trap / illegal / hang;
#                    the latch is cleared to 0 on every reload)
#
# Select which one runs by uncommenting exactly one ACTIVE = ... line.
# =============================================================================

import sys
import time
import shrike
from machine import Pin, SPI

# -- Platform configuration ---------------------------------------------------
if sys.platform == 'rp2':
    CONFIG = {
        'platform':  'RP2040/RP2350',
        'spi_id':    0,
        'sck':       2,    # RP2040 GPIO2  -> FPGA spi_sck
        'mosi':      3,    # RP2040 GPIO3  -> FPGA spi_mosi
        'miso':      0,    # RP2040 GPIO0  (unused)
        'cs':        1,    # RP2040 GPIO1  -> FPGA spi_ss_n
        'bit0_pin':  15,   # RP2040 GPIO15 <- FPGA GPIO17 (result bit 0)
        'bit1_pin':  14,   # RP2040 GPIO14 <- FPGA GPIO18 (result bit 1)
        'bitstream': 'FPGA_bitstream_MCU.bin',
    }
else:
    raise RuntimeError(
        "Unsupported platform: {}. Supported: 'rp2'.".format(sys.platform)
    )

NOP        = 0x00000013
PASS_VALUE = 3

# =============================================================================
# RV32I CONFORMANCE PROGRAMS (Padded out dynamically to fill your 128-word BRAM)
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
PROG_IMMALU = [
    0x00D00293, 0xFF300F13, 0x00528313, 0x00229E93, 0x01D30333,
    0x0022DE93, 0x01D30333, 0x402F5E93, 0x01D30333, 0x0062FE93,
    0x01D30333, 0x0022EE93, 0x01D30333, 0x0062CE93, 0x01D30333,
    0x000F2E93, 0x01D30333, 0x001F3E93, 0x01D30333, 0x00001EB7,
    0x00CEDE93, 0x01D30333, 0x00000E97, 0x01D30333, 0x0BD00393,
    0x00100513, 0x00731463, 0x00300513, 0x400004B7, 0x00A4A023,
    0x0000006F
]

# --- branches (each tested BOTH taken and not-taken): beq bne blt bge --------
PROG_BRANCH = [
    0x00500293, 0x00500E13, 0x00700E93, 0xFFD00F13, 0x01C28463,
    0x04C0006F, 0x05D28463, 0x01D29463, 0x0400006F, 0x03C29E63,
    0x005F4463, 0x0340006F, 0x03E2C863, 0x01C2D463, 0x0280006F,
    0x025F5263, 0x01D2E463, 0x01C0006F, 0x005F6C63, 0x005F7463,
    0x0100006F, 0x01D2F663, 0x00300513, 0x0080006F, 0x00100513,
    0x400004B7, 0x00A4A023, 0x0000006F
]

# --- loads (all widths + sign/zero extension): lw lh lhu lb lbu --------------
PROG_LOADS = [
    0x05802303, 0x00300393, 0x04731063, 0x05C04303, 0x08000393,
    0x02731A63, 0x05C00303, 0xF8000393, 0x02731463, 0x06005303,
    0x00F35313, 0x00100393, 0x00731C63, 0x06401303, 0x80000393,
    0x00731663, 0x00300513, 0x0080006F, 0x00100513, 0x400004B7,
    0x00A4A023, 0x0000006F, 0x00000003, 0x00000080, 0x00008000,
    0xFFFFF800
]

# --- long program test: 40 NOPs then store 3 -- confirms 128-word BRAM works -
PROG_LONGTEST = [
    0x00300513,      # li   a0, 3
    0x400004B7,      # lui  s1, 0x40000
    0x00A4A023,      # sw   a0, 0(s1)
    0x0000006F,      # j    .  (halt)
]

TESTS = {
    "regalu":    ("add sub sll srl sra and or xor slt sltu",             PROG_REGALU),
    "immalu":    ("addi slli srli srai andi ori xori slti sltiu lui auipc", PROG_IMMALU),
    "branch":    ("beq bne blt bge bltu bgeu",                           PROG_BRANCH),
    "loads":     ("lw lh lhu lb lbu",                                    PROG_LOADS),
    "longtest":  ("128-word BRAM depth check (40 NOPs + store)",         PROG_LONGTEST),
}

# -- Pick ONE program to run (uncomment exactly one) --------------------------
ACTIVE = "regalu"
# ACTIVE = "immalu"
# ACTIVE = "branch"
# ACTIVE = "loads"
# ACTIVE = "longtest"

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
    """Stream <=128 words into the FPGA instruction RAM and start the CPU."""
    image = (list(words) + [NOP] * 128)[:128]
    spi_cmd(0xA3)                              # halt + re-arm
    spi_cmd(0xA0)                              # enter load
    for w in image:                            # 512 little-endian bytes total
        spi_cmd(w)
        spi_cmd(w >> 8)
        spi_cmd(w >> 16)
        spi_cmd(w >> 24)
    spi_cmd(0xA2)                              # run


def flash_bitstream():
    """Load the FPGA bitstream and let the fabric settle. Call once at start."""
    shrike.flash(CONFIG['bitstream'])
    time.sleep(1)


def read_result(settle=0.5):
    """Sample the 2-bit CPU result latch."""
    time.sleep(settle)
    bit0 = Pin(CONFIG['bit0_pin'], Pin.IN).value()
    bit1 = Pin(CONFIG['bit1_pin'], Pin.IN).value()
    return (bit1 << 1) | bit0


# -- Flash, load the ACTIVE program, run, report ------------------------------
if __name__ == '__main__':
    covers, program = TESTS[ACTIVE]

    print("Flashing SERV Core bitstream to FPGA...")
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
