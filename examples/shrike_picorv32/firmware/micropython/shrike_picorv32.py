# =============================================================================
# shrike_picorv32.py
# Project  : shrike_picorv32  (runtime-programmable RV32I core)
# Board    : Shrike-lite (RP2040) / Shrike (RP2350)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : GPL-2.0
#
# Flashes the PicoRV32 bitstream, then STREAMS AN RV32I PROGRAM INTO THE FPGA
# OVER SPI and runs it -- no re-synthesis, no new bitstream. The CPU writes its
# final result to a memory-mapped GPIO latch (store to 0x40000000); the low 2
# bits drive FPGA GPIO17/18, hardwired to RP2040 GPIO15/14, which we read back.
#
# To run your own program: edit PROGRAM below (a list of 32-bit RV32I
# instruction words, up to 32 of them) and re-run this script. Nothing else
# changes -- the same bitstream executes whatever you load.
#
# SPI load protocol (the bootloader FSM in shrike_picorv32_top.v):
#   0xA0          enter load (halt CPU, reset write pointer)
#   <128 bytes>   program image, 32 words x 4 bytes, little-endian
#   0xA2          run (release the CPU)
#   0xA3          halt (re-arm before loading a new program)
#
# Expected output:
#   Flashing PicoRV32 bitstream to FPGA...
#   [shrike_flash] FPGA programming done.
#   Loading 32-word program over SPI...
#   PicoRV32 result = 3 -> PASS (RV32I instruction-variety self-test)
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

# -- The program to run -------------------------------------------------------
# RV32I instruction-variety self-test: threads accumulator x10 through 27
# distinct opcodes (arith/logic/shift/set-less-than in register+immediate
# forms), uses every branch as a must-not-take gate, then jal + sw. A correct
# core leaves x10 == 3 and stores it to 0x40000000. Up to 32 words; the rest of
# the 128-byte (PC_W=7) instruction RAM is padded with NOP.
PROGRAM = [
    0x00600093,  # li   ra,6
    0x00300113,  # li   sp,3
    0x00100193,  # li   gp,1
    0x00600513,  # li   a0,6
    0x00251513,  # slli a0,a0,0x2
    0x00155513,  # srli a0,a0,0x1
    0x00351533,  # sll  a0,a0,gp
    0x00355533,  # srl  a0,a0,gp
    0x40355533,  # sra  a0,a0,gp
    0x40155513,  # srai a0,a0,0x1
    0x00150533,  # add  a0,a0,ra
    0x40250533,  # sub  a0,a0,sp
    0x00157533,  # and  a0,a0,ra
    0x00356533,  # or   a0,a0,gp
    0x00254533,  # xor  a0,a0,sp
    0x00E57513,  # andi a0,a0,14
    0x00156513,  # ori  a0,a0,1
    0x00654513,  # xori a0,a0,6
    0x00112233,  # slt  tp,sp,ra
    0x0020B2B3,  # sltu t0,ra,sp
    0x00512313,  # slti t1,sp,5
    0x02208463,  # beq  ra,sp,halt   (must NOT take)
    0x02109263,  # bne  ra,ra,halt   (must NOT take)
    0x0220C063,  # blt  ra,sp,halt   (must NOT take)
    0x00115E63,  # bge  sp,ra,halt   (must NOT take)
    0x0020EC63,  # bltu ra,sp,halt   (must NOT take)
    0x00117A63,  # bgeu sp,ra,halt   (must NOT take)
    0x0080006F,  # j    +8           (jump over the poison addi)
    0x00150513,  # addi a0,a0,1      (poison: skipped by the jal)
    0x400004B7,  # lui  s1,0x40000   (GPIO result base)
    0x00A4A023,  # sw   a0,0(s1)     (latch result = x10)
    0x0000006F,  # j    .            (halt)
]
PASS_VALUE = 3   # x10 == 3 after the self-test == every opcode correct
NOP        = 0x00000013

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


# -- Flash, load, run, read result --------------------------------------------
# Copy bitstream/shrike_picorv32.bin to the board filesystem (e.g. via Thonny)
# before running this script.

print("Flashing PicoRV32 bitstream to FPGA...")
shrike.flash(CONFIG['bitstream'])
time.sleep(1)                                  # let the FPGA settle after config

print("Loading {}-word program over SPI...".format(len(PROGRAM)))
load_and_run(PROGRAM)
time.sleep(0.5)                                # CPU finishes in microseconds

bit0 = Pin(CONFIG['bit0_pin'], Pin.IN).value()
bit1 = Pin(CONFIG['bit1_pin'], Pin.IN).value()
result = (bit1 << 1) | bit0

if result == PASS_VALUE:
    print("PicoRV32 result = {} -> PASS "
          "(RV32I instruction-variety self-test)".format(result))
else:
    print("PicoRV32 result = {} -> FAIL (expected {})".format(result, PASS_VALUE))
