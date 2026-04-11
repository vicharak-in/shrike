# ws2812_led_controller

**Difficulty:** Intermediate

**Uses MCU:** No

**External Hardware:** WS2812 / WS2811 LED Strip

## Overview

This example demonstrates driving a WS2812/WS2811 LED strip directly from the FPGA on the Shrike board without any MCU involvement.

The FPGA generates RGB values internally and transmits them using the precise timing required by the WS2811 protocol. A hardware driver module handles the bit-level waveform generation, enabling smooth color transitions across multiple LEDs.

## Compatibility

| Board                | Firmware                | Status      |
| -------------------- | ----------------------- | --------    |
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` | ✅ Tested   |
| Shrike (RP2350)      | `firmware/arduino-ide/` | ✅ Tested   |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

### Required Components

* WS2812 / WS2811 LED strip
* Power supply (as required by LED strip)

### Connections

| Signal | Description              |
| ------ | ------------------------ |
| `DO`   | Data output to LED strip |
| `GND`  | Common ground            |
| `VCC`  | LED power supply         |

> Ensure common ground between FPGA and LED strip.

---

## Quick Start (Pre-Built Bitstream)

1. Connect the LED strip data line to FPGA output (`DO`)
2. Power the LED strip
3. Upload `bitstream/ws2812_led_controller.bin` using ShrikeFlash
4. Expected result: LEDs display continuously changing RGB colors

---

## Build From Source

### FPGA (Verilog)

1. Open `ws2812_led_controller.ffpga` in Go Configure Software Hub
2. Paste the provided Verilog (`wstest` + `ws2811` modules)
3. Configure I/O mapping
4. Generate bitstream

### Firmware

No firmware required for this example.

---

## How It Works

The design consists of two main modules:

### 1. `wstest` (Top Module)

* Generates dynamic RGB values using a counter
* Feeds color data into the WS2811 driver
* Controls multiple LEDs (`NUM_LEDS = 6`)

```verilog id="ws1"
assign red   = count[25:18];
assign green = count[28:21];
assign blue  = count[31:24];
```

* This creates smooth color transitions over time

---

### 2. `ws2811` Driver Module

This module implements the WS2811 protocol, which requires strict timing.

Key responsibilities:

* Serialize RGB data
* Generate correct pulse widths for logic `0` and `1`
* Handle LED chaining
* Generate reset pulse

---

## Protocol Details

* Data rate: **800 kHz**
* Each bit is transmitted within a fixed cycle

### Timing Rules

* Logic `1` → ~50% duty cycle
* Logic `0` → ~20% duty cycle

```verilog id="ws2"
localparam integer CYCLE_COUNT    = SYSTEM_CLOCK / 800000;
localparam integer H0_CYCLE_COUNT = 0.32 * CYCLE_COUNT;
localparam integer H1_CYCLE_COUNT = 0.64 * CYCLE_COUNT;
```

---

### Reset Condition

* Line held LOW for **≥ 50 µs** resets LED chain

```verilog id="ws3"
localparam integer RESET_COUNT = 100 * CYCLE_COUNT;
```

---

## Internal Operation

The driver uses an FSM:

| State    | Function               |
| -------- | ---------------------- |
| RESET    | Reset pulse generation |
| LATCH    | Load RGB values        |
| PRE      | Start bit transmission |
| TRANSMIT | Generate waveform      |
| POST     | Advance bit / color    |

### Color Order

WS2811 expects:

```
Green → Red → Blue
```

---

## Expected Output

* LEDs continuously change colors
* Smooth RGB transitions across all LEDs
* Multiple LEDs update sequentially (chained protocol)

---

## Notes

* Timing is critical — depends on correct `SYSTEM_CLOCK` value

* Default configuration:

  * `NUM_LEDS = 6`
  * `SYSTEM_CLOCK = 50 MHz`

* Fully hardware-driven LED control (no MCU needed)

* Reference implementation based on WS2811 protocol driver 
