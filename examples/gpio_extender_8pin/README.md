# gpio_extender_8bit

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** None

## Overview

This project implements a custom **8-bit Bi-directional GPIO Expander** on the Vicharak Shrike Lite board.

By leveraging the FPGA's logic fabric, this design allows the RP2040 to control 8 additional independent pins via a high-speed SPI interface. The FPGA pins support dynamic direction switching (Input/Output) and manual read/write operations, effectively turning the FPGA into a versatile I/O expansion peripheral.

## Compatibility

| Board                | Firmware                | Status     |
| -------------------- | ----------------------- | ---------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested   |
| Shrike (RP2350)      | `firmware/micropython/` | ✅ Tested   |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required.

### System Architecture

The system functions as a soft-command bridge between the microcontroller and the FPGA:

* **RP2040 (Master):** Executes MicroPython/C++ firmware to send commands and read pin states
* **FPGA (Slave):** Contains a custom GPIO architecture that manages internal registers and physical tristate buffers

### Specifications

| Feature    | Detail                                   |
| :--------- | :--------------------------------------- |
| I/O Width  | 8 Independent Bi-directional Pins        |
| Interface  | 8-bit SPI (Address Nibble + Data Nibble) |
| Clocking   | Internal 50MHz Oscillator                |
| Logic Type | Memory-mapped Register Control           |

---

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike board via USB
2. Upload the generated bitstream using ShrikeFlash
3. Run MicroPython firmware on RP2040
4. Send SPI commands to configure GPIO direction and values
5. Expected result: FPGA GPIO pins respond as configurable input/output pins

---

## Build From Source

### FPGA (Verilog)

1. Load `top.v` and `spi_target.v` into Go Configure Software Hub
2. Configure I/O Planner
3. Generate bitstream

### Firmware (MicroPython / C++)

1. Initialize SPI on RP2040
2. Send 8-bit command packets
3. Read back GPIO state via MISO

---

## How It Works

The FPGA implements a memory-mapped GPIO system controlled via SPI. Each GPIO pin is split into three internal signals:

* Input
* Output
* Output Enable (OE)

This allows true bidirectional behavior per pin.

The RP2040 sends commands using an 8-bit packet format:

```
{Address[3:0], Data[3:0]}
```

### SPI Input Packet (RP2040 → FPGA)

| Address | Function   | Description                                       |
| :-----: | :--------- | :------------------------------------------------ |
|  `0x1`  | Lower DIR  | Set directions for Pins [3:0] (1=Input, 0=Output) |
|  `0x2`  | Upper DIR  | Set directions for Pins [7:4] (1=Input, 0=Output) |
|  `0x3`  | Lower DATA | Drive logic levels for Pins [3:0]                 |
|  `0x4`  | Upper DATA | Drive logic levels for Pins [7:4]                 |

### SPI Output Packet (FPGA → RP2040)

During each SPI transfer, the FPGA returns an 8-bit value representing the current logic state of all GPIO pins. This allows the MCU to poll inputs while issuing commands.

---

## Hardware Connections

### Top Module Interface

| Signal        | Direction | Description                |
| :------------ | :-------- | :------------------------- |
| `clk`         | In        | Internal 50 MHz Oscillator |
| `clk_en`      | Out       | OSC Enable (tied to 1'b1)  |
| `rst_n`       | In        | System Reset (Active Low)  |
| `spi_ss_n`    | In        | SPI Slave Select           |
| `spi_sck`     | In        | SPI Clock                  |
| `spi_mosi`    | In        | Master Out Slave In        |
| `spi_miso`    | Out       | Master In Slave Out        |
| `spi_miso_en` | Out       | MISO Tristate Enable       |

### SPI Pin Mapping

| Signal Function | FPGA Pin (Label) | RP2040 Pin | Direction     |
| :-------------- | :--------------: | :--------: | :------------ |
| SPI Clock       |  GPIO03 (Pin 2)  |      2     | RP2040 → FPGA |
| Chip Select     |  GPIO04 (Pin 17) |      1     | RP2040 → FPGA |
| MOSI            |  GPIO05 (Pin 18) |      3     | RP2040 → FPGA |
| MISO            |  GPIO06 (Pin 19) |      0     | FPGA → RP2040 |
| Reset           |  GPIO18 (Pin 9)  |     14     | RP2040 → FPGA |

### Target GPIO Mapping

| GPIO Bit | FPGA Label | Physical Pin |
| :------: | :--------: | :----------: |
|     0    |   GPIO07   |      20      |
|     1    |   GPIO08   |      23      |
|     2    |   GPIO09   |      24      |
|     3    |   GPIO10   |       1      |
|     4    |   GPIO11   |       2      |
|     5    |   GPIO12   |       3      |
|     6    |   GPIO13   |       4      |
|     7    |   GPIO14   |       5      |

> Ensure `i_gpio_pins[x]`, `o_gpio_pins[x]`, and `o_gpio_en[x]` are mapped to the same physical GPIO index in the I/O planner.

---

## Expected Output

* RP2040 can configure GPIO pins as input or output dynamically
* Output pins reflect values written via SPI
* Input pins can be read back through SPI MISO line

---

## Notes

* Requires correct OE handling due to ForgeFPGA architecture
* SPI operates as full-duplex (simultaneous read/write)
* Ensure correct pin mapping in I/O planner
