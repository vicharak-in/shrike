# pll_oscillator

**Difficulty:** Intermediate

**Uses MCU:** No

**External Hardware:** Optional (External Clock Source, Logic Analyzer)

## Overview

This project implements the Renesas application note **"How to Drive PLL from Oscillator"** using the same SLG47910 FPGA found on Shrike-Lite. The design demonstrates selecting the PLL input clock source, using bypass mode, and adjusting PLL frequency parameters dynamically. 

It also includes a simple 4-bit counter driven by the PLL clock output, allowing real-time frequency observation on output pins.

## Compatibility

| Board                | Status     |
| -------------------- | ---------- |
| Shrike-Lite (RP2040) | ✅ Tested   |
| Shrike (RP2350)      | ✅ Tested   |
| Shrike-fi (ESP32-S3) | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required for basic operation.

Optional:

* External clock source connected to GPIO2
* Logic analyzer to observe counter outputs

## Quick Start (Pre-Built Bitstream)

1. Load the FPGA bitstream using ForgeFPGA toolchain
2. Observe counter outputs on FPGA pins
3. Toggle control signals:

   * `SEL` → select clock source
   * `BYP` → enable/disable PLL
4. Expected result: Counter frequency changes based on PLL configuration

## Build From Source

### FPGA (Verilog)

1. Open project in Go Configure Software Hub
2. Configure PLL parameters and I/O mapping
3. Generate bitstream

### Firmware

No firmware required for this example.

## How It Works

The design demonstrates PLL configuration and clock routing inside the FPGA.

### Function Summary

| Feature                                                   | Status |
| --------------------------------------------------------- | ------ |
| PLL driven from internal 50MHz oscillator                 | ✔      |
| PLL driven from external clock (GPIO2)                    | ✔      |
| Bypass mode support                                       | ✔      |
| Live frequency scaling via REFDIV/FBDIV/POSTDIV1/POSTDIV2 | ✔      |
| 4-bit counter running off PLL output                      | ✔      |

Operation matches the Renesas reference implementation.

### Clock Source Selection

| SEL | PLL Reference Source         |
| --- | ---------------------------- |
| 0   | Internal 50 MHz OSC          |
| 1   | External clock through GPIO2 |

### Signal Description

| Signal          | Purpose                          |
| --------------- | -------------------------------- |
| SEL (GPIO0)     | Clock select — internal/external |
| BYP (GPIO1)     | Bypass PLL direct-through clock  |
| EXT_CLK (GPIO2) | External reference input         |
| PLL_CLK         | PLL output used as system clock  |
| COUNTER[3:0]    | Visual frequency check output    |

* When `BYP = 1` → PLL output = reference clock
* When `BYP = 0` → PLL output is scaled using divider/multiplier

---

## PLL Frequency Equation

From Renesas documentation:

```text
FOUT = FREFF × (FBDIV / (REFDIV × POSTDIV1 × POSTDIV2))
```

Where:

* `FREFF` = Internal 50 MHz or external input



### Example Configurations

| FREF (MHz) | REFDIV | FBDIV | POST1 | POST2 | FOUT (MHz) |
| ---------- | ------ | ----- | ----- | ----- | ---------- |
| 50         | 2      | 32    | 5     | 4     | 40         |
| 50         | 3      | 40    | 7     | 7     | 13.6       |
| 50         | 1      | 16    | 4     | 2     | 100        |

---

## Testing this on Shrike-Lite

1. Load bitstream using ForgeFPGA toolchain
2. Connect logic analyzer to counter pins
3. Toggle `SEL` to switch between oscillator and external clock
4. Toggle `BYP` to enable/disable PLL processing
5. Observe frequency change in real time

Reference document:
https://www.renesas.com/en/document/apn/fg-006-how-drive-pll-oscillator?r=25546631

---

## Expected Output

* Counter output frequency changes based on PLL configuration
* Switching `SEL` changes reference clock source
* Enabling `BYP` directly outputs reference clock
* Disabling `BYP` applies PLL scaling

The behavior should match the Renesas application note exactly.
