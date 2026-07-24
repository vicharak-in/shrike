# uart_to_i2c bridge self-test  (FPGA is the I2C MASTER)
# -----------------------------------------------------------------
# Board-only test: the FPGA drives I2C as master, so the RP2040 must
# play the I2C SLAVE (it emulates the external sensor) AND be the UART
# peer. MicroPython has no I2C-slave API, so the slave is configured
# by poking the RP2040 DW_apb_i2c registers directly.
#
# Flow per byte X:
#   RP2040 sends X on UART  -> FPGA writes X to the slave (we capture)
#                           -> FPGA reads the slave (we return X+0x10)
#                           -> FPGA echoes that on UART (we verify)
#
# For a REAL external sensor instead of this emulation: set I2C_ADDR in
# top.v to the sensor address, connect the sensor to the I2C pins, and
# run only the UART side (no RP2040 slave setup).
#
# Wiring (Shrike-Lite): UART0 tx=GP0 rx=GP1 ; I2C1 sda=GP14 scl=GP15.

from machine import Pin, UART, I2C, mem32
import time
import random

I2C1_BASE = 0x40048000          # RP2040 I2C1 (RP2350 differs: 0x40098000)
FPGA_MASTER_TARGET = 0x50       # address the FPGA master talks to (matches top.v)

uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
_    = I2C(1, sda=Pin(14), scl=Pin(15), freq=100000)   # claim the I2C1 pins

# Force internal pull-ups on GP14/GP15 (no external resistors needed for bench).
_PADS = 0x4001C000
for _gp in (14, 15):
    _r = _PADS + 0x04 + _gp * 4
    mem32[_r] = (mem32[_r] | (1 << 3)) & ~(1 << 2)

# Configure RP2040 I2C1 as a SLAVE at 0x50
mem32[I2C1_BASE + 0x6C] = 0            # IC_ENABLE = 0
mem32[I2C1_BASE + 0x00] = 0x22         # IC_CON: slave mode
mem32[I2C1_BASE + 0x08] = FPGA_MASTER_TARGET   # IC_SAR
mem32[I2C1_BASE + 0x6C] = 1            # IC_ENABLE = 1

def flush():
    _ = mem32[I2C1_BASE + 0x40]        # IC_CLR_INTR
    _ = mem32[I2C1_BASE + 0x50]        # IC_CLR_RD_REQ
    _ = mem32[I2C1_BASE + 0x54]        # IC_CLR_TX_ABRT
    _ = mem32[I2C1_BASE + 0x60]        # IC_CLR_STOP_DET

while mem32[I2C1_BASE + 0x78] > 0:     # drain RX FIFO (IC_RXFLR)
    _ = mem32[I2C1_BASE + 0x10]
if uart.any():
    uart.read()

vectors = [0x00, 0xFF, 0x55, 0xAA, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]
vectors += [random.randint(0, 255) for _ in range(20)]

passes = 0
total = 0

print("=== uart_to_i2c self-test (FPGA I2C master; RP2040 = slave) ===\n")

for v in vectors:
    total += 1
    reply = (v + 0x10) & 0xFF
    flush()

    uart.write(bytes([v]))             # trigger -> FPGA UART -> FPGA I2C write

    # 1) capture the FPGA's I2C write
    t0 = time.ticks_ms(); got_w = None
    while time.ticks_diff(time.ticks_ms(), t0) < 50:
        if mem32[I2C1_BASE + 0x78] > 0:              # IC_RXFLR
            got_w = mem32[I2C1_BASE + 0x10] & 0xFF   # IC_DATA_CMD
            break
    if got_w is None:
        print("  timeout: no I2C write for 0x%02X" % v)
        continue

    # 2) service the FPGA's I2C read request with reply = X + 0x10
    t0 = time.ticks_ms(); served = False
    while time.ticks_diff(time.ticks_ms(), t0) < 50:
        if mem32[I2C1_BASE + 0x34] & (1 << 5):       # IC_RAW_INTR_STAT.RD_REQ
            mem32[I2C1_BASE + 0x10] = reply          # IC_DATA_CMD <- reply
            _ = mem32[I2C1_BASE + 0x50]              # IC_CLR_RD_REQ
            served = True
            break
    if not served:
        print("  timeout: no I2C read request for 0x%02X" % v)
        continue

    # 3) verify the UART echo of the reply
    t0 = time.ticks_ms(); echo = None
    while time.ticks_diff(time.ticks_ms(), t0) < 50:
        if uart.any():
            echo = uart.read(1)[0]
            break
    if echo == reply:
        passes += 1
    else:
        print("  FAIL  sent 0x%02X  exp 0x%02X  got %s" % (v, reply, echo))

print("\nPassed %d / %d" % (passes, total))
print("STATUS: SUCCESS" if passes == total else "STATUS: FAILURE")
