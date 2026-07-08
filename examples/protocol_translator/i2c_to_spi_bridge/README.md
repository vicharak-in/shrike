# I2C to SPI Bridge

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** I2C host device and SPI peripheral.

## Overview

This project implements an I2C to SPI bridge on the Shrike FPGA.

The module:

* Receives I2C data.
* Stores received bytes in an RX FIFO.
* Starts an SPI transaction.
* Captures the SPI response.
* Stores the response in an internal response register.
* Returns the response through I2C.

## Compatibility

| Board                | Firmware                | Status               |
| -------------------- | ----------------------- | -------------------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested |
| Shrike (RP2350)      | `firmware/micropython/` | ⬜ Untested           |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested           |

> FPGA bitstream is the same across all boards.

## Hardware Setup

The I2C to SPI Bridge is designed to interface an I2C-compatible host device with an SPI-compatible peripheral.

### I2C Interface

Connect the I2C host device to the FPGA I2C pins.

| I2C Device | FPGA GPIO |
| ---------- | --------- |
| SDA        | GPIO0 (SDA) |
| SCL        | GPIO1 (SCL) |
| GND        | GND |

### SPI Interface

Connect the SPI peripheral to the FPGA SPI pins.

| SPI Device | FPGA GPIO |
| ---------- | --------- |
| MISO       | GPIO13 (MISO) |
| MOSI       | GPIO12 (MOSI) |
| SCLK       | GPIO10 (SCLK) |
| CS         | GPIO11 (CS) |
| GND        | GND |
### Development Setup

A Shrike-Lite (RP2040) board running MicroPython was used as the I2C master during validation.

During testing, the SPI MOSI and MISO pins were connected together to create a loopback configuration.

## Quick Start (Pre-Built Bitstream)

This example can be tested using the pre-built FPGA bitstream and the provided MicroPython firmware.

### FPGA

1. Connect your Shrike board to the computer.
2. Upload the bitstream from the `bitstream/` folder.
3. Reset the board after programming.

### Firmware

Open the MicroPython script located in:

```text
firmware/micropython/i2c_to_spi_bridge.py
```

Upload and run the script on the development board.

### Expected Behavior

* Firmware sends 100 bytes over I2C.
* The FPGA stores the received byte in the RX FIFO.
* The bridge controller starts an SPI transaction.
* The SPI response is captured and stored.
* The firmware reads the returned byte through I2C.

## Build From Source

### FPGA (Verilog)

Open the FPGA project in Go Configure Software Hub (GCSH).

Add the Verilog source files from:

```text
ffpga/src/
```

Synthesize the design.

Generate the FPGA bitstream.

Program the Shrike board with the generated bitstream.

### MicroPython Firmware

Open the MicroPython script:

```text
firmware/micropython/i2c_to_spi_bridge.py
```

Connect the development board.

Upload the script.

Run the program.

## How It Works

The I2C to SPI Bridge receives data from an I2C master, transfers it through SPI, and returns the SPI response through I2C.

Data received from I2C is first stored in a FIFO buffer. The bridge controller then starts an SPI transaction using the received byte.

The SPI response is stored in an internal response register. A response-valid mechanism ensures that the I2C master receives the response corresponding to the current SPI transaction.

## Expected Output
### Sample Serial Output

```text
100 BYTE I2C-SPI BRIDGE TEST
--------------------------------
PASS 0 TX = 0x0 RX = 0x0
PASS 1 TX = 0x1 RX = 0x1
PASS 2 TX = 0x2 RX = 0x2

...

PASS 99 TX = 0x63 RX = 0x63

--------------------------------
SUMMARY
Passed : 100
Failed : 0

SUCCESS
```
