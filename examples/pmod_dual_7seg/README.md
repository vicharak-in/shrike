# pmod_dual_7seg

**Difficulty:** Intermediate

**Uses MCU:** No

**External Hardware:** PMOD 7-Segment Display (common-anode)

## Overview

This example demonstrates driving a dual 7-segment PMOD display using FPGA logic with an FSM-based counter design. The FPGA generates a **00–99 counter** with a 1-second heartbeat, using time-multiplexing to drive both digits from shared segment lines. You will learn how to build a finite state machine, implement digit multiplexing, and interface a PMOD 7-segment display with the Shrike board.

## Compatibility

| Board                | Status   |
| -------------------- | -------- |
| Shrike-Lite (RP2040) | ✅ Tested |
| Shrike (RP2350)      | ✅ Tested |
| Shrike-fi (ESP32-S3) | ✅ Tested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

### Required Components

* **PMOD 7-Segment Display** (dual-digit, common-anode)

### Connection Notes

* Connect the PMOD 7-segment display to the FPGA PMOD header (3.3V, GND, F8–F15)
* Ensure correct orientation and pin alignment
* This example is designed for **common-anode** displays (`SEL_CA = 1`)

### Signal Mapping

| Signal | Function |
|--------|----------|
| `out_a` – `out_g` | Segment A–G outputs |
| `active_digit` | Digit select (time-multiplexed) |
| `out_*_oe` | Output enable (all tied high) |
| `active_digit_oe` | Digit select output enable |
| `nreset` | Active-low reset (pin chip_x=31, chip_y=12) |

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Attach the PMOD 7-segment display
3. Upload `bitstream/pmod_dual_7seg.bin` using ShrikeFlash
4. Expected result: Display shows a counter incrementing from `00` to `99` every second

## Build From Source

### FPGA (Verilog)

1. Open `pmod_dual_7seg.ffpga` in Go Configure Software Hub
2. Click **Synthesize → Generate Bitstream**
3. Output will be in `ffpga/build/`

### Firmware

No firmware required for this example.

## How It Works

The design is composed of four modules working together:

* **Clock Source**

  * `clk` = 50 MHz system clock (from onboard oscillator)

* **1 Hz Tick Generator** (`counter_1s`)

  * Converts the 50 MHz system clock into a 1 Hz `tick` signal

* **FSM Counter** (`timer_FSM`)

  * A 3-state FSM (IDLE → SEC_COUNT → DEC_SEC_COUNT) that produces a 2-digit BCD value (00–99)
  * `sec_count` (tens digit) increments every 10 ticks
  * `dec_sec_count` (ones digit) increments every tick
  * Resets after reaching `99`

* **Dynamic Indication** (`dynamic_indication`)

  * Generates a high-frequency refresh clock (`refresh_clock`) for digit multiplexing

* **7-Segment Display Driver** (`seven_segment_disp`)

  * Latches the counter value on each `tick`
  * Decodes BCD to 7-segment outputs
  * Time-multiplexes between the two digits using `active_digit`

### Key Concept: Time Multiplexing

* Only one digit is active at a time
* The FPGA rapidly alternates between digits at a high refresh rate
* The human eye perceives both digits as continuously lit

## Expected Output

* Display shows values from `00` to `99`
* Increments once per second
* Both digits appear continuously ON due to multiplexing
* After `99`, the counter resets to `00`

## Notes

* `nreset` is active-low reset
* The design uses **common-anode** 7-segment displays only (`SEL_CA = 1`)
* To use a common-cathode display, change `SEL_CA` to `0` in the `seven_segment_disp` instantiation
