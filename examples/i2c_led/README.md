# i2c_led

**Difficulty:** Beginner

**Uses MCU:** Yes

**External Hardware:** None

## Overview

This example demonstrates controlling an LED on the FPGA using I2C communication from the MCU. You will learn how to implement a simple I2C slave interface in FPGA and use it to control hardware outputs using byte-level commands.

## Compatibility

| Board                | Firmware                | Status        |
| -------------------- | ----------------------- | ------------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested      |
| Shrike (RP2350)      | `firmware/micropython/` | ✅ Tested      |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` |   Not Tested   |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

### I2C Configuration

* SDA → GPIO0
* SCL → GPIO1
* Frequency → 100 kHz
* Slave Address → `0x32`

### Control Signal

* Reset Pin → GPIO3 (Active Low)

> Reset must be HIGH for normal operation.

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Upload `bitstream/i2c_led.bin` using ShrikeFlash
3. Run the MicroPython script
4. In the console, type:

   * `on` → LED turns ON
   * `off` → LED turns OFF

## Build From Source

### FPGA (Verilog)

1. Open `i2c_led.ffpga` in Go Configure Software Hub
2. Click **Synthesize → Generate Bitstream**
3. Output will be in `ffpga/build/`

### Firmware 

1. Open the script in Thonny
2. Select MicroPython (RP2040) interpreter
3. Run the script

## How It Works

The FPGA implements an I2C slave that listens on address `0x32`. When the MCU sends a byte, the FPGA decodes the value and updates the LED state accordingly.

The MicroPython firmware:

* Initializes I2C on GPIO0 (SDA) and GPIO1 (SCL)
* Sends command bytes to the FPGA
* Uses a reset pin to control FPGA reset state

### Command Protocol

* `0xAA` → LED ON
* `0xFF` → LED OFF

### Firmware Snippet

```python id="q1x8pl"
from machine import Pin, I2C
import time

reset = Pin(3, Pin.OUT)
reset.high()

i2c = I2C(0, scl=Pin(1), sda=Pin(0), freq=100_000)
SLAVE_ADDR = 0x32  

def write_byte(addr, value):
    i2c.writeto(addr, bytes([value]))
```

## Expected Output

Console interaction:

```text id="7v0m3r"
Enter command (on/off):
```

* Typing `on` → sends `0xAA` → LED turns ON
* Typing `off` → sends `0xFF` → LED turns OFF

Console output:

```text id="m3c9dj"
Sent 0xAA (LED ON)
Sent 0xFF (LED OFF)
```

The LED responds immediately to I2C commands.
