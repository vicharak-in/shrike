# Engineer - Deepak Sharda deepak.sharda@vicharak.in dshardan007@gmail.com

from machine import Pin, I2C
import time

# Configure I2C (SDA = GP0, SCL = GP1)
i2c = I2C(0, scl=Pin(1), sda=Pin(0), freq=100_000)

# Slave device I2C address (7-bit)
SLAVE_ADDR = 0x32  

def write_byte(addr, value):
    """
    Write a single 8-bit value to an I2C slave.
    """
    i2c.writeto(addr, bytes([value]))

print("Type 'on' to send 0xAA or 'off' to send 0xFF")

while True:
    cmd = input("Enter command (on/off): ").strip().lower()
    if cmd == "on":
        write_byte(SLAVE_ADDR, 0xAA)
        print("Sent 0xAA (LED ON)")
    elif cmd == "off":
        write_byte(SLAVE_ADDR, 0xFF)
        print("Sent 0xFF (LED OFF)")
    else:
        print("Invalid command, type 'on' or 'off'")
    time.sleep(0.1)
