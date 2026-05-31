# =============================================================================
# shrike_picorv32.py
# Project  : shrike_picorv32
# Board    : Shrike-lite (RP2040) / Shrike (RP2350)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : GPL-2.0
#
# Flashes the PicoRV32 RISC-V bitstream to the SLG47910 FPGA, then reads back
# the 2-bit result the CPU drives onto GPIO17/18.
#
# The baked program in nuclear_rom.v is an RV32I instruction-variety self-test:
# it threads one accumulator (x10) through 27 distinct RV32I opcodes -- adds,
# subs, the full logic set, all three shifts, set-less-than, every branch type
# as a must-not-take gate, lui, jal and a store -- and writes the final value
# to the GPIO result latch. If every instruction executed correctly the result
# is exactly 3 (0b11, both result bits high). Any other value means some
# instruction misbehaved (e.g. a branch wrongly taken, or a stale register read
# -- the very bugs the read-latency fix addresses).
#
# Expected output:
#   Flashing PicoRV32 bitstream to FPGA...
#   [shrike_flash] FPGA programming done.
#   PicoRV32 RV32I self-test result = 3 -> PASS (all 27 opcodes correct)
# =============================================================================

import sys
import time
import shrike
from machine import Pin

# -- Platform configuration ---------------------------------------------------
# FPGA GPIO17/18 are hardwired to RP2040 GPIO15/14 via PCB 0-ohm resistors.
# Shrike-fi (ESP32-S3) pin mapping for these traces is untested; add an
# `elif sys.platform == 'esp32'` branch once verified on hardware.

if sys.platform == 'rp2':
    CONFIG = {
        'platform':  'RP2040/RP2350',
        'bit0_pin':  15,   # RP2040 GPIO15 <- FPGA GPIO17 (result bit 0)
        'bit1_pin':  14,   # RP2040 GPIO14 <- FPGA GPIO18 (result bit 1)
        'bitstream': 'shrike_picorv32.bin',
    }
else:
    raise RuntimeError(
        "Unsupported platform: {}. Supported: 'rp2'.".format(sys.platform)
    )

PASS_VALUE = 3   # x10 == 3 after the self-test == every opcode correct

# -- Flash FPGA ---------------------------------------------------------------
# Copy bitstream/shrike_picorv32.bin to the board filesystem via Thonny file
# panel before running this script.

print("Flashing PicoRV32 bitstream to FPGA...")
shrike.flash(CONFIG['bitstream'])

# The self-test is ~32 instructions; the picorv32 small config takes a handful
# of cycles per instruction at ~45 MHz, so it completes in microseconds. The
# power-on reset counter in the top releases the CPU within 16 cycles. A 1 s
# settle is generous.
time.sleep(1)

# -- Read result --------------------------------------------------------------
bit0 = Pin(CONFIG['bit0_pin'], Pin.IN).value()
bit1 = Pin(CONFIG['bit1_pin'], Pin.IN).value()
result = (bit1 << 1) | bit0

if result == PASS_VALUE:
    print("PicoRV32 RV32I self-test result = {} -> PASS "
          "(all 27 opcodes correct)".format(result))
else:
    print("PicoRV32 RV32I self-test result = {} -> FAIL "
          "(expected {})".format(result, PASS_VALUE))
