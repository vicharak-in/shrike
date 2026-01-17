"""
This code pushes 2 numbers in stack of FPGA, multiply them on FPGA
and get back the result over SPI.
"""

from machine import Pin, SPI
import time

# Reset
reset_pin = Pin(14, Pin.OUT, value=1)
reset_pin.value(0)
time.sleep(1)
reset_pin.value(1)
time.sleep(1)

# RP2040
SCK  = 2  
CS   = 1  
MOSI = 3  
MISO = 0  

# Chip Select pin
cs = Pin(CS, Pin.OUT, value=1)

# SPI configuration (MODE 0, MSB first)
spi = SPI(0,
          baudrate=1_000_000,
          polarity=0,
          phase=0,
          bits=8,
          firstbit=SPI.MSB,
          sck=Pin(SCK),
          mosi=Pin(MOSI),
          miso=Pin(MISO))

def spi_exchange(byte_to_send):
    tx = bytes([byte_to_send])
    rx = bytearray(1)

    cs.value(0)          # Select FPGA
    spi.write_readinto(tx, rx)
    cs.value(1)          # Deselect FPGA

    return rx[0]



mul = [0x12, # Push 2
       0x15, # Push 5
       0x33, # Pop A (A = 5)
       0x34, # Pop B (A = 2)
       0xC2, # C = A * B (C = 5 * 2)
       0x32, # Push C
       0x20, # Pop
       0x00, # Stall
       ]

while True:    
    for val in mul:
        resp = spi_exchange(val)
        print(f"Sent 0x{val:02X}, Received 0x{resp:02X}")
        time.sleep(0.01)
        
    break