# DSPI PIO Echo

**Difficulty:**  
**Uses MCU:** Yes  
**External Hardware:** None  

## Overview

This example demonstrates a custom 10 MHz Dual-SPI (DSPI) protocol implementation on the Shrike platform, utilizing two data lines simultaneously to double standard SPI throughput. It uses the RP2040's Programmable I/O (PIO) to act as the DSPI master, and an oversampled target state machine on the ForgeFPGA that echoes data and generates periodic asynchronous heartbeat alerts.

The project includes two firmware implementations: a flat "logic analyzer" script to view raw clock-by-clock bit transmissions, and a fully encapsulated, object-oriented MicroPython library (`dspi_bus.py`) designed to be dropped into larger projects.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested |
| Shrike (RP2350) | `firmware/micropython/` | ✅ Tested |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required. The configuration utilizes the internal routing between the MCU and the FPGA.

**FPGA Connections:**
* **Pin 3:** `spi_sck` (Input) - SPI clock
* **Pin 4:** `spi_ss_in` (Input) - Chip select (active low)
* **Pin 18:** `dual_io[0]` (Inout) - DSPI Data Line 0
* **Pin 17:** `dual_io[1]` (Inout) - DSPI Data Line 1
* **Pin 16:** `led` (Output) - Status LED (Blinks based on internal heartbeat)

**RP2040 / RP2350 Connections:**
* **GPIO 2:** `SCK` (Output) - SPI clock
* **GPIO 1:** `CS` (Output) - Chip select
* **GPIO 14:** `DSPI_D0` (Inout) - PIO Data Line 0
* **GPIO 15:** `DSPI_D1` (Inout) - PIO Data Line 1

*(Note: The RP2040 PIO requires data pins to be contiguous in the silicon. GPIO 14 and 15 form a contiguous block mapped to the FPGA interconnects).*

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB.
2. Upload `bitstream/dspi_pio_echo.bin` using ShrikeFlash.
3. To view raw bit transmissions, run `firmware/micropython/dspi_pio_echo.py` on the MCU.
4. Open the serial monitor and type characters.
5. **Expected result:** The MCU will transmit the characters, and the terminal will print the clock-by-clock dual-bit transmission alongside periodic `0xFF` async alerts.

## Build From Source

### FPGA (Verilog)
1. Open `ffpga/dspi_pio_echo.ffpga` in Go Configure Software Hub.
2. Click Synthesize → Generate Bitstream.
3. Output will be in `ffpga/build/`.

### Firmware (MicroPython)
1. Open `firmware/micropython/` in Thonny.
2. Ensure you have flashed the compiled bitstream.
3. Run either `dspi_pio_echo.py` (for the analyzer view) or `main.py` (to test the OOP library).

## How It Works

This project bypasses standard SPI hardware limits by utilizing the **RP2040 PIO State Machine** (`@rp2.asm_pio`). The PIO uses `out(pins, 2)` and `in_(pins, 2)` instructions to shift two bits per clock cycle. On the FPGA side, a 3-stage synchronizer (`sck_sync`, `cs_sync`) driven by the ForgeFPGA's internal 50 MHz clock oversamples the 10 MHz SPI clock to safely shift data in and out, while toggling a bus turnaround phase to prevent short circuits on the bidirectional lines.

### Using the `DSPI` Library in Your Projects
If you want to use this high-speed bus in your own code, upload `dspi_bus.py` to your MCU. You can initialize the bus and trigger a standard data transfer using the `transfer()` method, which automatically handles strings, bytearrays, and integer lists:

```python
from dspi_bus import DSPI

# Initialize the bus on default pins
fpga_bus = DSPI()

# Send data and receive the echo
rx_data = fpga_bus.transfer("hello")
print([hex(b) for b in rx_data])

# Check for async alerts from the FPGA
if fpga_bus.has_alert():
    print("FPGA requested attention!")

    
