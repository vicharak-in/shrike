# shrike_flash.py
# Engineer - Deepak Sharda - dshardan007@gmail.com

import machine
import utime
import binascii

# Pin definitions
EN  = machine.Pin(13, machine.Pin.OUT)   # Enable FPGA
PWR = machine.Pin(12, machine.Pin.OUT)   # Power to FPGA

# SPI configuration
SPI = machine.SPI(0,
                  baudrate=1600000,
                  polarity=0,
                  phase=0,
                  bits=8,
                  firstbit=machine.SPI.MSB,
                  sck=machine.Pin(2),
                  mosi=machine.Pin(3),
                  miso=machine.Pin(0))

def flash(filename: str, word_size=46408):
    """
    Flash the given bitstream file to the FPGA over SPI.

    Args:
        filename (str): Path to the binary bitstream file.
        word_size (int): Number of bytes to send at once (default: 4).
    """
    SS  = machine.Pin(1, machine.Pin.OUT)    # Slave Select

    print("[shrike_flash] Starting FPGA flash...")
    utime.sleep(0.01)

    # Reset and power-up FPGA
    SS.value(0)
    EN.value(0)
    PWR.value(0)
    utime.sleep(0.1)
    EN.value(1)
    PWR.value(1)
    utime.sleep(0.1)

    # Start SPI transfer
    SS.value(1)
    utime.sleep(0.002)
    SS.value(0)

    # Send the bitstream
    try:
        with open(filename, 'rb') as f:
            while True:
                word = f.read(word_size)
                if not word:
                    break
                SPI.write(word)
    except OSError as e:
        print(f"[shrike_flash] File error: {e}")
    except Exception as e:
        print(f"[shrike_flash] Error: {e}")

    SS.value(1)
    utime.sleep(0.1)
    print("[shrike_flash] FPGA programming done.")
    
def reset():
    """
    Reset the FPGA by pulling PWR low.
    """
    PWR.value(0)
    print("[shrike_flash] FPGA reset done ")
