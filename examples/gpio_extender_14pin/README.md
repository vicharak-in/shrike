# gpio_bridge_14bit

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** None

## Overview

This project implements a custom **14-bit Bi-directional GPIO Expander** on the Vicharak Shrike Lite board. By leveraging the FPGA's logic fabric, this design allows the RP2040/RP2350 to control **14 additional independent pins** via a high-speed SPI interface.

The FPGA pins support dynamic direction switching (Input/Output) and full read/write operations, effectively turning the FPGA into a versatile I/O expansion peripheral with nearly double the capacity of the 8-bit version.

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

* **RP2040/RP2350 (Master):** Executes MicroPython firmware to send commands and read pin states over SPI
* **FPGA (Slave):** Contains a custom GPIO architecture that manages internal registers and physical tristate buffers

### Specifications

| Feature       | Detail                                         |
| :------------ | :--------------------------------------------- |
| I/O Width     | 14 Independent Bi-directional Pins             |
| Interface     | SPI with 2-byte command protocol               |
| Data Transfer | Multi-byte read support (high byte + low byte) |
| Clocking      | Internal 50MHz Oscillator                      |
| Logic Type    | Memory-mapped Register Control                 |
| Max Speed     | 1 MHz SPI (tested), higher speeds possible     |

---

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike board via USB
2. Upload the generated bitstream using ShrikeFlash
3. Run MicroPython firmware on RP2040/RP2350
4. Send SPI commands to configure GPIO direction and values
5. Expected result: FPGA GPIO pins behave as configurable 14-bit I/O

---

## Build From Source

### FPGA (Verilog)

1. Import `top.v` and `spi_target.v` into Go Configure Software Hub
2. Configure I/O Planner
3. Generate bitstream

### Firmware (MicroPython)

1. Upload `fpga_gpio_14bit.py`
2. Initialize SPI and interface class
3. Send commands and read GPIO state

---

## How It Works

The FPGA implements a memory-mapped GPIO system controlled via SPI. Each GPIO pin is internally split into:

* Input
* Output
* Output Enable (OE)

This allows true bidirectional control.

---

## SPI Protocol

### Write Operations (RP2040 → FPGA)

Each write consists of **2 consecutive bytes**:

| Command Byte | Function   | Data Byte Format                | Description                      |
| :----------: | :--------- | :------------------------------ | :------------------------------- |
|    `0x10`    | Lower DIR  | `[7:0]` = Direction bits [7:0]  | Set pins 0–7 (1=Input, 0=Output) |
|    `0x11`    | Upper DIR  | `[5:0]` = Direction bits [13:8] | Set pins 8–13                    |
|    `0x20`    | Lower DATA | `[7:0]` = Output data [7:0]     | Drive pins 0–7                   |
|    `0x21`    | Upper DATA | `[5:0]` = Output data [13:8]    | Drive pins 8–13                  |

Example:

```python id="a7k9sd"
fpga.spi.write(bytes([0x10, 0x00]))  # Set pins 0-7 as outputs
fpga.spi.write(bytes([0x20, 0xAA]))  # Write 0xAA to pins 0-7
```

---

### Read Operations (FPGA → RP2040)

Reading requires **2 SPI transfers**:

1. First → high byte `[13:8]`
2. Second → low byte `[7:0]`

Example:

```python id="x92kdf"
cs.value(0)
time.sleep_us(20)
high_byte = spi.read(1, 0x00)[0]
time.sleep_us(20)
low_byte = spi.read(1, 0x00)[0]
time.sleep_us(20)
cs.value(1)

gpio_state = low_byte | ((high_byte & 0x3F) << 8)
```

---

## Hardware Connections

### Top Module Interface

| Signal        | Direction | Description                   |
| :------------ | :-------- | :---------------------------- |
| `clk`         | In        | Internal 50 MHz Oscillator    |
| `clk_en`      | Out       | OSC Enable (tied to `1'b1`)   |
| `rst_n`       | In        | System Reset (Active Low)     |
| `spi_ss_n`    | In        | SPI Slave Select (Active Low) |
| `spi_sck`     | In        | SPI Clock                     |
| `spi_mosi`    | In        | Master Out Slave In           |
| `spi_miso`    | Out       | Master In Slave Out           |
| `spi_miso_en` | Out       | MISO Tristate Enable          |

---

### SPI Pin Mapping

| Signal Function | FPGA Pin (Label) |     RP2040/RP2350 Pin    | Direction     |
| :-------------- | :--------------: | :----------------------: | :------------ |
| SPI Clock       |  GPIO03 (Pin 2)  |          GPIO 2          | RP2040 → FPGA |
| Chip Select     |  GPIO04 (Pin 17) |          GPIO 1          | RP2040 → FPGA |
| MOSI            |  GPIO05 (Pin 18) |          GPIO 3          | RP2040 → FPGA |
| MISO            |  GPIO06 (Pin 19) |          GPIO 0          | FPGA → RP2040 |
| Reset           |  GPIO16 (Pin 7)  | (Connected via hardware) | System Reset  |

---

### Target GPIO Mapping (14 Pins)

| GPIO Bit | FPGA Internal Label | Physical Pin |    Register Bit    |
| :------: | :-----------------: | :----------: | :----------------: |
|     0    |        GPIO0        |      13      |  `gpio_out_reg[0]` |
|     1    |        GPIO1        |      14      |  `gpio_out_reg[1]` |
|     2    |        GPIO2        |      15      |  `gpio_out_reg[2]` |
|     3    |        GPIO7        |      20      |  `gpio_out_reg[3]` |
|     4    |        GPIO8        |      23      |  `gpio_out_reg[4]` |
|     5    |        GPIO9        |      24      |  `gpio_out_reg[5]` |
|     6    |        GPIO10       |       1      |  `gpio_out_reg[6]` |
|     7    |        GPIO11       |       2      |  `gpio_out_reg[7]` |
|     8    |        GPIO12       |       3      |  `gpio_out_reg[8]` |
|     9    |        GPIO13       |       4      |  `gpio_out_reg[9]` |
|    10    |        GPIO14       |       5      | `gpio_out_reg[10]` |
|    11    |        GPIO15       |       6      | `gpio_out_reg[11]` |
|    12    |        GPIO17       |       8      | `gpio_out_reg[12]` |
|    13    |        GPIO18       |       9      | `gpio_out_reg[13]` |

**Important:** Ensure `i_gpio_pins[x]`, `o_gpio_pins[x]`, and `o_gpio_en[x]` are mapped to the same physical GPIO index.

---

## Expected Output

* RP2040/RP2350 can configure GPIO directions dynamically
* Output pins reflect written values via SPI
* Input pins can be read back through SPI transactions
* Full 14-bit state can be reconstructed from two-byte read

---

## Notes

* Requires careful OE control due to FPGA architecture
* SPI operates in full-duplex mode
* Supports scalable GPIO expansion using FPGA fabric
