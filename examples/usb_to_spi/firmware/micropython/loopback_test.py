# loopback_test.py -- RP2040 self-test for the USB-to-SPI bridge (run on Thonny).
#
# Standalone check that does not need the PC host script. Jumper FPGA m_mosi
# (GPIO1) to m_miso (GPIO8) so the FPGA master loops its own output back. Each
# byte sent should read back on the *next* transfer (the bridge is one transfer
# behind), so a trailing dummy byte flushes the last reply. Prints OK/MANGLED
# per byte so you can confirm the FPGA is mastering the external SPI bus.

from machine import SPI, Pin
import shrike
import time

# Platform configuration (Shrike-Lite / RP2040).
CONFIG = {
    "bitstream": "usb_to_spi.bin",
    "baudrate": 1_000_000,
    "sck": 2,
    "mosi": 3,
    "miso": 0,
    "cs": 1,
    "test_bytes": [0xBB, 0xCD, 0xEF, 0x42, 0x00],
}

shrike.flash(CONFIG["bitstream"])
time.sleep(0.5)

spi = SPI(
    0,
    baudrate=CONFIG["baudrate"],
    polarity=0,
    phase=0,
    bits=8,
    firstbit=SPI.MSB,
    sck=Pin(CONFIG["sck"]),
    mosi=Pin(CONFIG["mosi"]),
    miso=Pin(CONFIG["miso"]),
)
cs = Pin(CONFIG["cs"], Pin.OUT, value=1)


def xfer(value):
    """Send one byte and return the byte shifted back from the FPGA."""
    rx = bytearray(1)
    cs(0)
    spi.write_readinto(bytes([value]), rx)
    cs(1)
    return rx[0]


prev = None
for b in CONFIG["test_bytes"]:
    r = xfer(b)
    if prev is not None:
        status = "OK" if r == prev else "MANGLED"
        print("sent 0x%02X -> read 0x%02X  %s" % (prev, r, status))
    prev = b
