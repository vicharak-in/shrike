# Shrike-GPIO-14: 14-Bit FPGA I/O Expander

This project implements a custom **14-bit Bi-directional GPIO Expander** on the Vicharak **Shrike Lite** board. By leveraging the FPGA's logic fabric, this design allows the RP2040/RP2350 to control **14 additional independent pins** via a high-speed **SPI interface**. The FPGA pins support dynamic direction switching (Input/Output) and full read/write operations, effectively turning the FPGA into a versatile I/O expansion peripheral with nearly double the capacity of the 8-bit version.

---

## System Architecture

The system functions as a soft-command bridge between the microcontroller and the FPGA:

* **RP2040/RP2350 (Master):** Executes MicroPython firmware to send commands and read pin states over SPI.
* **FPGA (Slave):** Contains a custom GPIO architecture that manages internal registers and physical tristate buffers.

### Specifications

| Feature | Detail |
| :--- | :--- |
| **I/O Width** | 14 Independent Bi-directional Pins |
| **Interface** | SPI with 2-byte command protocol |
| **Data Transfer** | Multi-byte read support (high byte + low byte) |
| **Clocking** | Internal 50MHz Oscillator |
| **Logic Type** | Memory-mapped Register Control |
| **Max Speed** | 1 MHz SPI (tested), higher speeds possible |

---

## The SPI Protocol

The 14-bit GPIO system uses a **2-byte command protocol** for writes and a **2-byte read protocol** for reading all GPIO states.

### Write Operations (RP2040 -> FPGA)

Each write consists of **2 consecutive bytes**: Command Byte + Data Byte

| Command Byte | Function | Data Byte Format | Description |
| :---: | :--- | :--- | :--- |
| `0x10` | **Lower DIR** | `[7:0]` = Direction bits [7:0] | Set directions for pins 0-7 (1=Input, 0=Output) |
| `0x11` | **Upper DIR** | `[5:0]` = Direction bits [13:8] | Set directions for pins 8-13 (1=Input, 0=Output) |
| `0x20` | **Lower DATA** | `[7:0]` = Output data [7:0] | Drive logic levels for pins 0-7 |
| `0x21` | **Upper DATA** | `[5:0]` = Output data [13:8] | Drive logic levels for pins 8-13 |

**Example:** To set pins 0-7 as outputs and write `0xAA`:
```python
fpga.spi.write(bytes([0x10, 0x00]))  # Set pins 0-7 as outputs
fpga.spi.write(bytes([0x20, 0xAA]))  # Write 0xAA to pins 0-7
```

### Read Operations (FPGA -> RP2040)

Reading the GPIO state requires **2 separate SPI byte transfers** with delays between them:

1. **First transfer:** Reads high byte `[13:8]` (6 bits + 2 padding bits)
2. **Second transfer:** Reads low byte `[7:0]`

The FPGA automatically alternates between sending the high byte and low byte on consecutive transfers within the same CS transaction.

**Example MicroPython read:**
```python
cs.value(0)
time.sleep_us(20)
high_byte = spi.read(1, 0x00)[0]  # Read bits [13:8]
time.sleep_us(20)
low_byte = spi.read(1, 0x00)[0]   # Read bits [7:0]
time.sleep_us(20)
cs.value(1)

gpio_state = low_byte | ((high_byte & 0x3F) << 8)
```

---

## Hardware Connections

This design utilizes specific synthesis attributes (`iopad_external_pin`, `clkbuf_inhibit`) to ensure the Renesas ForgeFPGA hardware maps the logic correctly to the physical pads.

### Top Module Interface

These signals correspond to the top-level Verilog module (`top.v`):

| Signal | Direction | Description |
| :--- | :--- | :--- |
| `clk` | In | Internal 50 MHz Oscillator |
| `clk_en` | Out | OSC Enable (tied to `1'b1`) |
| `rst_n` | In | System Reset (Active Low) |
| `spi_ss_n` | In | SPI Slave Select (Active Low) |
| `spi_sck` | In | SPI Clock |
| `spi_mosi` | In | Master Out Slave In |
| `spi_miso` | Out | Master In Slave Out |
| `spi_miso_en` | Out | MISO Tristate Enable |

### SPI Pin Mapping

| Signal Function | FPGA Pin (Label) | RP2040/RP2350 Pin | Direction |
| :--- | :---: | :---: | :--- |
| **SPI Clock** | GPIO03 (Pin 2) | GPIO 2 | RP2040 -> FPGA |
| **Chip Select** | GPIO04 (Pin 17) | GPIO 1 | RP2040 -> FPGA |
| **MOSI** | GPIO05 (Pin 18) | GPIO 3 | RP2040 -> FPGA |
| **MISO** | GPIO06 (Pin 19) | GPIO 0 | FPGA -> RP2040 |
| **Reset** | GPIO16 (Pin 7) | (Connected via hardware) | System Reset |

### Target GPIO Mapping (14 Pins)

Each bit is mapped to its own physical GPIO resource in the I/O Planner:

| GPIO Bit | FPGA Internal Label | Physical Pin | Register Bit |
| :---: | :---: | :---: | :---: |
| 0 | GPIO0 | 13 | `gpio_out_reg[0]` |
| 1 | GPIO1 | 14 | `gpio_out_reg[1]` |
| 2 | GPIO2 | 15 | `gpio_out_reg[2]` |
| 3 | GPIO7 | 20 | `gpio_out_reg[3]` |
| 4 | GPIO8 | 23 | `gpio_out_reg[4]` |
| 5 | GPIO9 | 24 | `gpio_out_reg[5]` |
| 6 | GPIO10 | 1 | `gpio_out_reg[6]` |
| 7 | GPIO11 | 2 | `gpio_out_reg[7]` |
| 8 | GPIO12 | 3 | `gpio_out_reg[8]` |
| 9 | GPIO13 | 4 | `gpio_out_reg[9]` |
| 10 | GPIO14 | 5 | `gpio_out_reg[10]` |
| 11 | GPIO15 | 6 | `gpio_out_reg[11]` |
| 12 | GPIO17 | 8 | `gpio_out_reg[12]` |
| 13 | GPIO18 | 9 | `gpio_out_reg[13]` |

**Important:** In the I/O Planner, ensure `i_gpio_pins[x]`, `o_gpio_pins[x]`, and `o_gpio_en[x]` are **all mapped to the same physical GPIO index** for each bit.

---

## How to Use

### 1. FPGA Synthesis

1. **Load Files:** Import `top.v` and `spi_target.v` into Renesas Go Configure Software Hub
2. **I/O Planning:** In the I/O Planner, map each GPIO bit's `IN`, `OUT`, and `OE` signals to the same physical GPIO number (see table above)
3. **Synthesize:** Run Synthesis, and then Generate Bitstream on the ForgeFPGA
4. **Program:** Load the generated bitstream onto the Shrike Lite board

### 2. MicroPython Firmware

Upload the provided `fpga_gpio_14bit.py` to your RP2040/RP2350:

```python
from machine import Pin, SPI
import time

# Initialize
fpga = ShrikeFPGA14GPIO()

# Set pin directions (0=output, 1=input)
fpga.set_all_directions(0x0000)  # All outputs

# Write data
fpga.write_all(0x1234)  # Write 0x1234 to all 14 pins

# Read data
value = fpga.read_all()  # Returns 14-bit value
print(f"GPIO state: 0x{value:04X}")

# Individual pin control
fpga.set_pin_direction(0, is_input=False)  # Pin 0 as output
fpga.write_pin(0, 1)  # Set pin 0 HIGH
state = fpga.read_pin(0)  # Read pin 0
```

---
