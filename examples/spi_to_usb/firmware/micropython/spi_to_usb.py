# read_arduino.py -- RP2040 firmware to read bytes sent by the Arduino master.
#
# Run this in Thonny (MicroPython interpreter on the Shrike board). It flashes
# the FPGA bitstream, then polls the FPGA over SPI every 200 ms by sending a
# dummy byte. The FPGA returns the last byte it received from the Arduino.
#
# The script prints a live table showing what the Arduino is sending so you can
# verify the full data path: Arduino -> FPGA -> RP2040.

from machine import SPI, Pin
import shrike
import time

# Platform configuration (Shrike-Lite / RP2040).
CONFIG = {
    "bitstream": "spi_to_usb.bin",
    "baudrate": 1_000_000,
    "sck": 2,
    "mosi": 3,
    "miso": 0,
    "cs": 1,
}

# Flash the FPGA bitstream.
shrike.flash(CONFIG["bitstream"])
time.sleep(0.5)

# Set up SPI on the RP2040 -> FPGA fixed link.
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


def spi_read():
    """Send a dummy byte to the FPGA and return the Arduino's last byte."""
    rx = bytearray(1)
    cs(0)
    spi.write_readinto(bytes([0x00]), rx)
    cs(1)
    return rx[0]


# Print header.
print()
print("=== Reading bytes from Arduino via FPGA ===")
print()
print("  #  | Arduino Byte")
print("  ---|-------------")

count = 0
prev = None

while True:
    byte = spi_read()

    # Only print when the value changes (avoids flooding the terminal).
    if byte != prev:
        count += 1
        print("  {:>3d} |  0x{:02X}".format(count, byte))
        prev = byte

    time.sleep(0.2)