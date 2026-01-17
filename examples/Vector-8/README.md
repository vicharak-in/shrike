# Vector - 8

This project implements a custom **8-bit Soft-Core CPU** on the Vicharak's **Shrike Lite** board. It serves as a hands-on introduction to Computer Architecture.

Expanding upon the Vector-4 architecture, this CPU doubles the data width and significantly expands the instruction set while maintaining a compact footprint under **140 CLBs**. It is controlled entirely via **SPI**, where the RP2040 acts as the master, sending 16-bit instruction packets and single-stepping the execution.

---

## System Architecture

The system follows a hybrid controller-target design:
* **RP2040 (Master):** Manages high-level logic, instruction sequencing, and user interface.
* **FPGA (Slave):** Contains the 8-bit CPU core (Accumulator-based), ALU, and status registers.

### Specifications
| Feature | Detail |
| :--- | :--- |
| **Data Width** | 8-bit (Full Byte) |
| **Instruction Set** | 32-ISA (5-bit Opcodes) |
| **Clocking** | Manual Stepping via SPI (Synchronous to FPGA System Clock) |
| **Interface** | 16-bit SPI Protocol (Double-Byte Packet) |

---

<img width="2816" height="1504" alt="8-bit_cpu" src="https://github.com/user-attachments/assets/f5d97bca-0007-4263-ad65-2c8b7dee1aeb" />

## The SPI Interface

To interact with the 8-bit core, the RP2040 sends **16-bit packets** (two 8-bit transfers). The FPGA assembles these into a single instruction and executes it on the rising edge of the internal step signal.

### Input Packet (RP2040 -> FPGA)
The instruction is sent across two bytes. 

**Byte 1: Command**
| Bit [7:5] | Bit [4:0] |
| :---: | :---: |
| **Unused** | **OPCODE** |
| - | 5-bit Instruction Identifier |

**Byte 2: Data**
| Bit [7:0] |
| :---: |
| **OPERAND / DATA** |
| 8-bit Immediate Value or Address |

### Output Packet (FPGA -> RP2040)
The FPGA replies with the current state of the Accumulator for verification. Because the SPI transfer occurs simultaneously with execution, the MISO line returns the result of the *previous* instruction.
| Bit [7:0] |
| :---: |
| **ACC (Accumulator Value)** |
| Current 8-bit result of the previous operation |

---

## Instruction Set Architecture (ISA)

The CPU supports an expanded set of 32 operations. Below are the primary validated opcodes.

| Opcode | Name | Description |
| :--- | :--- | :--- |
| `0x00` | **NOP** | No Operation |
| `0x01` | **LDA** | Load Accumulator with 8-bit Data |
| `0x02` | **ADD** | `Acc = Acc + Data` |
| `0x03` | **SUB** | `Acc = Acc - Data` |
| `0x04` | **AND** | Bitwise AND |
| `0x05` | **OR** | Bitwise OR |
| `0x06` | **XOR** | Bitwise XOR |
| `0x07` | **LSL** | Logical Shift Left |
| `0x08` | **LSR** | Logical Shift Right |
| `0x09` | **ROL** | Rotate Left |
| `0x0A` | **ROR** | Rotate Right |
| `0x0B` | **INC** | `Acc = Acc + 1` |
| `0x0C` | **DEC** | `Acc = Acc - 1` |
| `0x0D` | **JMP** | Jump to Address (Update PC) |
| `0x0E` | **JZ** | Jump to Address if Zero Flag is High |
| `0x0F` | **JNZ** | Jump to Address if Zero Flag is Low |

---

## Hardware Connections

### Top Module Interface
These signals correspond to the top-level Verilog module (`top.v`).

| Signal        | Direction | Description                                  |
|---------------|-----------|----------------------------------------------|
| `clk`         | In        | System clock (50 MHz typical)                |
| `clk_en`      | Out       | Clock enable (always 1)                      |
| `rst_n`       | In        | Reset Pin (active low)                       |
| `spi_ss_n`    | In        | Input target select signal (active low)      |
| `spi_sck`     | In        | Input SPI clock signal                       |
| `spi_mosi`    | In        | Input from controller (Master Out)           |
| `spi_miso`    | Out       | Output to controller (Master In)             |

### Pin Mapping Table

| Signal Function | FPGA Pin (GPIO) | RP2040 Pin | Direction |
| :--- | :---: | :---: | :--- |
| **SPI Clock** | 3 | 2 | RP2040 Output -> FPGA Input |
| **Chip Select** | 4 | 1 | RP2040 Output -> FPGA Input |
| **MOSI** | 5 | 3 | RP2040 Output -> FPGA Input |
| **MISO** | 6 | 0 | FPGA Output -> RP2040 Input |
| **Reset** | 18 | 14 | RP2040 Output -> FPGA Input |
