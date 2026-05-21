# =============================================================================
# shrike_picorv32.py
# Project  : shrike_picorv32
# Board    : Shrike-lite (RP2040) / Shrike (RP2350)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : GPL-2.0
#
# Flashes the PicoRV32 RISC-V bitstream to the SLG47910 FPGA, reads the 2-bit
# computation result from GPIO pins, and prints it over USB serial.
#
# Expected output:
#   Flashing PicoRV32 bitstream to FPGA...
#   [shrike_flash] FPGA programming done.
#   PicoRV32 RISC-V computed: 1 + 2 = 3
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

# -- Flash FPGA ---------------------------------------------------------------
# Copy bitstream/shrike_picorv32.bin to the board filesystem via Thonny file
# panel before running this script.

print("Flashing PicoRV32 bitstream to FPGA...")
shrike.flash(CONFIG['bitstream'])

# PicoRV32 small config takes ~5 cycles/instruction. 6 instructions at
# 45 MHz completes in well under 1 us; 1 s settling time is generous.
time.sleep(1)

# -- Read result --------------------------------------------------------------
bit0 = Pin(CONFIG['bit0_pin'], Pin.IN).value()
bit1 = Pin(CONFIG['bit1_pin'], Pin.IN).value()
result = (bit1 << 1) | bit0

print("PicoRV32 RISC-V computed: 1 + 2 = {}".format(result))
