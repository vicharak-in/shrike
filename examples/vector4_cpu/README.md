# Vector - 4

This project implements a custom **4-bit Soft-Core CPU** on the Vicharak's **Shrike Lite** board. 

Instead of using physical buttons and LEDs, this CPU is controlled entirely via **SPI**. The RP2040 acts as the master, sending instructions, loading memory, and single-stepping the clock.

---

## System Architecture

The system is a hybrid design:
* **RP2040 (Master):** Handles the high-level logic, user interface, and controls the CPU execution.
* **FPGA (Slave):** Contains the CPU core, memory (RAM/ROM), and ALU.

### Specifications
| Feature | Detail |
| :--- | :--- |
| **Data Width** | 4-bit (Nibble) |
| **Address Space** | 16 lines of Program Memory, 16 slots of Data Memory |
| **Clocking** | Manual Stepping via SPI (Synchronous to FPGA System Clock) |
| **Interface** | 8-bit SPI Packet (Command + Payload) |

---
<img width="2816" height="1536" alt="Vector-4 Schematic" src="https://github.com/user-attachments/assets/e860ca24-936c-403d-bab5-7254de5bde37" />

## The SPI Interface

To interact with the CPU, the RP2040 sends **8-bit packets** over SPI. The FPGA replies simultaneously with the current CPU state.

### Input Packet (RP2040 -> FPGA)
| Bit [7:4] | Bit [3:2] | Bit [1] | Bit [0] |
| :---: | :---: | :---: | :---: |
| **DATA Payload** | **INSTRUCTION** | **RESET** | **STEP** |
| 4-bit Value | Mode Selector | 1 = Reset CPU | 1 = Execute Cycle |

* **DATA Payload:** The number to be loaded into memory or the PC.
* **INSTRUCTION:**
    * `00` **LOADPROG**: Write payload to Program Memory at current PC.
    * `01` **LOADDATA**: Write payload to Data Memory at current PC.
    * `10` **SETRUNPT**: Set the Program Counter (PC) to the payload value.
    * `11` **RUNPROG**: Normal execution mode.
* **RESET:** Active High. Clears PC, Registers, and Memory.
* **STEP:** Rising-edge trigger. The CPU executes **one cycle** per packet where this bit is `1`.

### Output Packet (FPGA -> RP2040)
| Bit [7:4] | Bit [3:0] |
| :---: | :---: |
| **REGVAL** | **PC** |
| Current Accumulator Value | Current Program Counter |

---

## Instruction Set Architecture (ISA)

The CPU supports 16 operations. These opcodes are stored in the **Program Memory**.

| Opcode | Name | Description |
| :--- | :--- | :--- |
| `0` | **LOAD** | `Reg = Data[PC]` (Immediate Load) |
| `1` | **STORE** | `Data[Address] = Reg` (Indirect Store) |
| `2` | **ADD** | `Reg = Reg + Data[PC]` |
| `3` | **MUL** | `Reg = Reg * Data[PC]` |
| `4` | **SUB** | `Reg = Reg - Data[PC]` |
| `5` | **SHIFTL** | Left Shift |
| `6` | **SHIFTR** | Right Shift |
| `7` | **JUMPTOIF**| Jump to `Data[PC]` if the MSB of Input (Bit 7) is High |
| `8` | **LOGICAND**| Logical AND (`&&`) |
| `9` | **LOGICOR** | Logical OR (`\|\|`) |
| `10`| **EQUALS** | `Reg = (Reg == Data[PC])` |
| `11`| **NEQ** | `Reg = (Reg != Data[PC])` |
| `12`| **BITAND** | Bitwise AND (`&`) |
| `13`| **BITOR** | Bitwise OR (`\|`) |
| `14`| **LOGICNOT**| Logical NOT (`!`) |
| `15`| **BITNOT** | Bitwise NOT (`~`) |

---

## Hardware Connections

This design was tested using the following connections between the Shrike Lite FPGA (Slave) and the RP2040 (Master).

### Top Module Interface
These signals correspond to the top-level Verilog module (`top.v`).

| Signal        | Direction | Description                          |
|---------------|-----------|--------------------------------------|
| `clk`         | In        | System clock (50 MHz typical)        |
| `clk_en`      | Out       | Clock enable (always 1)              |
| `rst_n`       | In        | Reset Pin (active low)               |
| `spi_ss_n`    | In        | Input target select signal (active low) |
| `spi_sck`     | In        | Input SPI clock signal               |
| `spi_mosi`    | In        | Input from controller (Master Out)   |
| `spi_miso`    | Out       | Output to controller (Master In)     |

### Pin Mapping Table

| Signal Function | FPGA Pin (GPIO) | RP2040 Pin | Direction |
| :--- | :---: | :---: | :--- |
| **SPI Clock** | 3 | 2 | RP2040 Output -> FPGA Input |
| **Chip Select** | 4 | 1 | RP2040 Output -> FPGA Input |
| **MOSI** | 5 | 3 | RP2040 Output -> FPGA Input |
| **MISO** | 6 | 0 | FPGA Output -> RP2040 Input |
| **Reset** | 18 | 14 | RP2040 Output -> FPGA Input |
