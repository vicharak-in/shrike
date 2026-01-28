# Shrike-GPIO: 8-Bit FPGA I/O Expander

This project implements a custom **8-bit Bi-directional GPIO Expander** on the Vicharak **Shrike Lite** board. 

By leveraging the FPGA's logic fabric, this design allows the RP2040 to control 8 additional independent pins via a high-speed **SPI interface**. The FPGA pins support dynamic direction switching (Input/Output) and manual read/write operations, effectively turning the FPGA into a versatile I/O expansion peripheral.

---

## System Architecture

The system functions as a soft-command bridge between the microcontroller and the FPGA:
* **RP2040 (Master):** Executes MicroPython/C++ firmware to send commands and read pin states.
* **FPGA (Slave):** Contains a custom GPIO architecture that manages internal registers and physical tristate buffers.

### Specifications
| Feature | Detail |
| :--- | :--- |
| **I/O Width** | 8 Independent Bi-directional Pins |
| **Interface** | 8-bit SPI (Address Nibble + Data Nibble) |
| **Clocking** | Internal 50MHz Oscillator |
| **Logic Type** | Memory-mapped Register Control |

---

## The SPI Interface

To interact with the GPIOs, the RP2040 sends **8-bit packets** over SPI. Because the Renesas ForgeFPGA requires manual Output Enable (OE) management, the FPGA logic splits each physical pin into three internal signals: **Input**, **Output**, and **OE**.

### Input Packet (RP2040 -> FPGA)
The packet is structured as `{Address[3:0], Data[3:0]}`:

| Address Nibble | Function | Description |
| :---: | :--- | :--- |
| `0x1` | **Lower DIR** | Set Directions for Pins [3:0] (1=Input, 0=Output) |
| `0x2` | **Upper DIR** | Set Directions for Pins [7:4] (1=Input, 0=Output) |
| `0x3` | **Lower DATA**| Drive logic levels (High/Low) for Pins [3:0] |
| `0x4` | **Upper DATA**| Drive logic levels (High/Low) for Pins [7:4] |

### Output Packet (FPGA -> RP2040)
During every SPI transfer, the FPGA shifts out an 8-bit byte reflecting the **current physical logic state** of the 8 GPIO pins. This allows the RP2040 to "poll" the inputs while sending new output commands.



---

## Hardware Connections

This design utilizes specific synthesis attributes to ensure the Renesas ForgeFPGA hardware maps the logic correctly to the physical pads.

### Top Module Interface
These signals correspond to the top-level Verilog module (`top.v`).

| Signal | Direction | Description |
| :--- | :--- | :--- |
| `clk` | In | Internal 50 MHz Oscillator |
| `clk_en` | Out | OSC Enable (tied to 1'b1) |
| `rst_n` | In | System Reset (Active Low) |
| `spi_ss_n` | In | SPI Slave Select |
| `spi_sck` | In | SPI Clock |
| `spi_mosi` | In | Master Out Slave In |
| `spi_miso` | Out | Master In Slave Out |
| `spi_miso_en`| Out | MISO Tristate Enable |

### Pin Mapping Table

| Signal Function | FPGA Pin (Label) | RP2040 Pin | Direction |
| :--- | :---: | :---: | :--- |
| **SPI Clock** | GPIO03 (Pin 2) | 2 | RP2040 -> FPGA |
| **Chip Select** | GPIO04 (Pin 17) | 1 | RP2040 -> FPGA |
| **MOSI** | GPIO05 (Pin 18) | 3 | RP2040 -> FPGA |
| **MISO** | GPIO06 (Pin 19) | 0 | FPGA -> RP2040 |
| **Reset** | GPIO18 (Pin 9) | 14 | RP2040 -> FPGA |

### Target GPIO Mapping
To maintain independent control, each bit is mapped to its own physical GPIO resource in the I/O Planner:

| GPIO Bit | FPGA Label | Physical Pin |
| :---: | :---: | :---: |
| 0 | GPIO07 | 20 |
| 1 | GPIO08 | 23 |
| 2 | GPIO09 | 24 |
| 3 | GPIO10 | 1 |
| 4 | GPIO11 | 2 |
| 5 | GPIO12 | 3 |
| 6 | GPIO13 | 4 |
| 7 | GPIO14 | 5 |

---

## How to Use

1. **Synthesize:** Load `top.v` and `spi_target.v` into the Renesas Go Configure tool.
2. **I/O Planning:** Ensure `i_gpio_pins[x]`, `o_gpio_pins[x]`, and `o_gpio_en[x]` are all mapped to the same physical GPIO index in the planner.
3. **Firmware:** Use MicroPython on the RP2040 to send 8-bit SPI commands using the address/data nibble format described above.
