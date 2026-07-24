# SPI <-> I2C bridge self-test  (FPGA = SPI slave + I2C MASTER)
# -----------------------------------------------------------------
# Board-only test: the FPGA is the SPI slave AND the I2C master, so the
# RP2040 plays the SPI MASTER and also emulates the I2C SLAVE (sensor)
# via register pokes (MicroPython has no I2C-slave API).
#
# Flow per byte X:
#   RP2040 SPI writes X -> FPGA writes X to the I2C slave (we capture)
#                       -> FPGA reads the slave (we return X+0x05)
#                       -> FPGA puts the reply in its SPI TX buffer
#   RP2040 SPI reads    -> gets the reply back -> verify == X+0x05
#
# For a REAL sensor: set TARGET_SLAVE_ADDR in top.v, wire the sensor to
# the I2C pins, and drop the RP2040 I2C-slave emulation below.
#
# Wiring (Shrike-Lite): SPI0 sck=GP2 mosi=GP3 miso=GP0 cs=GP1 ;
#                       I2C1 sda=GP14 scl=GP15.

from machine import Pin, SPI, I2C, mem32
import time
import random
import shrike

shrike.flash("spi_to_i2c.bin")
time.sleep(1)

I2C1_BASE = 0x40048000          # RP2040 I2C1 (RP2350 differs: 0x40098000)
SENSOR_ADDR = 0x50              # must match TARGET_SLAVE_ADDR in top.v

spi = SPI(0, baudrate=1000000, polarity=0, phase=0,
          sck=Pin(2), mosi=Pin(3), miso=Pin(0))
cs  = Pin(1, Pin.OUT, value=1)
_   = I2C(1, sda=Pin(14), scl=Pin(15), freq=100000)   # claim I2C1 pins

# Force internal pull-ups on GP14/GP15 (no external resistors for bench test)
_PADS = 0x4001C000
for _gp in (14, 15):
    _r = _PADS + 0x04 + _gp * 4
    mem32[_r] = (mem32[_r] | (1 << 3)) & ~(1 << 2)

# Configure RP2040 I2C1 as a SLAVE at SENSOR_ADDR
mem32[I2C1_BASE + 0x6C] = 0
mem32[I2C1_BASE + 0x00] = 0x22
mem32[I2C1_BASE + 0x08] = SENSOR_ADDR
mem32[I2C1_BASE + 0x6C] = 1

def flush():
    _ = mem32[I2C1_BASE + 0x40]        # CLR_INTR
    _ = mem32[I2C1_BASE + 0x50]        # CLR_RD_REQ
    _ = mem32[I2C1_BASE + 0x54]        # CLR_TX_ABRT
    _ = mem32[I2C1_BASE + 0x60]        # CLR_STOP_DET

while mem32[I2C1_BASE + 0x78] > 0:     # drain RX FIFO
    _ = mem32[I2C1_BASE + 0x10]

_tx = bytearray(1)
_rx = bytearray(1)

def spi_write(b):
    _tx[0] = b
    cs.value(0); spi.write(_tx); cs.value(1)

def spi_read():
    _tx[0] = 0x00
    cs.value(0); spi.write_readinto(_tx, _rx); cs.value(1)
    return _rx[0]

vectors = [0x00, 0xFF, 0x55, 0xAA, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]
vectors += [random.randint(0, 255) for _ in range(20)]

passes = 0
total = 0

print("=== SPI <-> I2C self-test (FPGA SPI slave + I2C master; RP2040 = SPI master + I2C slave) ===\n")

for v in vectors:
    total += 1
    reply = (v + 0x05) & 0xFF
    flush()

    spi_write(v)                        # command -> FPGA -> I2C write to slave

    # 1) capture the FPGA's I2C write
    t0 = time.ticks_ms(); got_w = None
    while time.ticks_diff(time.ticks_ms(), t0) < 60:
        if mem32[I2C1_BASE + 0x78] > 0:               # RXFLR
            got_w = mem32[I2C1_BASE + 0x10] & 0xFF
            break
    if got_w is None:
        print("  timeout: no I2C write for 0x%02X" % v)
        continue

    # 2) service the FPGA's I2C read with reply = X + 0x05
    t0 = time.ticks_ms(); served = False
    while time.ticks_diff(time.ticks_ms(), t0) < 60:
        if mem32[I2C1_BASE + 0x34] & (1 << 5):        # RD_REQ
            mem32[I2C1_BASE + 0x10] = reply
            _ = mem32[I2C1_BASE + 0x50]               # CLR_RD_REQ
            served = True
            break
    if not served:
        print("  timeout: no I2C read request for 0x%02X" % v)
        continue

    time.sleep_ms(5)                    # let the FPGA finish the read + load SPI TX
    got = spi_read()                    # read-back

    if got == reply:
        passes += 1
    else:
        print("  FAIL  sent 0x%02X  exp 0x%02X  got 0x%02X" % (v, reply, got))

print("\nPassed %d / %d" % (passes, total))
print("STATUS: SUCCESS" if passes == total else "STATUS: FAILURE")
