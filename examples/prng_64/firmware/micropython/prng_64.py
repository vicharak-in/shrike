import machine
import time
import shrike
from machine import Pin, SPI

print("Flashing FPGA bitstream...")
shrike.flash("prng_64.bin")
print("Flash complete.")

# Power up the FPGA fabric
Pin(12, Pin.OUT, value=1)
Pin(13, Pin.OUT, value=1)
time.sleep_ms(50)

# SPI setup
fpga_ss  = Pin(1, Pin.OUT, value=1)
spi_fpga = SPI(0, baudrate=5000000, polarity=0, phase=0, sck=Pin(2), mosi=Pin(3), miso=Pin(0))

print("\nFPGA is running and ready.")

# The phrase just adds keystroke timing as extra entropy.
# The FPGA mixes it into its state as you type.
user_seed = input("\nType a phrase and press ENTER: ")


def generate_password(length=16):
    buf = bytearray(length)
    fpga_ss.value(0)

    for i in range(length):
        spi_fpga.write(b'\xA1')          # ask the FPGA for a byte
        raw_byte = spi_fpga.read(1)[0]
        buf[i] = 33 + (raw_byte % 94)    # map to a printable ASCII char

    fpga_ss.value(1)
    return buf.decode()


print("\nGenerating password...")
time.sleep_ms(200)
print(f"\nYour password:\n>>  {generate_password(16)}  <<\n")
