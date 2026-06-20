# Cellular Automata on WS2812 LED Matrix

**Difficulty:** Intermediate  
**Uses MCU:** No  
**External Hardware:** 4×4 WS2812 RGB LED matrix, 4× slide switches

## Overview

A hardware implementation of one-dimensional cellular automata running entirely on the Shrike-Lite FPGA. No microcontroller, firmware, or software is involved—the SLG47910 generates each automaton state and directly drives a 4×4 WS2812 LED matrix.
Four slide switches let you switch between rules in real time, each producing a visually and mathematically distinct pattern with its own colour.

## Compatibility

| Board | Status |
|-------|--------|
| Shrike-Lite (RP2040) | ✅ Tested |
| Shrike (RP2350) | ⬜ Untested |
| Shrike-fi (ESP32-S3) | ⬜ Untested |

> No firmware is involved. The FPGA handles everything from rule computation to LED driving.

## Hardware Setup

| Signal | Shrike-Lite Pin | Component |
|--------|-----------------|-----------|
| `DO` | Pin 0 | WS2812 DIN |
| `reset` | Pin 1 | Active-low reset |
| `SW0` | Pin 8 | Slide switch → GND |
| `SW1` | Pin 10 | Slide switch → GND |
| `SW2` | Pin 12 | Slide switch → GND |
| `SW3` | Pin 14 | Slide switch → GND |
| GND | GND | Matrix GND |
| 5V | 5V | Matrix VCC |

Wire the WS2812 matrix data-in to the `DO` pin. Each slide switch connects between its GPIO pin and GND — the FPGA reads them active-high so pull them up through the GoHub pin configuration.

## Quick Start (Pre-Built Bitstream)

1. Connect Shrike-Lite via USB
2. Upload bitstream.
3. Wire up the 4×4 WS2812 matrix and four slide switches
4. Power on — you should see a red chaotic pattern scrolling downward (Rule 30 is the default)
5. Flip any slide switch to change the rule and colour in real time

## Build From Source

### FPGA (Verilog)

1. Open `chaos.ffpga` in Go Configure Software Hub
2. Paste the provided Verilog 
3. Assign pins for `clk`, `reset`, `sw0–sw3`, `DO`, `clk_en`, and `do_en`
4. Click **Synthesize → Generate Bitstream**

## How It Works

### The Cellular Automaton

A one-dimensional cellular automaton is a row of cells, each either alive (1) or dead (0). At every generation, each cell looks at itself and its immediate left and right neighbours — three cells total — producing one of eight possible 3-bit patterns (000 through 111). An 8-bit rule number encodes the output for each of those eight patterns: if bit N of the rule is set, then pattern N produces a live cell in the next generation.

For example, Rule 30 in binary is `00011110`. Pattern 3 (`011`) maps to bit 3 → 1, so a live cell flanked by a dead-right and live-left neighbour stays alive. Every other pattern maps according to the same lookup.

The display shows this evolving in time: the current generation occupies row 0 (top), and each new tick the rows shift down, row 3 drops off, and a freshly computed row appears at the top. What you see is four consecutive generations at once — a scrolling window into the automaton's history.

The boundary is circular: the leftmost cell treats the rightmost cell as its left neighbour, and vice versa.


### Selectable Rules

| Switch | Rule     | Colour | Description                                                                                                                                   |
| ------ | -------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| SW0    | Rule 30  | Red    | Chaotic and unpredictable. Produces complex patterns from simple initial conditions and has been studied as a pseudo-random number generator. |
| SW1    | Rule 90  | Green  | Generates the classic Sierpinski triangle fractal with strong symmetry and self-similarity.                                                   |
| SW2    | Rule 110 | White  | Exhibits highly complex behaviour. Notably, Rule 110 has been proven to be Turing complete.                                                   |
| SW3    | Rule 45  | Amber  | Produces semi-chaotic structures with characteristics similar to Rule 30 but a distinct visual appearance.                                    |

Rules can be changed at any time using the slide switches, allowing real-time observation of different automaton behaviours.

## Expected Output

On power-up with no switches set, Rule 30 runs by default in red. A single lit cell in the middle of the top row appears first, then each subsequent generation appears below it as the pattern grows. The result is an irregular, asymmetric cascade that never repeats.

> [Watch it running](images/ws2812.mp4)
