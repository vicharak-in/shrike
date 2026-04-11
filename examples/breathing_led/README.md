# breathing_led

**Difficulty:** Beginner  

**Uses MCU:** No  

**External Hardware:** None  

## Overview

This example demonstrates a smooth "breathing" LED effect using pure FPGA logic. The LED brightness gradually increases and decreases, creating a fade-in/fade-out pattern. You will learn how to implement PWM and simple counters to generate time-based visual effects on hardware.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `None` | ✅ Tested |
| Shrike (RP2350) | `None` | ✅ Tested |
| Shrike-fi (ESP32-S3) | `None` | ✅ Tested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

The example uses the onboard LED connected to **GPIO 16** of the FPGA.

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB  
2. Upload `bitstream/breathing_led.bin` using ShrikeFlash  
3. Expected result: The onboard LED on GPIO 16 will smoothly fade in and out continuously  

## Build From Source

### FPGA (Verilog)
1. Open `led_breathing.ffpga` in Go Configure Software Hub  
2. Click **Synthesize → Generate Bitstream**  
3. Output will be in `ffpga/build/`  

### Firmware

No firmware required for this example.

## How It Works

The breathing effect is implemented using a PWM (Pulse Width Modulation) signal whose duty cycle is gradually increased and decreased over time.

- A counter generates a slow ramp signal  
- This ramp controls the PWM duty cycle  
- As the duty cycle increases, LED brightness increases  
- As it decreases, the LED fades out  

This creates a smooth visual breathing effect without requiring any CPU or firmware interaction.

## Expected Output

The LED connected to GPIO 16 will:
- Gradually increase in brightness (fade in)  
- Reach maximum brightness  
- Gradually decrease in brightness (fade out)  
- Repeat this cycle continuously  

The transition should appear smooth and periodic, similar to a "breathing" pattern.
