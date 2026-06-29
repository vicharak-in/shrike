# cordic_coprocessor
**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

## Overview
A 4-mode fixed-point math coprocessor implemented on the shrike lite. The RP2040 sends a single 8-bit SPI command and reads back the result on the next transaction. Three modes use a CORDIC circular rotation engine for sine, cosine, and tangent. The fourth mode is a shift-and-add integer multiplier. All arithmetic runs in Q1.6 fixed-point, valid for angles from 0 to 45 degrees.

## Compatibility
| Board                | Firmware                | Status        |
| -------------------- | ----------------------- | ------------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested     |
| Shrike (RP2350)      | `firmware/micropython/` | ⬜ Untested   |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested   |

> FPGA bitstream is the same across all boards.

## Hardware Setup
No external hardware required.

### FPGA

| FPGA GPIO Pin | Signal   | Direction | Description |
| ------------- | -------- | --------- | ----------- |
| 3             | spi_sck  | Input     | SPI clock   |
| 4             | spi_ss_n | Input     | Chip select |
| 5             | spi_mosi | Input     | MOSI        |
| 6             | spi_miso | Output    | MISO        |
| 18            | rst_n    | Input     | Reset       |

---

### RP2040

| RP2040 Pin | Signal | Direction | Description   |
| ---------- | ------ | --------- | ------------- |
| 2          | SCK    | Output    | SPI clock     |
| 1          | CS     | Output    | Chip select   |
| 3          | MOSI   | Output    | Master output |
| 0          | MISO   | Input     | Master input  |
| 14         | Reset  | Output    | Reset         |

> Ensure pin mapping in FPGA constraints matches firmware configuration.

---

## Quick Start (Pre-Built Bitstream)
1. Connect Shrike Lite via USB
2. Upload `bitstream/cordic_coprocessor.bin` using ShrikeFlash
3. Run `test_cordic.py` on the RP2040
4. Enter a mode (`cos`, `sin`, `tan`, `mul`) and provide the operand

---

## Build From Source

### FPGA (Verilog)
1. Open project in Go Configure Software Hub
2. Add modules: `top`, `cordic_circular`, `cordic_divide`, `cordic_multiply`, `spi_target`
3. Configure I/O mapping
4. Generate bitstream

### Firmware (MicroPython)
1. Use SPI to send instruction bytes
2. Observe returned values

---

## How It Works

### Packet Format
The RP2040 sends one 8-bit command byte. The top 2 bits select the mode, the lower 6 bits carry the operand.

```
[ 7:6 ]  mode select
[ 5:0 ]  operand

Trig  : bits[5:0] = angle in Q1.6  (valid range: 0 to 45 degrees)
MUL   : bits[5:3] = operand A (3-bit signed), bits[2:0] = operand B (3-bit signed)
```

### Modes
| Mode | Operation | Engine                          |
| ---- | --------- | ------------------------------- |
| 00   | Cosine    | CORDIC circular rotation        |
| 01   | Sine      | CORDIC circular rotation        |
| 10   | Multiply  | Shift-and-add (3-bit operands)  |
| 11   | Tangent   | Cascaded sin/cos divider        |

### Module Breakdown

#### `top`
Decodes the incoming SPI byte, generates a one-cycle start strobe, routes the operand to the correct engine, and muxes the result back to the SPI TX register.

#### `cordic_circular`
CORDIC rotation mode over 7 iterations. Computes sin and cos simultaneously. Accumulators are extended to 12-bit internally to prevent overflow. Angle input uses zero-padding on the top 2 bits — sign extension caused angles above 30° to be misinterpreted as negative during intermediate subtractions.

#### `cordic_divide`
CORDIC linear vectoring mode. Used for tangent by dividing the sine output by the cosine output. Triggered automatically by `circ_done` when mode 11 is active.

#### `cordic_multiply`
Shift-and-add multiplier over 3 iterations. Handles 3-bit signed operands packed into the lower 6 bits of the command byte.

#### `spi_target`
Configurable SPI peripheral (CPOL, CPHA, width, bit order). Synchronizes SCK and SS into the system clock domain with a 3-stage pipeline before processing.

---

### Output

```
CORDIC Coprocessor  |  angle range: 0 to 45 deg                                 
                                                                                
  cos  sin  tan  mul  exit                                                      
                                                                                
> cos                                                                           
angle (deg) > 20                                                                
  fpga 0.9063  ref 0.9397  err 0.033443                                         
> sin                                                                           
angle (deg) > 30                                                                
  fpga 0.5000  ref 0.5000  err 0.000000                                         
> mul                                                                           
a (3-bit signed, -4 to 3) > -3                                                  
b (3-bit signed, -4 to 3) > 2                                                   
  fpga -6.0000  ref -6.0000  err 0.000000                                       
> 
```

