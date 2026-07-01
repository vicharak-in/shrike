# SPI to UART Bridge

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** SPI host device and UART device.

## Overview

This project implements an SPI to UART bridge on the Shrike FPGA.

The module:

- Receives SPI data
- Stores data in an RX FIFO
- Starts a UART transmission
- Receives UART response
- Stores the response in a FIFO
- Sends the response back through SPI

## Compatibility

| Board                | Firmware                | Status                |
| -------------------- | ----------------------- | --------------------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested |
| Shrike (RP2350)      | `firmware/arduino-ide/` | ⬜ Untested           |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested           |

> FPGA bitstream is the same across all boards.

## Hardware Setup

The SPI to UART Bridge is designed to interface an SPI host device with a UART device.

### SPI Interface

| SPI Device | FPGA GPIO    |
| ---------- | ------------ |
| MISO       | GPIO6 (MISO) |
| MOSI       | GPIO5 (MOSI) |
| SCLK       | GPIO3 (SCLK) |
| CS         | GPIO4 (CS)   |
| GND        | GND          |

### UART Interface

| UART Device | FPGA GPIO   |
| ----------- | ----------- |
| TX          | GPIO14 (RX) |
| RX          | GPIO15 (TX) |
| GND         | GND         |


### Development Setup

A Shrike-Lite (RP2040) board running MicroPython was used for testing.

## Quick Start (Pre-Built Bitstream)

### FPGA

1. Connect your Shrike board.
2. Upload the bitstream from the `bitstream/` folder.
3. Reset the board.

### Firmware

1. Open:

```
firmware/micropython/spi_to_uart_bridge.py
```

2. Upload and run the script.

### Expected Behavior

- Firmware sends SPI data.
- FPGA forwards data to UART.
- UART response is received.
- FPGA sends the response back through SPI.

A successful execution should complete without communication errors.

## Build From Source

### FPGA

1. Open the FPGA project in GCSH.
2. Add the Verilog files from:

```
ffpga/src/
```

3. Generate the bitstream.
4. Program the board.

### MicroPython

1. Open the firmware script.
2. Upload it to the development board.
3. Run the program.

## How It Works

The SPI to UART Bridge converts SPI data into UART transactions and returns the UART response through SPI.


## Expected Output

### Sample Serial Output

```text
===================================
 100 BYTE FULL BRIDGE TEST
===================================

PASS [0] REQ=0xC8 RESP=0x37
PASS [1] REQ=0x7F RESP=0x80
PASS [2] REQ=0x47 RESP=0xB8

...

PASS [99] REQ=0x6F RESP=0x90

===================================
 SUMMARY
===================================

Passed : 100
Failed : 0

SUCCESS
```

### Note

The SPI to UART and UART to SPI communication paths have been validated using the included MicroPython firmware.

The project performs a complete end-to-end bridge test and can be extended to work with external SPI and UART peripherals.