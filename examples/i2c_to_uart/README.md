# I2C-to-UART Bridge with RP2040 Loopback Verification

**Difficulty:** Intermediate  
**Uses MCU:** Yes (RP2040)  
**External Hardware:** None

## Overview

This example demonstrates a complete I2C-to-UART communication bridge implemented on the FPGA and verified using an RP2040.

A byte written over I2C is received by the FPGA, forwarded over UART, and then a response byte is captured back through UART and made available for the next I2C read. The included Python scripts perform automated validation and stress testing to verify end-to-end operation.

This project demonstrates I2C slave handling, UART communication, finite state machine (FSM) design, turnaround response handling, and hardware-in-the-loop verification.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | MicroPython | ✅ Tested |
| Shrike (RP2350) | MicroPython | ⬜ Untested |
| Shrike-fi (ESP32-S3) | Arduino IDE | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

The setup consists of:

- FPGA running the I2C-to-UART bridge design
- RP2040 configured as the I2C master and UART responder for validation
- USB connection for programming and serial monitoring

### Interface Mapping

| Interface | Purpose |
|------------|------------|
| I2C SDA | Receives trigger data from the master |
| I2C SCL | I2C clock line |
| UART RX | Receives turnaround response data |
| UART TX | Sends forwarded data out |

## Project Structure

```text
i2c_to_uart/
│
├── main.py
├── Normal_test.py
├── stress.py
├── tb.v
│
└── ffpga/
    ├── src/
    └── build/
        └── bitstream/
			└── i2c_to_uart.bin