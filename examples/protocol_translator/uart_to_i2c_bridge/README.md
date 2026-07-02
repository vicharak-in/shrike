# UART-to-I2C Bridge with RP2040 Loopback Verification

**Difficulty:** Intermediate

**Uses MCU:** Yes (RP2040)

**External Hardware:** None

## Overview

This project implements a complete UART-to-I2C communication bridge on the FPGA and verifies it using an RP2040 configured as an I2C slave.

The module:

- Receives UART data
- Initiates an I2C write transaction
- Sends the received byte to the RP2040 I2C slave
- Performs an I2C read transaction
- Receives the response from the RP2040
- Sends the response back over UART

## Compatibility

| Board                | Firmware      | Status      |
| -------------------- | ------------- | ----------- |
| Shrike-Lite (RP2040) | `MicroPython` | ✅ Tested   |
| Shrike (RP2350)      | `MicroPython` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `Arduino IDE` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware is required.

The setup consists of:

- FPGA running the UART-to-I2C bridge
- RP2040 configured as an I2C slave
- USB connection for programming and serial monitoring

### UART Interface

| UART Device | FPGA GPIO |
| ----------- | -----------| 
| TX          | GPIO06  (UART TX) | 
| RX          | GPIO04  (UART RX) | 
| GND         | GND            |



### I2C Interface

| I2C Device | GPIO | 
| ---------- | ----------- | 
| SDA        | GPIO18  (I2C1 SDA) | 
| SCL        | GPIO17  (I2C1 SCL) | 
| GND        | GND               |
### Development Setup

A Shrike-Lite (RP2040) board running MicroPython was used for testing.

## Quick Start (Pre-Built Bitstream)

### FPGA

1. Connect your Shrike board.
2. Upload the bitstream from the `bitstream/` folder.
3. Reset the board.

### Firmware

1. Open:

```text
firmware/micropython/main.py
```

2. Upload and run the script.

### Expected Behavior

- Firmware sends a UART trigger byte.
- FPGA performs an I2C write transaction.
- RP2040 receives the byte.
- FPGA performs an I2C read transaction.
- RP2040 returns a response.
- FPGA transmits the response over UART.
- Firmware verifies the received response.

A successful execution should complete without communication errors.

## Build From Source

### FPGA

1. Open the FPGA project in GCSH.
2. Add the Verilog files from:

```text
ffpga/src/
```

3. Generate the bitstream.
4. Program the board.

### MicroPython

1. Open the firmware script.
2. Upload it to the development board.
3. Run the program.

## How It Works

The UART-to-I2C Bridge converts UART data into I2C transactions and returns the I2C response over UART.

## Expected Output

### Sample Serial Output

```text
=== STARTING ROBUST STRESS TESTING (166 MULTIPLE VECTORS) ===

--------------------------------------------------
VECTOR 000/165 | Blasting Payload: 0x00
 -> [I2C Slave] FPGA Write Caught: 0x00
 -> [I2C Slave] Read Request Filled: 0x10
 -> [UART RX] Object A Logged Echo: 0x10
 >> CYCLE VERIFICATION STATUS: PASS ✅
--------------------------------------------------
VECTOR 001/165 | Blasting Payload: 0xFF
 -> [I2C Slave] FPGA Write Caught: 0xFF
 -> [I2C Slave] Read Request Filled: 0x0F
 -> [UART RX] Object A Logged Echo: 0x0F
 >> CYCLE VERIFICATION STATUS: PASS ✅

...

==================================================
 FINAL BENCH BENCHMARK: 166/166 CYCLES PASSED PERFECTLY
==================================================
```

### Note

The UART-to-I2C and I2C-to-UART communication paths have been validated using the included MicroPython firmware.

The project performs a complete end-to-end bridge test and can be extended to work with external UART and I2C peripherals.