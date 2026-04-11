# vector8_cpu

**Difficulty:** Advanced

**Uses MCU:** Yes

**External Hardware:** None

## Overview

This project implements a custom **8-bit Soft-Core CPU** on the Vicharak's **Shrike Lite** board. It serves as a hands-on introduction to Computer Architecture.

Expanding upon the Vector-4 architecture, this CPU doubles the data width and significantly expands the instruction set while maintaining a compact footprint under **140 CLBs**. It is controlled entirely via **SPI**, where the RP2040 acts as the master, sending 16-bit instruction packets and single-stepping the execution.

---

## Compatibility

| Board                | Firmware                | Status     |
| -------------------- | ----------------------- | ---------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested   |
| Shrike (RP2350)      | `firmware/micropython/` | ✅ Tested   |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

---

## Hardware Setup

No external hardware required.

---

## System Architecture

The system follows a hybrid controller-target design:

* **RP2040 (Master):** Manages high-level logic, instruction sequencing, and user interface
* **FPGA (Slave):** Contains the 8-bit CPU core (Accumulator-based), ALU, and status registers

### Specifications

| Feature         | Detail                                   |
| :-------------- | :--------------------------------------- |
| Data Width      | 8-bit (Full Byte)                        |
| Instruction Set | 32-ISA (5-bit Opcodes)                   |
| Clocking        | Manual stepping via SPI                  |
| Interface       | 16-bit SPI Protocol (Double-Byte Packet) |

---

## Architecture Diagram

<img width="2816" height="1504" alt="8-bit_cpu" src="https://github.com/user-attachments/assets/f5d97bca-0007-4263-ad65-2c8b7dee1aeb" />

---

## Quick Start (Pre-Built Bitstream)

1. Connect Shrike board via USB
2. Upload bitstream using ShrikeFlash
3. Run MicroPython firmware to send SPI instructions
4. Step execution cycle-by-cycle
5. Observe accumulator output via SPI

---

## Build From Source

### FPGA (Verilog)

1. Open `vector_cpu_8bit.ffpga` in Go Configure Software Hub
2. Add CPU, ALU, and SPI modules
3. Configure I/O mapping
4. Generate bitstream

### Firmware (MicroPython)

1. Send 16-bit instruction packets over SPI
2. Control execution flow (step/reset)
3. Read accumulator value from SPI

---

## How It Works

The CPU is fully controlled through SPI communication:

* Instructions are sent as 16-bit packets
* FPGA executes instruction on step trigger
* Result is returned via SPI (MISO)
* Execution is synchronous with system clock

---

## SPI Interface

### Input Packet (RP2040 → FPGA)

The instruction is sent across two bytes.

#### Byte 1: Command

| Bit [7:5] |           Bit [4:0]          |
| :-------: | :--------------------------: |
|   Unused  |            OPCODE            |
|     -     | 5-bit Instruction Identifier |

#### Byte 2: Data

|             Bit [7:0]            |
| :------------------------------: |
|          OPERAND / DATA          |
| 8-bit Immediate Value or Address |

---

### Output Packet (FPGA → RP2040)

|                Bit [7:0]               |
| :------------------------------------: |
|         ACC (Accumulator Value)        |
| Current result of previous instruction |

> SPI is full-duplex, so returned data corresponds to the **previous instruction execution**.

---

## Instruction Set Architecture (ISA)

| Opcode | Name | Description                |
| :----- | :--- | :------------------------- |
| `0x00` | NOP  | No Operation               |
| `0x01` | LDA  | Load Accumulator with Data |
| `0x02` | ADD  | `Acc = Acc + Data`         |
| `0x03` | SUB  | `Acc = Acc - Data`         |
| `0x04` | AND  | Bitwise AND                |
| `0x05` | OR   | Bitwise OR                 |
| `0x06` | XOR  | Bitwise XOR                |
| `0x07` | LSL  | Logical Shift Left         |
| `0x08` | LSR  | Logical Shift Right        |
| `0x09` | ROL  | Rotate Left                |
| `0x0A` | ROR  | Rotate Right               |
| `0x0B` | INC  | `Acc = Acc + 1`            |
| `0x0C` | DEC  | `Acc = Acc - 1`            |
| `0x0D` | JMP  | Jump to Address            |
| `0x0E` | JZ   | Jump if Zero flag is High  |
| `0x0F` | JNZ  | Jump if Zero flag is Low   |

---

## Hardware Connections

### Top Module Interface

| Signal     | Direction | Description                   |
| ---------- | --------- | ----------------------------- |
| `clk`      | In        | System clock (50 MHz typical) |
| `clk_en`   | Out       | Always 1                      |
| `rst_n`    | In        | Reset (active low)            |
| `spi_ss_n` | In        | Chip select                   |
| `spi_sck`  | In        | SPI clock                     |
| `spi_mosi` | In        | Input from controller         |
| `spi_miso` | Out       | Output to controller          |

---

### Pin Mapping Table

| Signal Function | FPGA Pin (GPIO) | RP2040 Pin | Direction     |
| :-------------- | :-------------: | :--------: | :------------ |
| SPI Clock       |        3        |      2     | RP2040 → FPGA |
| Chip Select     |        4        |      1     | RP2040 → FPGA |
| MOSI            |        5        |      3     | RP2040 → FPGA |
| MISO            |        6        |      0     | FPGA → RP2040 |
| Reset           |        18       |     14     | RP2040 → FPGA |

---

## Expected Output

* CPU executes instructions step-by-step
* Accumulator updates based on operations
* Result is returned via SPI after each instruction
* Execution is fully controlled by RP2040

---

## Notes

* Compact design (~140 CLBs)
* Fully software-driven CPU control
* Demonstrates:

  * CPU architecture scaling (4-bit → 8-bit)
  * Instruction decoding
  * ALU operations
  * SPI-based control interface
