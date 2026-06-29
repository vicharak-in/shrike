#cordic.py
# Author: Yash Sharda
# Interactive test runner for the CORDIC math coprocessor on Shrike Lite.
# Valid angle range: 0 to 45 degrees.

import math
import time
import shrike
from machine import Pin, SPI

# FPGA bring-up
shrike.flash("FPGA_bitstream_MCU.bin")
reset_pin = Pin(14, Pin.OUT, value=1)
reset_pin.value(0)
time.sleep(0.1)
reset_pin.value(1)
time.sleep(0.1)

# SPI setup
cs  = Pin(1, Pin.OUT, value=1)
spi = SPI(0, baudrate=1_000_000, polarity=0, phase=0, bits=8,
          sck=Pin(2), mosi=Pin(3), miso=Pin(0))

def spi_exchange(byte_val):
    rx = bytearray(1)
    cs.value(0)
    spi.write_readinto(bytes([byte_val]), rx)
    cs.value(1)
    return rx[0]

def fpga_query(mode, val1, val2=0):
    if mode == "cos":
        packet = (int(val1 * 64) & 0x3F) | 0x00
    elif mode == "sin":
        packet = (int(val1 * 64) & 0x3F) | 0x40
    elif mode == "mul":
        packet = ((int(val1) & 0x07) << 3) | (int(val2) & 0x07) | 0x80
    elif mode == "tan":
        packet = (int(val1 * 64) & 0x3F) | 0xC0

    spi_exchange(packet)
    time.sleep_us(15)
    raw = spi_exchange(0x00)

    if raw & 0x80:
        raw -= 0x100
    fpga_val = raw if mode == "mul" else raw / 64.0

    if mode == "sin":
        ref = math.sin(val1)
    elif mode == "cos":
        ref = math.cos(val1)
    elif mode == "tan":
        ref = math.tan(val1)
    elif mode == "mul":
        ref = float(val1 * val2)

    return fpga_val, ref, abs(fpga_val - ref)



print()
print("CORDIC Coprocessor  |  angle range: 0 to 45 deg")
print()
print("  cos  sin  tan  mul  exit")
print()

while True:
    try:
        mode = input("> ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        break

    if mode == "exit":
        break

    elif mode in ("cos", "sin", "tan"):
        try:
            deg = float(input("angle (deg) > "))
        except ValueError:
            print("  number please")
            continue
        if not (0.0 <= deg <= 45.0):
            print("  0 to 45 deg only")
            continue
        rad = math.radians(deg)
        fpga, ref, err = fpga_query(mode, rad)
        print(f"  fpga {fpga:.4f}  ref {ref:.4f}  err {err:.6f}")

    elif mode == "mul":
        try:
            a = int(input("a (3-bit signed, -4 to 3) > "))
            b = int(input("b (3-bit signed, -4 to 3) > "))
        except ValueError:
            print("  integers only")
            continue
        if not (-4 <= a <= 3 and -4 <= b <= 3):
            print("  range: -4 to 3")
            continue
        fpga, ref, err = fpga_query("mul", a, b)
        print(f"  fpga {fpga:.4f}  ref {ref:.4f}  err {err:.6f}")

    else:
        print("  modes: cos  sin  tan  mul  exit")
