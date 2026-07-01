# usb_to_spi.py -- RP2040 firmware for the USB-to-SPI bridge (run with Thonny).
#
# Acts as the SPI master on the fixed RP2040 <-> FPGA link. It reads one byte at
# a time from the USB serial port and forwards it to the FPGA over SPI; the FPGA
# returns the external slave's reply (one transfer behind) which is written back
# to USB. Flashes the FPGA bitstream on start via the shrike helper.
#
# Pin config is kept in CONFIG below so it can be adjusted per board variant.

import sys
from machine import SPI, Pin
import shrike

# Platform configuration (Shrike-Lite / RP2040).
CONFIG = {
    "bitstream": "usb_to_spi.bin",
    "baudrate": 1_000_000,
    "sck": 2,
    "mosi": 3,
    "miso": 0,
    "cs": 1,
}

shrike.flash(CONFIG["bitstream"])

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


def spi_transfer(value):
    """Send one byte to the FPGA and return the byte shifted back."""
    rx = bytearray(1)
    cs(0)
    spi.write_readinto(bytes([value]), rx)
    cs(1)
    return rx[0]


# Bridge loop: USB byte in -> SPI -> USB byte out.
while True:
    raw = sys.stdin.buffer.read(1)
    if raw:
        reply = spi_transfer(raw[0])
        sys.stdout.buffer.write(bytes([reply]))
