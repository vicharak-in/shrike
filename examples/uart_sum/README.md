# Add Two 8-bit Numbers on FPGA and Return Result via UART
This project demonstrates UART-based communication between an RP2040 and an FPGA. Two 8-bit numbers are sent from the RP2040 to the FPGA over UART. The FPGA stores the received values, performs an addition operation, and then transmits the result back to the RP2040 using UART.

## Overview on FPGA side
- This project consists of three modules :   
    1) `top :` This module implements the FSM.
        - Continuously look for input data
        - Add the two 8 bit numbers.
        - Generate appropriate transmission signal onces summation is done.
    2) `uart_rx : ` This module implements a UART Receiver.
        - When the data is received, it makes "data valid" signal high.
    3) `uart_rx : ` This module implements a UART Transmitter.
        - When the start signal is given, it transmit the data present in its output buffer.

---

## Features
- Configurable `BAUD_RATE` 

---

## Top Module Interface

| Signal        | Direction | Description                          |
|---------------|-----|--------------------------------------|
| `clk`         | In  | System clock (50 MHz typical)        |
| `rst`        | In  | Reset Pin   |
| `rx`        | In | Receiver Line |
| `tx`  | Out | Transmission Line              |
| `tx_en`     | Out | Output enable for transmitter (always 1)              |
| `clk_en`      | Out | Clock enable (always 1)              |

---

## Parameters Used
#### `CLK :` 
- Parameter to represent the System clock frequency in Hz.
    -  `parameter CLK = 50_000_000`
#### `BAUD_RATE :` 
- Parameter to configure Baud Rate of UART communication.
     - `parameter BAUD_RATE = 115200`

---

## Pin Usage for Testing
This design was tested using configuration given below:

### FPGA 
| FPGA GPIO Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| 3       | Reset     | Input    | For Reseting the FPGA     |
| 4       | UART TX     | Input     | UART ouput to RP2040    |
| 6       | UART RX     | Output    | UART input from RP2040    |

### RP2040
| RP2040 Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| 1       | UART RX     | Input     | UART input from FPGA    |
| 0       | UART TX     | Output    | UART ouput to FPGA    |
| 2       | Reset     | Output    | MCU output for reseting the FPGA     |

When testing using RP2040 MCU, first load the bitstream to FPGA then run the `uart_sum.py`. The pin number in your FPGA constraints must match what is used in the micropython code.

---

## Expected Output in Thonny
![Expected Output in Thonny](ffpga/images/output.JPG "Expected Output")