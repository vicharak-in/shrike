# UART-to-I2C Bridge with RP2040 Loopback Verification

**Difficulty:** Intermediate  
**Uses MCU:** Yes (RP2040)  
**External Hardware:** None

## Overview

This example demonstrates a complete UART-to-I2C communication bridge implemented on the FPGA and verified using an RP2040 acting as an I2C slave.

A byte received over UART is forwarded through the FPGA's I2C Master, transmitted to an I2C slave, and a response is read back and returned over UART. The included Python scripts perform automated validation and stress testing to verify end-to-end functionality.

This project demonstrates UART communication, I2C master transactions, finite state machine (FSM) design, clock stretching, and hardware-in-the-loop verification.

## Compatibility

| Board | Firmware | Status |
|---------|---------|---------|
| Shrike-Lite (RP2040) | MicroPython | ✅ Tested |
| Shrike (RP2350) | MicroPython | ⬜ Untested |
| Shrike-fi (ESP32-S3) | Arduino IDE | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

The setup consists of:

- FPGA running the UART-to-I2C bridge design
- RP2040 configured as an I2C slave device
- USB connection for programming and serial monitoring

### Interface Mapping

| Interface | Purpose |
|------------|------------|
| UART RX | Receives trigger data |
| UART TX | Returns response data |
| I2C SDA | I2C data line |
| I2C SCL | I2C clock line |

## Project Structure

```text
uart_to_i2c/
│
├── main.py
├── Normal_test.py
├── tb.sv
│
└── ffpga/
    ├── src/
    └── build/
        └── bitstream/
            └── UART_to_I2C_bridge.bin
```
### Files

| File/Folder | Description |
|------------|-------------|
| `ffpga/src/` | FPGA source files |
| `ffpga/build/bitstream/UART_to_I2C_bridge.bin` | Pre-built FPGA bitstream |
| `tb.sv` | SystemVerilog simulation testbench |
| `Normal_test.py` | Functional 100-cycle verification test |
| `main.py` | Extended stress-testing framework |

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB.
2. Program the FPGA using the pre-built bitstream:

```text
ffpga/build/bitstream/UART_to_I2C_bridge.bin
```

3. Upload `Normal_test.py` or `main.py` to the RP2040.
4. Open a serial terminal at **115200 baud**.
5. Run the test script.

Expected result:

- UART trigger byte transmitted
- FPGA performs I2C write transaction
- FPGA performs I2C read transaction
- Response returned over UART
- Test cycle reports PASS


## Build From Source

### FPGA (Verilog)

1. Open the FPGA project located in:

```text
ffpga/src/
```

2. Synthesize the design.
3. Generate the bitstream.
4. Generated files will be available in:

```text
ffpga/build/
```

### Firmware (MicroPython)

1. Open `Normal_test.py` or `main.py` in Thonny.
2. Connect the RP2040 board.
3. Upload the script.
4. Run the script.

## How It Works

### System Architecture

```text
UART Host
    │
    ▼
UART Receiver
    │
    ▼
Bridge FSM
    │
    ▼
I2C Master
    │
    ▼
RP2040 I2C Slave
    │
    ▼
I2C Master Read
    │
    ▼
UART Transmitter
    │
    ▼
UART Host
```

### Transaction Flow

1. A byte is received on UART RX.
2. The FPGA stores the received value.
3. An I2C write transaction is initiated to slave address `0x50`.
4. The RP2040 receives the transmitted byte.
5. The FPGA initiates an I2C read transaction.
6. The RP2040 supplies a response byte.
7. The FPGA captures the response.
8. The response is transmitted back over UART.
9. The firmware verifies the returned value.

## RP2040 Test Firmware

The RP2040 is configured as an I2C slave and performs the following operations:

- Receives I2C write transactions
- Detects FPGA read requests
- Supplies response data
- Verifies UART echoes
- Reports PASS/FAIL status

### Normal_test.py

Performs:

- 100 transaction cycles
- Deterministic test patterns
- End-to-end verification

### main.py

Performs:

- Boundary value testing
- Walking-one patterns
- Incrementing sequences
- Randomized stress testing

## Expected Output

Successful execution produces output similar to:

```text
=== STARTING TRUE BIDIRECTIONAL SILICON SWEEP (100 CYCLES) ===

TEST 00 | Blasting UART Trigger: 0x01

 -> [I2C Slave] FPGA Write Caught: 0x01
 -> [I2C Slave] Read Request Filled: 0x11
 -> [UART RX] Object A Logged Echo: 0x11
 >> CYCLE VERIFICATION STATUS: PASS

TEST 01 | Blasting UART Trigger: 0x02

 -> [I2C Slave] FPGA Write Caught: 0x02
 -> [I2C Slave] Read Request Filled: 0x12
 -> [UART RX] Object A Logged Echo: 0x12
 >> CYCLE VERIFICATION STATUS: PASS
```

Final summary:

```text
==================================================
FINAL BENCH BENCHMARK: 100/100 CYCLES PASSED PERFECTLY
==================================================
```

## Features Demonstrated

- UART Receiver
- UART Transmitter
- I2C Master Write Transactions
- I2C Master Read Transactions
- Clock Stretching Support
- Finite State Machine (FSM) Design
- FPGA-to-MCU Communication
- Hardware-in-the-Loop Validation
- Automated Stress Testing

## Learning Outcomes

After completing this example, you will understand:

- How to implement a UART-to-I2C bridge in FPGA logic
- How UART and I2C protocols interact
- How an FSM coordinates peripheral transactions
- How I2C read and write operations work
- How clock stretching is handled by an I2C slave
- How to validate FPGA designs using real hardware
- How to create automated verification and stress-test frameworks