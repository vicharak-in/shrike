# UART to SPI Bridge

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** UART host device and SPI peripheral for complete system validation

## Overview

This example demonstrates a UART to SPI protocol bridge implemented on the Shrike FPGA platform.

The bridge receives data from a UART-compatible device, temporarily stores it inside a FIFO buffer, initiates an SPI transaction using an FPGA-based SPI Master, captures the SPI response, and sends the received SPI data back through the UART interface.

This example introduces several important FPGA design concepts, including:

* UART Receiver and Transmitter Design
* FIFO Buffer Implementation
* Finite State Machine (FSM) Design
* SPI Master Implementation
* Protocol Bridging
* FPGA Hardware Interface Design

The architecture is generic and can be used to interface UART-based systems with SPI-compatible peripherals.

## Compatibility

| Board                | Firmware                | Status               |
| -------------------- | ----------------------- | -------------------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Development Tested |
| Shrike (RP2350)      | `firmware/arduino-ide/` | ⬜ Untested           |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested           |

> FPGA bitstream is the same across all boards.

## Hardware Setup

The UART to SPI Bridge is designed to interface a UART-compatible host device with an SPI-compatible peripheral.

### UART Interface

Connect the UART host device to the FPGA UART pins.

| UART Device | FPGA |
| ----------- | ---- |
| TX          | RX   |
| RX          | TX   |
| GND         | GND  |

### SPI Interface

Connect the SPI peripheral to the FPGA SPI pins.

| SPI Device | FPGA |
| ---------- | ---- |
| MISO       | MISO |
| MOSI       | MOSI |
| SCLK       | SCLK |
| CS         | CS   |

### Development Setup

During development and validation, a Shrike-Lite (RP2040) board running MicroPython was used as the UART host.

The SPI interface was validated using the FPGA SPI Master implementation. Final validation with actual SPI peripherals can be performed by connecting compatible SPI sensors, displays, memory devices, or other SPI-enabled hardware.

No modifications to the FPGA design are required when replacing the development setup with a compatible UART host and SPI peripheral.

## Quick Start (Pre-Built Bitstream)

This example can be tested using the pre-built FPGA bitstream and the provided MicroPython firmware.

### FPGA

1. Connect your Shrike board to the computer.
2. Upload the bitstream from the `bitstream/` folder.
3. Reset the board after programming.

### Firmware

1. Open the MicroPython script located in:

   ```
   firmware/micropython/uart_to_spi_bridge.py
   ```

2. Upload and run the script on the development board.

### Expected Behavior

* The firmware sends 100 UART data bytes to the FPGA.
* The FPGA stores the data in the RX FIFO.
* The Bridge Controller starts an SPI transaction.
* The SPI response is stored in the TX FIFO.
* The UART TX Handler sends the response back to the UART host.

During the current development stage, the SPI slave is not implemented, so the expected UART response is `0x00`.

A successful execution should complete the test without any communication errors.

## Build From Source

### FPGA (Verilog)

1. Open the FPGA project in Go Configure Software Hub (GCSH).
2. Add the Verilog source files from:

   ```
   ffpga/src/
   ```

3. Synthesize the design.
4. Generate the FPGA bitstream.
5. Program the Shrike board with the generated bitstream.

### MicroPython Firmware

1. Open the MicroPython script:

   ```
   firmware/micropython/uart_to_spi_bridge.py
   ```

2. Connect the development board.
3. Upload the script.
4. Run the program.

### Project Structure

```
uart_to_spi_bridge/
│
├── README.md
│
├── ffpga/
│   └── src/
│       ├── uart_rx.v
│       ├── uart_tx.v
│       ├── fifo_8x8.v
│       ├── bridge_controller.v
│       ├── spi_master.v
│       ├── uart_tx_handler.v
│       └── top.v
│
├── firmware/
│   ├── micropython/
│   │   └── uart_to_spi_bridge.py
│   │
│   └── arduino-ide/
│
├── bitstream/
│
└── docs/
```

The FPGA source code and MicroPython firmware are organized independently, making it easier to modify or replace either side of the bridge.

## How It Works

The UART to SPI Bridge converts UART data into SPI transactions and returns the SPI response back through UART.

### System Architecture

```
                UART Host Device
                        │
                        ▼
                 +-------------+
                 |   UART RX   |
                 +-------------+
                        │
                        ▼
                 +-------------+
                 |   RX FIFO   |
                 +-------------+
                        │
                        ▼
              +------------------+
              | Bridge Controller|
              +------------------+
                        │
                        ▼
                 +-------------+
                 | SPI Master  |
                 +-------------+
                        │
                  SPI Peripheral
                        │
                        ▼
                 +-------------+
                 |   TX FIFO   |
                 +-------------+
                        │
                        ▼
              +------------------+
              | UART TX Handler  |
              +------------------+
                        │
                        ▼
                 +-------------+
                 |   UART TX   |
                 +-------------+
                        │
                        ▼
                UART Host Device
```

### Data Flow

#### Step 1 : UART Reception

The UART Receiver monitors the serial input line and converts the incoming UART frame into an 8-bit parallel data byte.

#### Step 2 : RX FIFO Buffering

The received byte is stored in the RX FIFO. This allows the UART and SPI modules to operate independently without losing data.

#### Step 3 : Bridge Controller

The Bridge Controller monitors the RX FIFO. When data is available, it:

1. Reads one byte from the RX FIFO.
2. Stores the byte internally.
3. Starts an SPI transaction.
4. Waits for the SPI transaction to complete.
5. Writes the SPI response into the TX FIFO.

#### Step 4 : SPI Communication

The SPI Master performs an 8-bit full duplex transfer using SPI Mode 0.

- CPOL = 0
- CPHA = 0
- MSB First

The transmitted byte is sent through MOSI while the received byte is captured through MISO.

#### Step 5 : TX FIFO Buffering

The SPI response is stored inside the TX FIFO until the UART transmitter is ready.

#### Step 6 : UART Transmission

The UART TX Handler reads the TX FIFO, starts the UART transmitter, and sends the SPI response back to the UART host.

### FIFO Usage

Two FIFOs are used in the design:

| FIFO | Purpose |
|------|----------|
| RX FIFO | Stores UART received data before SPI transfer |
| TX FIFO | Stores SPI received data before UART transmission |

The FIFOs decouple the UART and SPI modules, allowing them to operate at different speeds.

### Finite State Machines

The project uses multiple FSMs:

- UART Receiver FSM
- UART Transmitter FSM
- Bridge Controller FSM
- SPI Master FSM
- UART TX Handler FSM

This modular approach keeps the design easy to understand and extend.

## Expected Output

When the project is running correctly, the MicroPython firmware sends 100 bytes to the FPGA over UART.

The FPGA performs the following operations for each byte:

1. Receive UART data.
2. Store the data in the RX FIFO.
3. Start an SPI transaction.
4. Store the SPI response in the TX FIFO.
5. Send the response back through UART.

### Sample Serial Output

```text
100 BYTE UART-SPI BRIDGE TEST
--------------------------------
Sending: 0x0
Received: b'\x00'

Sending: 0x1
Received: b'\x00'

Sending: 0x2
Received: b'\x00'

...

Sending: 0x63
Received: b'\x00'

--------------------------------
Test Complete
Errors = 0
```

### Current Development Status

The UART to SPI Bridge communication path has been successfully validated.

The current implementation verifies:

- UART Reception
- RX FIFO Operation
- Bridge Controller FSM
- SPI Master FSM
- TX FIFO Operation
- UART Transmission

At this stage, the SPI slave peripheral is not implemented, therefore the expected response byte is `0x00`.

The design can be connected to compatible SPI peripherals such as sensors, memory devices, displays, or other SPI-enabled hardware for complete end-to-end validation.