# uart_led

**Difficulty:** Beginner
**Uses MCU:** Yes
**External Hardware:** None

## Overview

This example demonstrates controlling an LED on the FPGA using UART communication from the MCU. You will learn how to implement a basic UART receiver in Verilog and use serial data to control hardware outputs in real time.

## Compatibility

| Board                | Firmware                | Status         |
| -------------------- | ----------------------- | -------------  |
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` | ✅ Tested      |
| Shrike (RP2350)      | `firmware/arduino-ide/` | ✅ Tested      |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ❌ Not Tested  |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

UART communication occurs between the MCU and FPGA internally. The FPGA drives an onboard LED based on received UART data.

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Upload `bitstream/uart_led.bin` using ShrikeFlash
3. Run the MicroPython script
4. Open the serial console and type:

   * `on` → LED turns ON
   * `off` → LED turns OFF

## Build From Source

### FPGA (Verilog)

1. Open `uart_led.ffpga` in Go Configure Software Hub
2. Click **Synthesize → Generate Bitstream**
3. Output will be in `ffpga/build/`

### Firmware 

1. Open your script in Thonny
2. Select MicroPython interpreter (RP2040)
3. Run the script

## How It Works

The FPGA implements a UART receiver that listens for serial data from the MCU.

The MicroPython script sends specific command bytes:

* `0xAB` → Turn LED ON
* `0xFF` → Turn LED OFF

Based on the received byte, the FPGA updates the LED state.

UART is configured as:

* UART0
* TX = GPIO0
* RX = GPIO1
* Baudrate = 115200

This demonstrates a simple command-based communication protocol between MCU and FPGA.

## Expected Output

In the serial console:

```
Type 'on' or 'off':
```

* Typing `on` → sends `0xAB` → LED turns ON
* Typing `off` → sends `0xFF` → LED turns OFF

Console output:

```
LED on
LED off
```

The LED responds immediately to the command sent over UART.
