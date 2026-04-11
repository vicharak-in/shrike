# led_blink

**Difficulty:** Beginner

**Uses MCU:** No

**External Hardware:** None

## Overview

This example demonstrates a basic LED blinking pattern implemented entirely in FPGA logic. The LED connected to the FPGA toggles at a fixed interval, showing how to generate time-based signals using counters and clock division in Verilog.

## Compatibility

| Board                |Status   |
| -------------------- |-------- |
| Shrike-Lite (RP2040) |✅ Tested |
| Shrike (RP2350)      |✅ Tested |
| Shrike-fi (ESP32-S3) |✅ Tested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

The example uses the onboard LED connected to **GPIO 16** of the FPGA.

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Upload `bitstream/led_blink.bin` using ShrikeFlash
3. Expected result: The LED on GPIO 16 blinks continuously at a fixed rate

## Build From Source

### FPGA (Verilog)

1. Open `led_blink.ffpga` in Go Configure Software Hub
2. Click **Synthesize → Generate Bitstream**
3. Output will be in `ffpga/build/`

### Firmware

No firmware required for this example.

## How It Works

The FPGA uses a counter driven by the system clock to create a time delay. When the counter reaches a predefined value, it toggles the LED state.

This effectively divides the high-frequency clock into a slower signal that is visible to the human eye as a blinking LED.

## Expected Output

* LED on GPIO 16 turns ON and OFF periodically
* The blinking is continuous and stable
* The blink rate depends on the clock divider value used in the design
