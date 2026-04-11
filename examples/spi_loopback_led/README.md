# spi_loopback_led

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** None

## Overview

This example demonstrates controlling the onboard LED on Shrike using SPI commands from the RP2040 (or any SPI master). It also implements a loopback mechanism where data sent from the MCU to the FPGA is returned back to the MCU.

You will learn how to implement an SPI target (slave) in FPGA and perform bidirectional communication using SPI.

## Compatibility

| Board                | Firmware                | Status        |
| -------------------- | ----------------------- | ------------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested      |
| Shrike (RP2350)      | `firmware/micropython/` | ✅ Tested      |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested    |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

### FPGA Connections

| FPGA GPIO Pin | Signal Name | Direction | Description              |
| ------------- | ----------- | --------- | ------------------------ |
| 3             | `spi_sck`   | Input     | SPI clock                |
| 4             | `spi_ss_n`  | Input     | Chip select (active low) |
| 5             | `spi_mosi`  | Input     | MOSI (receive)           |
| 6             | `spi_miso`  | Output    | MISO (transmit)          |
| 18            | `rst_n`     | Input     | Reset (active low)       |
| 16            | `led`       | Output    | LED state                |

### RP2040 Connections

| RP2040 Pin | Signal Name | Direction | Description               |
| ---------- | ----------- | --------- | ------------------------- |
| 2          | SCK         | Output    | SPI clock                 |
| 1          | CS          | Output    | Chip select               |
| 3          | MOSI        | Output    | Master output             |
| 0          | MISO        | Input     | Master input              |
| 14         | Reset       | Output    | Reset signal (active low) |

> Ensure pin mapping in FPGA constraints matches firmware configuration.

---

## Quick Start (Pre-Built Bitstream)

1. Connect Shrike board via USB
2. Upload `bitstream/spi_loopback_led.bin` using ShrikeFlash
3. Run `spi_led.py` on RP2040
4. Expected result:

   * Sending `0xAB` → LED turns ON
   * Sending `0xFF` → LED turns OFF
   * Data sent is looped back to MCU

---

## Build From Source

### FPGA (Verilog)

1. Open project in Go Configure Software Hub
2. Paste Verilog for `top` and `spi_target` modules
3. Configure I/O mapping
4. Generate bitstream

### Firmware (MicroPython)

1. Open `spi_led.py` in Thonny
2. Configure SPI pins
3. Run script to send/receive data

---

## How It Works

The design consists of two main modules:

### 1. `top` Module

* Controls LED based on received SPI data
* Implements loopback functionality
* Instantiates SPI target module

Behavior:

* `0xAB` → LED ON
* `0xFF` → LED OFF
* Transmits previously received byte back via SPI

---

### 2. `spi_target` Module

* Implements SPI slave (target) logic
* Handles:

  * Data reception via MOSI
  * Data transmission via MISO
  * Clock synchronization using `spi_sck`
  * Chip select handling using `spi_ss_n`

---

## Top Module Interface

| Signal     | Direction | Description                   |
| ---------- | --------- | ----------------------------- |
| `clk`      | In        | System clock (50 MHz typical) |
| `clk_en`   | Out       | Clock enable (always 1)       |
| `rst_n`    | In        | Reset (active low)            |
| `led`      | Out       | LED output                    |
| `spi_ss_n` | In        | SPI select (active low)       |
| `spi_sck`  | In        | SPI clock                     |
| `spi_mosi` | In        | Input from controller         |
| `spi_miso` | Out       | Output to controller          |

---

## Expected Output

* Sending `0xAB` → LED turns ON
* Sending `0xFF` → LED turns OFF
* Data sent from RP2040 is echoed back (loopback)

This confirms:

* SPI communication is working
* FPGA correctly processes and returns data

---

## Notes

* SPI operates in full-duplex mode (simultaneous read/write)
* Loopback helps verify communication integrity
* Ensure correct reset handling before communication
