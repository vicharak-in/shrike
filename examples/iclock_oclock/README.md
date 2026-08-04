# iclock_oclock

**Difficulty:** Intermediate

**Uses MCU:** No

**External Hardware:** 26 MHz 3.3 V LVCMOS/CMOS clock source, oscilloscope or logic analyzer

## Overview

This example accepts a 26 MHz CMOS clock on `iclock` and produces an exact
32,500 Hz square wave on `oclock`. The output has a nominal 50% duty cycle.
The on-board FPGA LED blinks once per second from the same clock, providing a
simple visual check of the external-reference and PLL-bypass path.

GPIO2 is the SLG47910's dedicated external PLL-reference input. The design
selects that reference and puts the PLL in bypass mode, using it only as the
supported route into the FPGA global clock network. A 9-bit fabric counter
then toggles the output after every 400 input clocks:

```text
26,000,000 Hz / (400 clocks per half-cycle * 2) = 32,500 Hz
```

No MCU firmware is required.

## Pinout

Both signals are available on the Shrike/Shrike-Lite headers shown in the
[published board pinout](https://vicharak-in.github.io/shrike/_images/shrike_pinouts.svg).

| Signal | Board header label | SLG47910 pin | Direction | Purpose |
|--------|--------------------|---------------|-----------|---------|
| `iclock` | FPGA_IO2 | GPIO2 / pin 15 | Input | 26 MHz, 3.3 V LVCMOS reference |
| `oclock` | FPGA_IO7 | GPIO7 / pin 20 | Output | 32.5 kHz, 3.3 V LVCMOS clock |
| `led` | On-board FPGA LED | GPIO16 / pin 7 | Output | Active-high, 1 Hz clock-path heartbeat |
| GND | GND | GND / pin 12 | — | Clock-source ground reference |

The board's VDDIO must be configured for 3.3 V when a 3.3 V clock source is
connected. Do not drive `iclock` while the FPGA I/O bank is unpowered.

## Hardware Setup

1. Connect the clock generator's 26 MHz CMOS output to FPGA_IO2 (`iclock`).
2. Connect the generator ground to Shrike ground.
3. Connect an oscilloscope or logic analyzer to FPGA_IO7 (`oclock`).
4. Configure the source for a 0 V to 3.3 V CMOS waveform. Do not use a
   bipolar or 50-ohm RF-generator output directly.

After programming, the FPGA LED should remain stopped if the external clock
is absent and blink with a one-second period when the 26 MHz input path works.

## Build From Source

1. Open `iclock_oclock.ffpga` in Go Configure Software Hub.
2. Open `iclock_oclock.v` and run synthesis.
3. Confirm the existing I/O Planner assignments:

   - `iclock` -> `PLL_CLK` (the external GPIO2 reference is selected in logic)
   - `oclock` and `oclock_oe` -> GPIO7 output and output-enable resources
   - `led` and `led_oe` -> GPIO16 output and output-enable resources

4. Generate the bitstream and use `FPGA_bitstream_MCU.bin` from the project's
   `ffpga/build/bitstream/` directory.

The repository does not include a pre-built bitstream for this example; it
must be generated with the Renesas toolchain.

## RTL Checks

The example Makefile documents and runs the complete Icarus Verilog and
Verilator command lines. From this directory, use:

```sh
make             # Icarus simulation followed by Verilator lint
make icarus     # self-checking Icarus simulation only
make verilator  # Verilator elaboration and lint only
make clean      # remove generated simulation files
```

The self-checking testbench verifies the PLL-routing controls, checks that
every `oclock` transition occurs after exactly 400 input rising edges, and
checks the LED heartbeat divider using a simulation-shortened terminal count.
Run `make help` for the target summary.

## Expected Output

| Property | Expected value |
|----------|----------------|
| Frequency | 32,500 Hz |
| Period | 30.769230 us |
| High time | 15.384615 us |
| Low time | 15.384615 us |
| Duty cycle | 50% nominal |
| FPGA LED | Active-high, 0.5 s on / 0.5 s off |

The divider cannot remove frequency error or low-frequency jitter already
present on the 26 MHz source. Output edge placement is synchronous to the
input, and the output frequency error is the same fractional error as the
source clock.
