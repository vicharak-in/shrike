```
# ASCII to Braille QSPI Bridge with Bidirectional Interrupts
```

```
**Difficulty:** Advanced
**Uses MCU:** Yes
```

```
**External Hardware:** None
```

## `## Overview` 

```
This example demonstrates how to build a custom, bidirectional 4-bit (QSPI)
communication protocol over the Shrike's internal 6-wire bridge to convert ASCII
characters into Braille. It also highlights an advanced pin-saving technique:
overloading the Chip Select (CS) line as an open-drain interrupt, allowing the
FPGA to asynchronously demand attention from the MCU.
```

## `## Compatibility` 

```
| Board | Firmware | Status |
```

```
|-------|----------|--------|
```

`| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested | | Shrike (RP2350) | `firmware/micropython/` |` ⬜ `Untested | | Shrike-fi (ESP32-S3) | `firmware/micropython/` |` ⬜ `Untested |` 

```
> FPGA bitstream is the same across all boards, though MCU GPIO definitions may
need mapping adjustments for the RP2350 or ESP32-S3.
```

## `## Hardware Setup` 

```
No external hardware required. This example strictly relies on the internal 6-
trace copper bridge between the RP2040 and the ForgeFPGA.
```

```
**Go Configure I/O Mapping:**
```

- `**Clock (`spi_sck`):** Pin 3 (Input)` 

- `**CS / IRQ (`spi_ss`):** Pin 4 (Bidirectional)` 

- `**QSPI Bus (`qspi_io[0:3]`):** Pins 5, 6, 17, 18 (Bidirectional)` 

## `## Quick Start (Pre-Built Bitstream)` 

`1. Connect your Shrike-Lite board via USB.` 

`2. Open Thonny IDE and ensure your MicroPython interpreter is connected.` 

`3. Open `firmware/micropython/main.py` and run the script. The script will automatically flash `FPGA_bitstream_MCU.bin` to the FPGA on startup.` 

`4. **Expected result:** The terminal will display asynchronous FPGA alerts every 2 seconds, while allowing you to type strings for instant Braille conversion.` 

## `## Build From Source` 

```
### FPGA (Verilog)
```

`1. Open `qspi_braille.ffpga` in Go Configure Software Hub.` 

`2. Open the **I/O Planner** and ensure the Split-CS and QSPI data pins are properly configured with their `IN`, `OUT`, and `OE` nodes mapped to the Bidirectional pads.` 

`3. Click Synthesize → Generate Bitstream.` 

`4. Output will be in `ffpga/build/`. Rename and move the `.bin` file to your MCU's flash storage.` 

## `### Firmware (MicroPython)` 

`1. Open `firmware/micropython/main.py` in Thonny IDE.` 

`2. Ensure the `qio_pins` array matches your hardware mapping (accounting for non-contiguous internal RP2040 pins).` 

`3. Run the script.` 

## `## How It Works` 

```
* **The QSPI FSM:** Instead of standard 1-bit SPI, data is sliced into 4-bit
```

```
nibbles. The MCU drives the clock and transmits an ASCII character over two
clock cycles. The FPGA takes authoritative control of the bus during a 1-clock
"turnaround" phase, queries an internal Lookup Table (LUT), and transmits the 8-
bit Braille equivalent back to the MCU over the next two clock cycles.
```

```
* **The Shared CS/IRQ Hack:** Because all 6 internal traces are consumed by the
QSPI bus, there are no pins left for a hardware interrupt. The Verilog simulates
an open-drain output on the CS pin. When the FPGA needs attention (triggered by
a 2-second hardware timer), it pulls CS low. The RP2040 detects this falling
edge via a hardware IRQ, temporarily disables its listener, and takes over the
CS line as an Output to query the FPGA for its alert code (`0xF0`).
```

```
* **Non-Blocking Execution:** To prevent Python's standard `input()` function
from freezing the MCU, the script utilizes `uselect.poll()` on `sys.stdin`. This
allows the main loop to listen for asynchronous FPGA interrupts and human
keyboard input simultaneously.
```

## `## Expected Output` 

```
When running correctly in the Thonny shell, you will see a mix of asynchronous
hardware interrupts triggered by the FPGA, interwoven with synchronous user
input processing:
```

```
```text
```

```
--- FULLY BIDIRECTIONAL QSPI RUNNING ---
1. Click this console window, type a word, and press Enter.
```

```
2. The FPGA will also interrupt the MCU every 2 seconds.
```

```
[ASYNC FPGA ALERT] Received Code: 0xF0
[ASYNC FPGA ALERT] Received Code: 0xF0
```

```
--- Processing User Input: 'shrike' ---
[MCU SENT] 's' (0x73) -> [BRAILLE RECEIVED] 0x0E
[MCU SENT] 'h' (0x68) -> [BRAILLE RECEIVED] 0x13
[MCU SENT] 'r' (0x72) -> [BRAILLE RECEIVED] 0x17
[MCU SENT] 'i' (0x69) -> [BRAILLE RECEIVED] 0x0A
[MCU SENT] 'k' (0x6B) -> [BRAILLE RECEIVED] 0x05
[MCU SENT] 'e' (0x65) -> [BRAILLE RECEIVED] 0x11
-------------------------------------------
```

```
[ASYNC FPGA ALERT] Received Code: 0xF0
```

