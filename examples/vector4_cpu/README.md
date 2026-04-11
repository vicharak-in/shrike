# vector4_cpu

**Difficulty:** Advanced

**Uses MCU:** Yes

**External Hardware:** None

## Overview

This project implements a custom **4-bit Soft-Core CPU** on the Vicharak's **Shrike Lite** board.

Instead of using physical buttons and LEDs, this CPU is controlled entirely via **SPI**. The RP2040 acts as the master, sending instructions, loading memory, and single-stepping the clock.

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

The system is a hybrid design:

* **RP2040 (Master):** Handles high-level logic, user interface, and CPU control
* **FPGA (Slave):** Implements CPU core, memory, and ALU

### Specifications

| Feature       | Detail                               |
| :------------ | :----------------------------------- |
| Data Width    | 4-bit (Nibble)                       |
| Address Space | 16 Program Memory + 16 Data Memory   |
| Clocking      | Manual stepping via SPI              |
| Interface     | 8-bit SPI Packet (Command + Payload) |

---

## Architecture Diagram

<img width="2816" height="1536" alt="Vector-4 Schematic" src="https://github.com/user-attachments/assets/e860ca24-936c-403d-bab5-7254de5bde37" />

---

## Quick Start (Pre-Built Bitstream)

1. Connect Shrike board via USB
2. Upload bitstream using ShrikeFlash
3. Run MicroPython firmware to send SPI commands
4. Load program and step CPU execution
5. Observe CPU state via SPI response

---

## Build From Source

### FPGA (Verilog)

1. Open `vector_cpu_4bit.ffpga` in Go Configure Software Hub
2. Add CPU, memory, and SPI modules
3. Configure I/O mapping
4. Generate bitstream

### Firmware (MicroPython)

1. Use SPI to send instruction packets
2. Implement control logic (load, step, reset)
3. Read CPU state via MISO

---

## How It Works

The CPU is controlled entirely through SPI packets sent by the RP2040.

* Instructions and data are loaded into memory
* Execution is controlled via single-step clocking
* CPU state is returned via SPI

---

## SPI Interface

### Input Packet (RP2040 → FPGA)

|   Bit [7:4]  |   Bit [3:2]   |    Bit [1]    |      Bit [0]      |
| :----------: | :-----------: | :-----------: | :---------------: |
| DATA Payload |  INSTRUCTION  |     RESET     |        STEP       |
|  4-bit Value | Mode Selector | 1 = Reset CPU | 1 = Execute Cycle |

#### Instruction Encoding

* `00` → LOADPROG → Write payload to Program Memory
* `01` → LOADDATA → Write payload to Data Memory
* `10` → SETRUNPT → Set Program Counter
* `11` → RUNPROG → Execute program

#### Control Bits

* RESET → Clears PC, registers, memory
* STEP → Executes one CPU cycle

---

### Output Packet (FPGA → RP2040)

|  Bit [7:4]  |    Bit [3:0]    |
| :---------: | :-------------: |
|    REGVAL   |        PC       |
| Accumulator | Program Counter |

---

## Instruction Set Architecture (ISA)

| Opcode | Name     | Description                     |    |    |
| :----- | :------- | :------------------------------ | -- | -- |
| 0      | LOAD     | `Reg = Data[PC]`                |    |    |
| 1      | STORE    | `Data[Address] = Reg`           |    |    |
| 2      | ADD      | `Reg = Reg + Data[PC]`          |    |    |
| 3      | MUL      | `Reg = Reg * Data[PC]`          |    |    |
| 4      | SUB      | `Reg = Reg - Data[PC]`          |    |    |
| 5      | SHIFTL   | Left Shift                      |    |    |
| 6      | SHIFTR   | Right Shift                     |    |    |
| 7      | JUMPTOIF | Conditional jump (MSB of input) |    |    |
| 8      | LOGICAND | Logical AND (`&&`)              |    |    |
| 9      | LOGICOR  | Logical OR (`                   |    | `) |
| 10     | EQUALS   | `Reg == Data[PC]`               |    |    |
| 11     | NEQ      | `Reg != Data[PC]`               |    |    |
| 12     | BITAND   | Bitwise AND (`&`)               |    |    |
| 13     | BITOR    | Bitwise OR (`                   | `) |    |
| 14     | LOGICNOT | Logical NOT (`!`)               |    |    |
| 15     | BITNOT   | Bitwise NOT (`~`)               |    |    |

---

## Hardware Connections

### Top Module Interface

| Signal     | Direction | Description           |
| ---------- | --------- | --------------------- |
| `clk`      | In        | System clock (50 MHz) |
| `clk_en`   | Out       | Always 1              |
| `rst_n`    | In        | Reset (active low)    |
| `spi_ss_n` | In        | Chip select           |
| `spi_sck`  | In        | SPI clock             |
| `spi_mosi` | In        | Input from controller |
| `spi_miso` | Out       | Output to controller  |

---

### Pin Mapping

| Signal Function | FPGA Pin | RP2040 Pin | Direction     |
| :-------------- | :------: | :--------: | :------------ |
| SPI Clock       |     3    |      2     | RP2040 → FPGA |
| Chip Select     |     4    |      1     | RP2040 → FPGA |
| MOSI            |     5    |      3     | RP2040 → FPGA |
| MISO            |     6    |      0     | FPGA → RP2040 |
| Reset           |    18    |     14     | RP2040 → FPGA |

---

## Expected Output

* CPU executes instructions step-by-step
* Accumulator and PC values are returned via SPI
* Programs can be loaded and executed dynamically

---

## Notes

* Fully software-controlled CPU (no physical IO required)
* Ideal for understanding:

  * CPU architecture
  * Instruction execution
  * Hardware/software co-design
* SPI acts as both control and debug interface
