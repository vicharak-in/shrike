# prng64

**Difficulty:** Intermediate
**Uses MCU:** Yes
**External Hardware:** None

## Overview

A hardware psuedo random number generator built on the Shrike Lite. A small mixing function runs entirely in FPGA fabric, spinning a 64-bit state on every clock cycle. The RP2040 sends in whatever you type, and the timing of that gets mixed into the state, so the FPGA turns it into a unguessable number which can be used as passwords.

It is a custom chi-and-rotate mixing loop, small enough to fit in shrike and fast enough to update the state millions of times per second.

## Compatibility

| Board | Firmware | Status |
|---|---|---|
| Shrike Lite (RP2040) | firmware/micropython/ | ✅ Tested |
| Shrike (RP2350) | firmware/micropython/ | ⬜ Untested |
| Shrike-fi (ESP32-S3) | firmware/micropython/ | ⬜ Untested |

FPGA bitstream is the same across all boards.

## Hardware Setup
No external hardware required.

### FPGA

| FPGA GPIO Pin | Signal   | Direction | Description |
| ------------- | -------- | --------- | ----------- |
| 3             | spi_sck  | Input     | SPI clock   |
| 4             | spi_ss_n | Input     | Chip select |
| 5             | spi_mosi | Input     | MOSI        |
| 6             | spi_miso | Output    | MISO        |

---

### RP2040

| RP2040 Pin | Signal | Direction | Description   |
| ---------- | ------ | --------- | ------------- |
| 2          | SCK    | Output    | SPI clock     |
| 1          | CS     | Output    | Chip select   |
| 3          | MOSI   | Output    | Master output |
| 0          | MISO   | Input     | Master input  |

> Ensure pin mapping in FPGA constraints matches firmware configuration.

## Quick Start (Pre-Built Bitstream)

1. Connect Shrike Lite via USB
2. Upload `FPGA_bitstream_MCU.bin` 
3. Run `main.py` on the RP2040 
4. Type a phrase and press ENTER

## Build From Source

### FPGA (Verilog)

1. Open the project in Go Configure Software Hub
2. Add modules: `prng_64` and `spi_target`
3. Configure I/O mapping for the SPI pins
4. Generate the bitstream

### Firmware (MicroPython)

Run `main.py`. The script handles SPI setup, ASCII encoding, and printing the result.

## How It Works

### The Algorithm

The FPGA holds a 64-bit register and runs it through three rounds of a simple mixing loop, all in combinational logic, no adders or carry chains:

- **Chi (non-linearity):** an AND/NOT/XOR step that flips bits based on their neighbors, breaking up any obvious patterns.
- **Rotate-XOR (diffusion):** shifts and XORs the state with rotated copies of itself, so a single flipped bit spreads across the whole 64 bits within a round.

Three rounds of this run back to back in a single clock cycle, and the result feeds directly back into the register, so the state keeps updating without SPI activity.

### Packet Format

The RP2040 talks to the FPGA over a plain SPI byte stream:

```
[ 0xA1 ]     : the MCU wants a byte. FPGA sends back a mix of the current state.
[ != 0xA1 ]  : any other byte. FPGA XORs it directly into the state.
```

Any byte that isn't `0xA1`, including whatever is typed at the prompt, is XORed into the state.

## Output

```
FPGA is running and ready.                                                      
                                                                                
Type a phrase and press ENTER: helo                                             
                                                                                
Generating password...                                                          
                                                                                
Your password:                                                                  
>>  !fGt+?RD1,R3)/~K  <<                                                        
     
=================================
```
