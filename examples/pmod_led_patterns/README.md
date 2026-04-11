# pmod_pattern_generator

**Difficulty:** Beginner

**Uses MCU:** No

**External Hardware:** LED PMOD (8-bit)

## Overview

This example demonstrates multiple LED patterns on an external LED PMOD driven entirely by FPGA logic. The design cycles through different visual patterns such as shifting, bouncing, snake effect, and breathing patterns using counters and state machines.

You will learn how to implement pattern generators, timing control, and simple state machines in FPGA.

## Compatibility

| Board                | Status   |
| -------------------- | -------- |
| Shrike-Lite (RP2040) | ✅ Tested |
| Shrike (RP2350)      | ✅ Tested |
| Shrike-fi (ESP32-S3) | ✅ Tested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

An **8-bit LED PMOD** is required.

* Connect the LED PMOD to the FPGA PMOD header
* Ensure correct orientation

Signals:

* `led_pmod[7:0]` → LED outputs
* `led_en[7:0] = 8'b11111111` → enables all outputs

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Attach the LED PMOD
3. Upload `bitstream/pmod_pattern_generator.bin` using ShrikeFlash
4. Expected result: LED patterns automatically cycle on the PMOD

## Build From Source

### FPGA (Verilog)

1. Open `pmod_pattern_generator.ffpga` in Go Configure Software Hub
2. Paste the provided Verilog into `main.v`
3. Click **Synthesize → Generate Bitstream**
4. Output will be in `ffpga/build/`

### Firmware

No firmware required for this example.

## How It Works

The FPGA uses:

* A **counter** for timing
* A **pattern timer** to switch between patterns
* A **state machine (`pattern_select`)** to select active pattern

### Pattern Switching

* Pattern changes every ~1.5 seconds
* Controlled by `pattern_timer`

```verilog id="p1w9sx"
if (pattern_timer >= 75_000_000) begin
  pattern_timer <= 0;
  pattern_select <= pattern_select + 1;
end
```

---

## Implemented Patterns

### Pattern 0 — Blink All LEDs

* Toggles all LEDs ON/OFF

### Pattern 1 — Left Shift

* LEDs shift from LSB → MSB

### Pattern 2 — Right Shift

* LEDs shift from MSB → LSB

### Pattern 3 — Alternating Pattern

* Alternates between:

  * `10101010`
  * `01010101`

### Pattern 4 — Fill from Edges

* LEDs fill inward:

  ```
  10000001 → 11000011 → 11100111 → 11111111
  ```

### Pattern 5 — Snake Effect

* Growing pattern:

  ```
  00000001 → 00000011 → ... → 11111111 → reset
  ```

### Pattern 6 — Bounce (Ping-Pong)

* Single LED moves left ↔ right

### Pattern 7 — Breathing Effect (Fake PWM)

* Gradual fill/unfill:

  ```
  00000000 → 00000001 → 00000011 → ... → 11111111 → reverse
  ```

---

## Key Logic Snippet

```verilog id="z9l2rm"
case (pattern_select)
  3'd0: led <= ~led;
  3'd1: led <= (led == 0) ? 8'b00000001 : led << 1;
  3'd2: led <= (led == 0) ? 8'b10000000 : led >> 1;
  ...
endcase
```

---

## Expected Output

* LED PMOD continuously cycles through 8 patterns
* Each pattern runs for ~1.5 seconds
* Transitions are smooth and periodic

---

## Notes

* Uses 50 MHz clock assumption for timing
* Pattern speed can be adjusted via counter thresholds
* Demonstrates multiple design techniques:

  * Counters
  * State machines
  * Bit manipulation
