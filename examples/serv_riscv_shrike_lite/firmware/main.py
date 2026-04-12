# =============================================================================
# main.py
# Board    : Shrike-lite (RP2040 side)
# Tool     : Thonny + MicroPython (Shrike custom UF2)
# License  : GPL-2.0
#
# Flashes the SERV RISC-V bitstream to the SLG47910 FPGA, waits for the CPU
# to execute the 1+2=3 program, reads the 2-bit result from GPIO, and prints.
#
# Expected output:
#   SERV RISC-V computed: 1 + 2 = 3
#
# PIN MAP (internal PCB traces — from official Shrike-lite pinout docs)
#   FPGA GPIO17 → RP2040 GPIO15  =  result bit 0  (expected: 1)
#   FPGA GPIO18 → RP2040 GPIO14  =  result bit 1  (expected: 1)
#   result = (bit1 << 1) | bit0  =  0b11  =  3
# =============================================================================

import shrike
from machine import Pin
import time

# Step 1 — Flash SERV bitstream to FPGA.
# Copy serv_shrike.bin (renamed from FPGA_bitstream_MCU.bin) to the board
# filesystem via Thonny's file panel before running this script.
print("Flashing SERV bitstream to FPGA...")
shrike.flash("serv_shrike.bin")

# Step 2 — Wait for FPGA to initialise and execute the program.
# At 50 MHz, 6 instructions × ~32 cycles = ~192 cycles ≈ 4 µs.
# One second is generous — also covers oscillator stabilisation time.
time.sleep(1)

# Step 3 — Read 2-bit result from FPGA GPIO pins (RP2040 as input).
bit0_pin = Pin(15, Pin.IN)   # FPGA GPIO17 → RP2040 GPIO15  (result bit 0)
bit1_pin = Pin(14, Pin.IN)   # FPGA GPIO18 → RP2040 GPIO14  (result bit 1)

bit0   = bit0_pin.value()
bit1   = bit1_pin.value()
result = (bit1 << 1) | bit0

# Step 4 — Print result.
print(f"SERV RISC-V computed: 1 + 2 = {result}")
