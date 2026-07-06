# FPGA-Based CORDIC Digital Communication Demonstrator

## Overview

This example implements SIN, COS, and TAN computation on the ForgeFPGA using the CORDIC algorithm, and uses the results to generate BPSK and QPSK modulated symbols. A desktop GUI visualizes the resulting waveforms and constellation diagrams.

The RP2040 acts only as a bridge: it forwards commands from the host over USB Serial to SPI transactions with the FPGA, and relays the results back.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested |
| Shrike (RP2350) | `firmware/micropython/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested |

> The FPGA bitstream is identical across all compatible Shrike boards — only the MCU firmware differs.

## Hardware Setup

No external hardware is required. The RP2040 and ForgeFPGA SLG47910 are both integrated on the Shrike Lite board, and all communication between the host PC and the FPGA runs over the onboard USB Serial and SPI links.

### Onboard FPGA Interface

| FPGA Port | Direction | Description |
|-----------|-----------|-------------|
| `clk` | Input | System clock (internal oscillator) |
| `clk_en` | Output | Enables the onboard oscillator |
| `rst_n` | Input | Active-low system reset |
| `led` | Output | Status indication |
| `spi_sck` | Input | SPI clock from RP2040 |
| `spi_mosi` | Input | Command and angle data from RP2040 |
| `spi_miso` | Output | SIN, COS, and TAN data returned to RP2040 |
| `spi_miso_en` | Output | Enables FPGA SPI output driver |
| `spi_ss_n` | Input | Active-low SPI slave select |

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike Lite to your computer via USB.
2. Flash `bitstream/cordic.bin` to the board.
3. Upload the MicroPython firmware from `firmware/micropython/` using Thonny and run it.
4. Expected result: the script flashes the bitstream, then prompts for an angle and prints FPGA-computed SIN/COS/TAN — or, if using the Host GUI, prompts you to pick a modulation scheme and starts visualizing live BPSK/QPSK output.

## Build From Source

### FPGA

1. Open the `.ffpga` project in Go Configure Software Hub (GCSH).
2. Click Synthesize → Generate Bitstream.
3. The output `.bin` will appear in the project's build folder — copy it into `bitstream/`.

### Firmware

1. Open the provided MicroPython script in Thonny.
2. Connect the Shrike Lite over USB and select it as the run target.
3. Run the script — it flashes the FPGA bitstream automatically, then starts the SPI command loop

### Desktop Host GUI

A cross-platform desktop GUI is available for interacting with the FPGA in real time. The GUI provides:

- USB Serial communication with the Shrike board
- BPSK and QPSK modulation modes
- Binary, ASCII, and random data transmission
- Real-time waveform visualization
- I/Q constellation viewer
- Backend processing visualizer
- FPGA CORDIC calculator (SIN/COS/TAN verification)
- Data table and serial monitor

Download the latest GUI package (ZIP) from:
**https://drive.google.com/file/d/17IrBJPUw-XISiCXlB3vhB_2ddASdi6e4/view?usp=sharing**

After downloading:

1. Extract the ZIP archive.
2. Run the executable.
3. Connect the Shrike board via USB.
4. Select the appropriate COM port.
5. Start transmitting BPSK or QPSK data.

For a complete walkthrough of every GUI feature, see **docs/gui_guide.md**.

## How It Works

An input angle first passes through Quadrant Reduction, which folds it into the FPGA's native `[0°, 90°]` operating range and records which quadrant it came from as two sign bits. This allows the system to handle arbitrary input angles, including values outside a single revolution.

The reduced angle enters the CORDIC Rotation engine: a 2D vector, initialized to `(K, 0)`, is rotated one small known angle at a time using shifts and additions. Each iteration adds or subtracts a precomputed `atan(2⁻ⁱ)` value depending on the sign of the remaining angle, moving the vector's components toward the cosine and sine of the target angle. After enough iterations, the vector's two components are SIN and COS, and the original quadrant's sign bits are reapplied to produce the signed result.

TAN is computed by a second, smaller Linear Divider engine that runs after the rotation stage completes, rather than a conventional divider — a full hardware divider was evaluated and did not fit within the FPGA's logic budget. The Linear Divider holds COS constant and iteratively shifts and adds/subtracts it against a running remainder, starting at SIN, to converge on the quotient — the same shift-add approach as the rotation stage, applied to division.

The RP2040 handles only communication: it parses incoming USB Serial commands, translates them into a small SPI command set (send angle, poll ready, read result bytes), and forwards the FPGA's results back to the host. SIN, COS, and TAN are computed by the CORDIC core.

## Expected Output

Sending an angle through the CORDIC Calculator returns FPGA-computed SIN, COS, and TAN values alongside a software reference for comparison. Running the full demonstrator with BPSK selected shows a two-point constellation and a waveform with 180° phase flips at each bit transition; selecting QPSK shows a four-point Gray-coded constellation and a waveform with four distinct phase states, one per 2-bit symbol.