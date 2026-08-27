# =============================================================================
# shrike_serv.py
# Project  : shrike_serv  (runtime-programmable SERV RV32I core)
# Board    : Shrike-lite (RP2040) / Shrike (RP2350)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : ISC (matches the vendored SERV core)
#
# Flashes the SERV bitstream, then streams a program image into the FPGA's 4 KB
# BRAM memory over SPI and runs it -- no re-synthesis, no new bitstream. The CPU
# writes its pass/fail result to a memory-mapped latch (store to 0x40000000); the
# top maps that to 2 bits on FPGA GPIO17/18 -> RP2040 GPIO15/14, read by the MCU:
#       3 = PASS   (test stored 1 to the result MMIO)
#       1 = FAIL   (test ran but reported a wrong value)
#       0 = DEAD   (CPU never reached the store: trap / hang; latch clears on load)
#
# Unlike the PicoRV32 example (32-word hand-written programs), SERV keeps its
# register file in distributed RAM, freeing all 8 BRAM slices for one 4 KB
# memory. That fits any single rv32ui test, so this driver streams the real
# riscv-tests binaries (padded to 4096 bytes) from the board filesystem.
#
# SPI load protocol (bootloader FSM in shrike_serv_top.v):
#   0xA0             enter load (halt core, reset write pointer)
#   <4096 bytes>     program image, little-endian, zero-padded to the fixed length
#   0xA2             run (release the core)
#   0xA3             halt (re-arm before loading a new program)
#
# USAGE (on the board, via Thonny/mpremote):
#   1. Copy bitstream/shrike_serv.bin + this file + the serv_tests/ dir to the board.
#   2. Run this file: it flashes, then runs every serv_tests/*.bin and tallies.
#      Or import it and call run_test("serv_tests/add.bin").
# =============================================================================

import sys
import os
import time
import shrike
from machine import Pin, SPI

if sys.platform == 'rp2':
    CONFIG = {
        'spi_id':    0,
        'sck':       2,    # RP2040 GPIO2  -> FPGA spi_sck
        'mosi':      3,    # RP2040 GPIO3  -> FPGA spi_mosi
        'miso':      0,    # RP2040 GPIO0  (unused; FPGA does not drive MISO)
        'cs':        1,    # RP2040 GPIO1  -> FPGA spi_ss_n
        'bit0_pin':  15,   # RP2040 GPIO15 <- FPGA GPIO17 (result bit 0 = "done")
        'bit1_pin':  14,   # RP2040 GPIO14 <- FPGA GPIO18 (result bit 1 = "pass")
        'bitstream': 'shrike_serv.bin',
    }
else:
    raise RuntimeError("Unsupported platform: {}. Supported: 'rp2'.".format(sys.platform))

PROG_BYTES = 4096
PASS_VALUE = 3
TESTS_DIR  = 'serv_tests'

# -- SPI bootloader helpers ---------------------------------------------------
spi = SPI(CONFIG['spi_id'],
          baudrate=1_000_000, polarity=0, phase=0,
          bits=8, firstbit=SPI.MSB,
          sck=Pin(CONFIG['sck']), mosi=Pin(CONFIG['mosi']), miso=Pin(CONFIG['miso']))
cs = Pin(CONFIG['cs'], Pin.OUT, value=1)


def spi_cmd(byte):
    """Send one control byte as its own chip-select frame (one FSM step)."""
    cs.value(0)
    spi.write(bytes([byte & 0xFF]))
    cs.value(1)


def load_and_run(image):
    """Stream a program image into BRAM (padded to 4096 bytes) and start the core."""
    img = (bytes(image) + b'\x00' * PROG_BYTES)[:PROG_BYTES]
    spi_cmd(0xA3)                 # halt + re-arm
    spi_cmd(0xA0)                 # enter load
    cs.value(0)                   # one burst for the whole payload (fast)
    spi.write(img)
    cs.value(1)
    spi_cmd(0xA2)                 # run


def flash_bitstream():
    """Load the FPGA bitstream and let the fabric settle. Call once at start."""
    shrike.flash(CONFIG['bitstream'])
    time.sleep(1)


def read_result(settle=0.3):
    """Sample the 2-bit result latch. Returns 0..3 (3=PASS, 1=FAIL, 0=DEAD).
    SERV is bit-serial (~40-80 cycles/instruction), so give it a moment."""
    time.sleep(settle)
    bit0 = Pin(CONFIG['bit0_pin'], Pin.IN).value()
    bit1 = Pin(CONFIG['bit1_pin'], Pin.IN).value()
    return (bit1 << 1) | bit0


def run_test(path, settle=0.5):
    """Load one test .bin, run it, and return 0..3."""
    with open(path, 'rb') as f:
        image = f.read()
    load_and_run(image)
    return read_result(settle=settle)


# -- Flash, run every serv_tests/*.bin, tally --------------------------------
if __name__ == '__main__':
    print("Flashing SERV bitstream to FPGA...")
    flash_bitstream()

    try:
        names = sorted(f for f in os.listdir(TESTS_DIR) if f.endswith('.bin'))
    except OSError:
        names = []
    if not names:
        print("No tests in {}/ -- copy the serv_tests/*.bin to the board.".format(TESTS_DIR))
        sys.exit(1)

    npass = nfail = ndead = 0
    for name in names:
        r = run_test(TESTS_DIR + '/' + name)
        t = name[:-4]
        if r == PASS_VALUE:
            print("  PASS  {}".format(t)); npass += 1
        elif r == 0:
            print("  DEAD  {}  (trap/hang: no result stored)".format(t)); ndead += 1
        else:
            print("  FAIL  {}  (result={})".format(t, r)); nfail += 1

    print("-------------------------------------------")
    print("SERV rv32ui on hardware: PASS={} FAIL={} DEAD={} / {}".format(
        npass, nfail, ndead, len(names)))
    if npass == len(names):
        print("ALL RV32UI TESTS PASSED ON HARDWARE")
