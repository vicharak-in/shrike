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

# The phrase adds keystroke timing as extra entropy.
user_seed = input("\nType a phrase and press ENTER: ")

fpga_ss.value(0)
for char in user_seed:
    # Any byte that is NOT 0xA1 drops directly into the FPGA's seed trapdoor
    spi_fpga.write(char.encode('utf-8'))
    time.sleep_us(10) 
fpga_ss.value(1)


def generate_password(length=16):
    buf = bytearray(length)
    fpga_ss.value(0)

    for i in range(length):
        spi_fpga.write(b'\xA1')          # Ask the FPGA for a byte
        raw_byte = spi_fpga.read(1)[0]
        buf[i] = 33 + (raw_byte % 94)    # Map to a printable ASCII char

    fpga_ss.value(1)
    return buf.decode()


print("Generating password...")
time.sleep_ms(200)
print(f"\nYour password:\n>>  {generate_password(16)}  <<\n")
