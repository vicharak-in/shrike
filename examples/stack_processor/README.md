## Simple Stack Processor (SPI-Controlled)
This project implements a small stack-based processor written in Verilog HDL, designed to run on FPGA of Shrike and be controlled by onboard RP2040 through a Serial Peripheral Interface (SPI). Instead of using a conventional register-file–centric architecture, the processor relies on a Last-In, First-Out (LIFO) stack as its primary data storage and execution mechanism. The stack itself is implemented using on-chip Block RAM (BRAM), allowing efficient and deterministic push and pop operations.

All instructions are issued to the processor over SPI, where each received byte is decoded as a command that either manipulates the stack, transfers data between the stack and internal registers, or performs arithmetic and logic operations. By combining a simple SPI-controlled command interface with a BRAM-backed stack, the design provides a compact and easy-to-understand processing core that is well suited for learning, experimentation, and FPGA prototyping.


## Overview on FPGA side
1. The processor exposes a simple instruction set over SPI that allows:   
    - Pushing 4-bit values onto a stack
    - Popping values from the stack
    - Loading internal registers from the stack
    - Performing basic arithmetic and logic operations
    - Reading stack status and data via SPI
2. The top-level module (`top`) connects:
    - An SPI slave (`spi_target`)
    - A BRAM-based LIFO stack (`lifo_bram`)
    - Simple control logic implementing the instruction decoding and execution

### Internal Registers
The processor contains three 8-bit registers:
A, B, C.
Most arithmetic and logic operations use A and B as operands and store the result in C.

---

## Modules

1. `top` : The top-level module that:
    - Interfaces with SPI
    - Decodes instructions
    - Controls stack operations
    - Manages internal registers
2. `spi_target`: SPI slave module configured with:
    - CPOL = 0
    - CPHA = 0
    - 8-bit data width
    - MSB first
3. `lifo_bram` :  A BRAM-backed LIFO (stack) with:
    - BRAM-backed stack storage
    - Simple push (WE) and pop (RE) control
    - Empty and full status flags
    - 4-bit data width (easily extendable)
    - Synchronous operation with active-low reset

> **Note:**  
> The write operation in BRAM takes 1 cycle. The data is written in BRAM on the rising clock of 2<sup>nd</sup> cycle.
> The read operation in BRAM takes 2 cycle. The output data is valid in the 2<sup>nd</sup> cycle.

---

## LIFO BRAM Module Interface

| Signal        | Direction | Description                          |
|---------------|-----|--------------------------------------|
| `clk`         | In  | System clock (50 MHz typical)        |
| `nReset`      | In  | Active-low synchronous reset   |
| `DIN[3:0]`    | In  | Data to be pushed onto the stack |
| `WE`          | In  | Write enable (push operation)              |
| `RE`          | In  | Read enable (pop operation)             |
| `DOUT[3:0]`            | Out | Data popped from the stack  |
| `LIFO_full`            | Out | Asserted when stack is full              |
| `LIFO_empty`           | Out  | Asserted when stack is empty  |
| `BRAM0_RATIO[1:0]`     | Out | BRAM data ratio (fixed to `2'b00`) |
| `BRAM0_DATA_IN[7:0]`   | Out | Data written to BRAM (upper bits zeroed)              |
| `BRAM0_WEN`            | Out | Active-low write enable              |
| `BRAM0_WCLKEN`         | Out | Write clock enable (tied off)  |
| `BRAM0_WRITE_ADDR[8:0]`| Out | Write address              |
| `BRAM0_DATA_OUT[3:0]`  | In  | Data read from BRAM  |
| `BRAM0_REN`            | Out | Active-low read enable              |
| `BRAM0_RCLKEN`         | Out | Read clock enable (tied off)   |
| `BRAM0_READ_ADDR[8:0]` | Out | Read address |

---

**Make sure to enable BRAM. Here we are using BRAM0, so we enable only North BRAM** 

![Make sure to enable BRAM](assets\images\bram_en.JPG)

---

**BRAM0 Floorplan**

In the Verilog code the user can observe that only BRAM_0 has been used for this application. The floorplan of BRAM_0 should look something like image given below. 

![BRAM0 Floorplan](assets\images\bram0_fp.JPG)

For more information about BRAM check: 
- [Datasheet](https://www.renesas.com/en/document/dst/slg47910-datasheet?r=25546631)
- [FIFO BRAM example](https://www.renesas.com/en/document/apn/fg-011-fifo-using-bram?srsltid=AfmBOorkxiMLFTFX1kxDsPZrO7USStJ2QL_vjj5_Dv_yuWuQguJm1SbN)

---

## Top Module Interface

| Signal        | Direction | Description                    |
|---------------|-----|--------------------------------------|
| `clk`         | In  | System clock (50 MHz typical)        |
| `rst_n`       | In  | Reset Pin (active low)               |
| `spi_ss_n`    | In  | Input target select signal (activel low) |
| `spi_sck`     | In  | Input SPI clock signal               |
| `spi_mosi`    | In  | Input from controller                |
| `spi_miso`    | Out | Output to controller                 |
| + `BRAM PINS` |

---

## Pin Usage for Testing
This design was tested using configuration given below:

### FPGA 
| FPGA GPIO Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| 3        | spi_sck     | Input     | SPI clock                 |
| 4        | spi_ss_n    | Input     | chip select               |
| 5        | spi_mosi    | Input     | mosi (receiver) line      |
| 6        | spi_miso    | Output    | miso (transmission) line  |
| 18       | rst_n       | Input     | For Reseting the FPGA     |

### RP2040
| RP2040 Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| 2        | SCK         | Output    | SPI clock                         |
| 1        | CS          | Output    | chip select                       |
| 3        | MOSI        | Output    | Master output                     |
| 0        | MISO        | Input     | Master input                      |
| 14       | Reset       | Output    | reset signal (active low)         |

When testing using RP2040 MCU, first load the bitstream to FPGA then run the `multiplication.py`. The pin number in your FPGA constraints must match what is used in the micropython code.

---

**Instruction Set**

In this project, we have simple Instruciton Set. However user can modify it easily as per requirement.

|Opcode     | Function |
|-----------|----------|
|0000_0000 | Stall    |
|0001_XXXX | Push  (LSB : XXXX)   |
|0010_0000 | Pop      |
|0011_0000 | Push reg A |
|0011_0001 | Push reg B |
|0011_0010 | Push reg C |
|0011_0011 | Pop reg A |
|0011_0100 | Pop reg B |
|0011_0101 | Pop reg C |
|1100_0000 | Add ( C <= A + B )    |
|1100_0001 | Sub ( C <= A - B )    |
|1100_0010 | Mul ( C <= A * B )    |
|1100_0011 | DIV ( C <= A / B )    |
|1100_0100 | C = A << 1    |
|1100_0101 | C = A >> 1 (logical)  |
|1100_0110 | C = A >> 1 (arithmetic)   |

---

### SPI Communication (Multiplication Example)

**Input**
```text
0x12, # Push 2
0x15, # Push 5
0x33, # Pop A       (A = 5)
0x34, # Pop B       (A = 2)
0xC2, # C = A * B   (C = 5 * 2)
0x32, # Push C
0x20, # Pop
0x00, # Stall (For Reading via SPI)
```

**Output:**  
```text
Sent 0x12, Received 0x00
Sent 0x15, Received 0x00
Sent 0x33, Received 0x00
Sent 0x34, Received 0x00
Sent 0xC2, Received 0x00
Sent 0x32, Received 0x00
Sent 0x20, Received 0x00 (Poped output is send in next SPI transaction)
Sent 0x00, Received 0x8A (8: stack is empty, A: result)
```