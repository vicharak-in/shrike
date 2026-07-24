# Board-only self-test : UART <-> I2C bridge (I2C_to_UART bitstream)
# -----------------------------------------------------------------
# Connect ONLY the Shrike-Lite over USB. Load the I2C_to_UART
# bitstream onto the FPGA first, then run this on the RP2040.
#
# The RP2040 plays the "external I2C master" (I2C1) AND the UART peer,
# so no extra hardware is needed. It checks BOTH directions of the
# bidirectional bridge and prints PASS/FAIL to the USB REPL.
#
#   Dir 1 (I2C -> UART): I2C master writes X to the FPGA(0x50);
#                        the FPGA forwards it out on UART; we read it.
#   Dir 2 (UART -> I2C): we send Y on UART; the FPGA buffers it;
#                        we read it back over I2C.
#
# Pins (fixed on Shrike-Lite): UART0 tx=GP0 rx=GP1 ; I2C1 sda=GP14 scl=GP15

from machine import Pin, UART, I2C, mem32
import time
import random
import shrike

shrike.flash("i2c_to_uart.bin")
time.sleep(1)
FPGA_ADDR = 0x50

uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
i2c  = I2C(1, sda=Pin(14), scl=Pin(15), freq=100000)

# Force the RP2040's INTERNAL pull-ups on the I2C1 pads (GP14=SDA, GP15=SCL)
# so no external pull-up resistors are needed for a quick bench test.
# (PADS_BANK0 GPIOn reg = 0x4001C000 + 0x04 + n*4 ; bit3=PUE, bit2=PDE.)
_PADS_BANK0 = 0x4001C000
for _gp in (14, 15):
    _reg = _PADS_BANK0 + 0x04 + _gp * 4
    mem32[_reg] = (mem32[_reg] | (1 << 3)) & ~(1 << 2)   # pull-up on, pull-down off

# quick presence check
try:
    devices = i2c.scan()
    print("I2C scan:", [hex(d) for d in devices])
    if FPGA_ADDR not in devices:
        print("WARNING: FPGA (0x50) not found on I2C. Check the bitstream / pull-ups.")
except Exception as e:
    print("I2C scan failed:", e)

if uart.any():
    uart.read()

vectors = [0x00, 0xFF, 0x55, 0xAA, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]
vectors += [random.randint(0, 255) for _ in range(20)]

passes = 0
total = 0

print("\n=== UART <-> I2C bidirectional self-test ===\n")

print("-- Direction 1: I2C write -> UART out --")
for v in vectors:
    total += 1
    if uart.any():
        uart.read()
    try:
        i2c.writeto(FPGA_ADDR, bytes([v]))
    except OSError:
        print("  I2C write error for 0x%02X" % v)
        continue
    got = None
    t0 = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), t0) < 50:
        if uart.any():
            got = uart.read(1)[0]
            break
    if got == v:
        passes += 1
    else:
        print("  FAIL  sent 0x%02X  got %s" % (v, got))

print("-- Direction 2: UART in -> I2C read --")
for v in vectors:
    total += 1
    uart.write(bytes([v]))
    time.sleep_ms(10)
    try:
        got = i2c.readfrom(FPGA_ADDR, 1)[0]
    except OSError:
        print("  I2C read error")
        continue
    if got == v:
        passes += 1
    else:
        print("  FAIL  sent 0x%02X  got 0x%02X" % (v, got))

print("\nPassed %d / %d" % (passes, total))
print("STATUS: SUCCESS" if passes == total else "STATUS: FAILURE")
