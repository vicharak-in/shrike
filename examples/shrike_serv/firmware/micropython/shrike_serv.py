# =============================================================================
# shrike_serv.py
# Project  : shrike_serv
# Board    : Shrike-lite (RP2040) / Shrike (RP2350)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : GPL-2.0
#
# Flashes the SERV RISC-V bitstream to the SLG47910 FPGA, reads the 2-bit
# result from GPIO pins, and prints the result over USB serial.
#
# Expected output:
#   SERV RISC-V computed: 1 + 2 = 3
#
# PIN MAP (internal PCB traces — Shrike-lite)
#   FPGA GPIO17 → RP2040 GPIO15  =  result bit 0  (expected: HIGH)
#   FPGA GPIO18 → RP2040 GPIO14  =  result bit 1  (expected: HIGH)
#   result = (bit1 << 1) | bit0  =  0b11  =  3
# =============================================================================

import sys
import time

# ── Platform configuration ────────────────────────────────────────────────────
PLATFORM = sys.platform   # 'rp2' for RP2040, 'esp32' for ESP32-S3

if PLATFORM == 'rp2':
    BIT0_PIN  = 15   # RP2040 GPIO15 ← FPGA GPIO17 (result bit 0)
    BIT1_PIN  = 14   # RP2040 GPIO14 ← FPGA GPIO18 (result bit 1)
elif PLATFORM == 'esp32':
    BIT0_PIN  = 15   # untested — update for Shrike-fi pin map
    BIT1_PIN  = 14
    print("WARNING: ESP32-S3 pin mapping not verified for this example")
else:
    raise RuntimeError(f"Unsupported platform: {PLATFORM}")

BITSTREAM = "shrike_serv.bin"

# ── Flash FPGA ────────────────────────────────────────────────────────────────
# Copy bitstream/shrike_serv.bin to the board filesystem via Thonny file panel
# before running this script.

import shrike
from machine import Pin

print("Flashing SERV bitstream to FPGA...")
shrike.flash(BITSTREAM)

# At 50 MHz: 6 instructions × ~32 cycles ≈ 4 µs. 1 s is generous.
time.sleep(1)

# ── Read result ───────────────────────────────────────────────────────────────
bit0_pin = Pin(BIT0_PIN, Pin.IN)
bit1_pin = Pin(BIT1_PIN, Pin.IN)

bit0   = bit0_pin.value()
bit1   = bit1_pin.value()
result = (bit1 << 1) | bit0

print(f"SERV RISC-V computed: 1 + 2 = {result}")
