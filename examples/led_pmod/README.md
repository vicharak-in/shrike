# pmod_led_controller

**Difficulty:** Beginner

**Uses MCU:** No

**External Hardware:** LED PMOD (8-bit)

## Overview

This example demonstrates driving an external LED PMOD using FPGA logic. The FPGA generates a blinking pattern on all 8 PMOD pins using a simple counter-based clock divider. You will learn how to interface external peripherals and control multiple outputs in parallel from FPGA.

## Compatibility

| Board                | Status   |
| -------------------- | -------- |
| Shrike-Lite (RP2040) | ✅ Tested |
| Shrike (RP2350)      | ✅ Tested |
| Shrike-fi (ESP32-S3) | ✅ Tested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

An **8-bit LED PMOD** is required.

* Connect the PMOD to the FPGA PMOD header
* Ensure correct orientation and pin alignment

The FPGA drives all 8 PMOD pins through:

* `led_pmod[7:0]` → LED outputs
* `led_en[7:0]` → Output enable (always enabled)

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Attach the LED PMOD module
3. Upload `bitstream/pmod_led_controller.bin` using ShrikeFlash
4. Expected result: All LEDs on the PMOD toggle ON and OFF together

## Build From Source

### FPGA (Verilog)

1. Open `pmod_led_controller.ffpga` in Go Configure Software Hub
2. Paste the provided Verilog into `main.v`
3. Click **Synthesize → Generate Bitstream**
4. Output will be in `ffpga/build/`

### Firmware

No firmware required for this example.

## How It Works

The FPGA uses a 32-bit counter driven by the system clock:

* The counter increments on every clock cycle
* When it reaches `50,000,000`, it toggles the LED state
* The counter resets and repeats

This creates a visible blinking pattern.

### Key Signals

* `led_pmod[7:0]` → drives external LEDs
* `led_en[7:0] = 8'b11111111` → enables all outputs
* `clk_en = 1'b1` → enables internal oscillator

### Verilog Snippet

```verilog id="y3l8kp"
always @ (posedge clk) begin
  counter <= counter + 1'b1;
  if (counter == 50_000_000) begin
    led <= ~led;
    counter <= 32'b0;
  end
end

assign led_pmod = led;
```

## Expected Output

* All 8 LEDs on the PMOD turn ON and OFF simultaneously
* Blinking is periodic and stable
* Blink rate is determined by the counter threshold (50 MHz clock assumed)
