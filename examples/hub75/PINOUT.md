# HUB75 ⇄ Shrike-fi (SLG47910V ForgeFPGA) pin mapping

> **Not needed to run the simulation.** The testbench drives the panel pins as
> plain wires — there is no physical placement in `sim/`. This document is the
> **hardware bring-up reference**: use it only when you generate a real
> bitstream in Go Configure and need to place the ports on physical GPIO.

This is the IO-planner mapping used in the Renesas **Go Configure Software
Hub** after synthesising `src/main.v`. One ForgeFPGA drives **one**
panel.

## How mapping works on ForgeFPGA

Unlike Vivado/Quartus there is **no text constraint file**. You map top-level
ports to physical nets in the graphical **IO Planner** (see
`generating_your_first_bitstream.md` in the Shrike docs). Every output port has
a matching `*_oe` port in this design that must be tied to the pad's
`GPIOxx_OE` net (all are driven to 1 in RTL).

- `clk`   → **OSC_CLK**   (50 MHz internal oscillator)
- `clk_en`→ **OSC_EN**
- each output bit → **GPIOxx_OUT**, and its `_oe` bit → the *same* **GPIOxx_OE**
- `rst_n` → a spare **GPIOxx_IN**, or tie to **FPGA_CORE_READY** (costs no GPIO)

> The Shrike-fi exposes **14 FPGA GPIO**. Avoid **GPIO16** (FPGA user LED) and
> FPGA pins **3–6** (the ESP32-S3 SPI/config bus) if you intend to stream
> pixels from the ESP32 at runtime. Read the exact free GPIO numbers off the
> Shrike-fi pinout diagram (docs → *Shrike Pinouts* → Shrike-fi tab).

## Signals for the default 8×8 build (11 output pins + 1 reset)

`hub_rgb[5:0]` bit order is `{b2,g2,r2, b1,g1,r1}` — half **1** = upper 4 rows,
half **2** = lower 4 rows.

| Verilog port    | Bit | HUB75 connector | Map OUT to | Map OE to (`*_oe`) |
|-----------------|-----|-----------------|------------|--------------------|
| `hub_rgb[0]`    | R1  | R1              | GPIOa_OUT  | GPIOa_OE           |
| `hub_rgb[1]`    | G1  | G1              | GPIOb_OUT  | GPIOb_OE           |
| `hub_rgb[2]`    | B1  | B1              | GPIOc_OUT  | GPIOc_OE           |
| `hub_rgb[3]`    | R2  | R2              | GPIOd_OUT  | GPIOd_OE           |
| `hub_rgb[4]`    | G2  | G2              | GPIOe_OUT  | GPIOe_OE           |
| `hub_rgb[5]`    | B2  | B2              | GPIOf_OUT  | GPIOf_OE           |
| `hub_addr[0]`   | A   | A               | GPIOg_OUT  | GPIOg_OE           |
| `hub_addr[1]`   | B   | B               | GPIOh_OUT  | GPIOh_OE           |
| `hub_clk`       | —   | CLK             | GPIOi_OUT  | GPIOi_OE           |
| `hub_lat`       | —   | LAT/STB         | GPIOj_OUT  | GPIOj_OE           |
| `hub_oe_n`      | —   | OE (active low) | GPIOk_OUT  | GPIOk_OE           |
| `clk`           | —   | —               | OSC_CLK    | —                  |
| `clk_en`        | —   | —               | OSC_EN     | —                  |
| `rst_n`         | —   | —               | GPIO_IN / FPGA_CORE_READY | —   |

Panel **GND** ↔ board **GND**. Panel logic is 3.3 V-tolerant on most modern
HUB75 panels; level-shift to 5 V if your panel needs it (Shrike-fi pins are
3.3 V only — never drive 5 V back into them).

## Pin & BRAM budget when you scale (change parameters on `hub75_top`)

Output pins needed = `6 (RGB) + ceil(log2(ROWS/2)) (address) + 3 (CLK/LAT/OE)`.
Framebuffer bits = `ROWS × COLS × 3 × BPP`  (BRAM = **32768 bits**).

| Panel   | Addr bits | Output pins | BPP | FB bits | Fits 14 GPIO? | Fits BRAM? |
|---------|-----------|-------------|-----|---------|----------------|------------|
| 8×8     | 2 (A,B)   | 11          | 4   | 768     | ✅             | ✅ (dist.) |
| 16×16   | 3 (A–C)   | 12          | 4   | 3 072   | ✅             | ✅         |
| 32×32   | 4 (A–D)   | 13          | 4   | 12 288  | ✅             | ✅         |
| 64×32   | 4 (A–D)   | 13          | 4   | 24 576  | ✅             | ✅         |
| 64×64   | 5 (A–E)   | 14          | 4   | 49 152  | ✅ (no rst pin)| ❌ → use BPP≤2 |
| 64×64   | 5 (A–E)   | 14          | 2   | 24 576  | ✅             | ✅         |

For 64×64 use `FPGA_CORE_READY` for reset (frees the GPIO) and `BPP ≤ 2`, or
move the framebuffer to the ESP32 and stream lines.
