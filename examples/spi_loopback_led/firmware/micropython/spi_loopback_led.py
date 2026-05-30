import sys
import shrike
from machine import Pin, SPI
import time


#Flash the bitstream into the FPGA ic
shrike.flash("spi_loopback_led.bin")

# --- 1. Platform-Specific Pin Routing ---
if sys.platform == 'rp2':
    # Shrike Lite (RP2040)
    SPI_ID = 0
    SCK_PIN = 2
    MOSI_PIN = 3
    MISO_PIN = 0
    CS_PIN = 1

elif sys.platform == 'esp32':
    # Shrike FI (ESP32)
    SPI_ID = 2
    SCK_PIN = 12
    MOSI_PIN = 11
    MISO_PIN = 13
    CS_PIN = 10

else:
    raise RuntimeError("Unsupported platform!")

# --- 2. Shared Hardware Reset ---
# Both platforms use Pin 14 for reset in this loopback test
reset_pin = Pin(14, Pin.OUT, value=1)
reset_pin.value(0)
time.sleep(1)
reset_pin.value(1)
time.sleep(1)

# --- 3. Shared SPI Initialization ---
cs = Pin(CS_PIN, Pin.OUT, value=1)

spi = SPI(SPI_ID,
          baudrate=1_000_000,
          polarity=0,
          phase=0,
          bits=8,
          firstbit=SPI.MSB,
          sck=Pin(SCK_PIN),
          mosi=Pin(MOSI_PIN),
          miso=Pin(MISO_PIN))

# --- 4. Loopback Function ---
def spi_exchange(byte_to_send):
    tx = bytes([byte_to_send])
    rx = bytearray(1)

    cs.value(0)          # Select FPGA
    spi.write_readinto(tx, rx)
    cs.value(1)          # Deselect FPGA

    return rx[0]

# --- 5. Main Execution Loop ---
print(f"Starting SPI Loopback on {sys.platform}...")

while True:
    for val in [0xAB, 0xFF]:
        resp = spi_exchange(val)
        print(f"Sent 0x{val:02X}, Received 0x{resp:02X}")
        time.sleep(1)
