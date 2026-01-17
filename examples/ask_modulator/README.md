# Shrike-Lite ASK Modulator

This project implements a mixed-signal Digital-to-Analog communication system using the Shrike-Lite board. It leverages the RP2040 as a Control Plane (Data/Protocol) and the ForgeFPGA as a Data Plane (Direct Digital Synthesis & PWM).

The system generates a smooth Sine Wave using DDS (Direct Digital Synthesis), converts it to a digital bitstream using PWM, and modulates it using Amplitude Shift Keying (ASK) commands from the RP2040.

To understand the working principle of DDS and PWM audio generation, refer to:
[FPGA DDS Tutorial](https://www.fpga4fun.com/DDS.html).

---

## Block Diagram
```mermaid
    graph LR
        A[RP2040 MCU] -- 6-Bit Frequency Bus --> B[FPGA Input GPIO]
        A -- Data/Enable Signal --> B
        B -- Tuning Word --> C[DDS Logic]
        C -- Sine Value --> D[PWM Generator]
        D -- Digital Pulses --> E[FPGA Output Pin]
        E -- RC Filter --> F[Analog Scope/Audio]
```
## Overview on FPGA Side
The FPGA logic (`dds_ask_modulator`) acts as a high-speed synthesizer consisting of three main stages:

1.  **Phase Accumulator:** A 16-bit counter that increments by a specific "Tuning Word" value every clock cycle. The speed of the overflow determines the carrier frequency.
2.  **Sine Look-Up Table (LUT):** A 64-entry ROM that maps the phase value to a digital amplitude (0 to 63), creating a sine wave shape.
3.  **PWM Generator:** Converts the 6-bit amplitude into a 1-bit high-speed Pulse Width Modulated signal (approx 780 kHz switching rate) suitable for RC filtering.

The modulation is performed logically at the output stage:
- If `i_data` is High: The generated Sine Wave is passed to the output.
- If `i_data` is Low: The output is forced to 0 (Silence).

---

## Features
- **Direct Digital Synthesis (DDS):** Generates mathematically precise sine waves without external DAC chips.
- **Hybrid Architecture:** Offloads fast signal generation (50 MHz logic) to FPGA, keeping the MCU free for text processing and timing.
- **Configurable Carrier:** A 6-bit parallel bus allows the RP2040 to tune the carrier frequency instantly.
- **ASK (Amplitude Shift Keying):** Implements On-Off Keying (OOK) to transmit binary data bursts.
- **Custom Encoding:** Implements a custom 6-bit character map for alphanumeric transmission over the ASK link.

---

## Top Module Interface

| Signal | Direction | Description |
| :--- | :--- | :--- |
| `i_clk` | In | System clock (50 MHz Internal Oscillator) |
| `i_freq_word[5:0]` | In | 6-Bit Tuning Word (Controls Carrier Pitch) |
| `i_data` | In | Modulation Signal (1=Carrier ON, 0=Silence) |
| `o_pwm_out` | Out | PWM Digital Output (Requires Filter) |
| `o_pwm_out_oe` | Out | Output Enable (Always 1) |
| `o_clk_en` | Out | Oscillator Enable (Always 1) |

---

## Parameters & Math
#### `CLK_FREQ :` 
- System clock frequency.
    - `50 MHz`
#### `PWM CARRIER :` 
- The PWM switching frequency is derived from the clock and the resolution ($2^6$).
    - `50 MHz / 64 steps ≈ 781.25 kHz`
#### `OUTPUT FREQUENCY :`
- The audible output frequency is determined by the Tuning Word ($TW$) sent by the RP2040.
    - $F_{out} = \frac{F_{clk} \times TW}{2^{16}}$
    - With $TW=1$, Output $\approx 762 \text{ Hz}$ (Optimal for filtering).

---

## Hardware Setup
### 1. The RC Filter (Demodulator)
The FPGA output is a digital square wave. To see the sine wave on an oscilloscope, an RC Low Pass Filter is required to reconstruct the analog signal.

*   **Resistor:** 1 kΩ
*   **Capacitor:** 10 nF (Code 103) - *Cutoff ~15.9 kHz*
*   **Connection:** Connect Resistor to FPGA Output. Connect Capacitor from Resistor leg to Ground. Probe the junction between R and C.

### 2. Pin Interconnects (Jumper Wires)
Due to pin availability on the specific package, a mixed-header wiring scheme is used. Ensure **Common Ground** between headers.

| Signal | RP2040 Pin | FPGA Pin (Board Label) | Physical Pin (Bitstream) |
| :--- | :--- | :--- | :--- |
| **Freq Bit 0 (LSB)** | **GPIO 5** | **FPGA_IO1** | **PIN 14** |
| **Freq Bit 1** | **GPIO 6** | **FPGA_IO2** | **PIN 15** |
| **Freq Bit 2** | **GPIO 7** | **FPGA_IO17** | **PIN 8** |
| **Freq Bit 3** | **GPIO 8** | **FPGA_IO18** | **PIN 9** |
| **Freq Bit 4** | **GPIO 9** | **FPGA_IO8** | **PIN 23** |
| **Freq Bit 5 (MSB)** | **GPIO 10**| **FPGA_IO9** | **PIN 24** |
| **Data / Enable** | **GPIO 16**| **FPGA_IO0** | **PIN 13** |
| **Power Control** | **GPIO 12/13** | *(Internal)* | *(Internal)* |
| **PWM Output** | *(None)* | **FPGA_IO14** | **PIN 5** |

> **Note:** FPGA Physical Pins refer to the IO Manager mapping in Go Configure.

---

## Firmware Overview
The control logic is written in **MicroPython** running on the RP2040.

1.  **`flash.py`:** Uses the `shrike` library to write the Verilog bitstream (`.bin`) from the RP2040 filesystem into the FPGA configuration memory.
2.  **`main.py`:** 
    *   Initializes the 6-bit Parallel Bus to set the Carrier Frequency.
    *   Powers up the FPGA Core (GPIO 12) and IOs (GPIO 13).
    *   Implements a **Custom 6-Bit Look-Up Table** to map characters (A-Z, 0-9) to specific 6-bit integer codes.
    *   Transmits the string `"HelloShrike123"` by toggling the `i_data` pin (ASK) using a Start-Bit/Stop-Bit protocol.

### Exercise for the User
The current implementation utilizes a custom, optimized 6-bit codebook to map alphanumeric characters to the available bandwidth. 
**A full standard ASCII (8-bit) implementation requires splitting characters into two 4-bit nibbles or serializing the data further. This implementation is left as an exercise for the reader.**

---

## Quick Steps
1.  **Synthesize:** Generate the bitstream in Go Configure with the pin map above.
2.  **Upload:** Copy `FPGA_bitstream_MCU.bin`, `flash.py`, and `helloshrike.py` to the RP2040 via Thonny/VS Code.
3.  **Flash:** Run `flash.py` once to configure the FPGA.
4.  **Run:** Run `helloshrike.py` to start the transmission loop.
5.  **Observe:** Connect Oscilloscope to **FPGA_IO14**. Set Timebase to `50ms/div` and Trigger to `Normal`.

## Expected Output
When running `helloshrike.py`, the oscilloscope will show bursts of Sine Waves corresponding to the logic levels of the transmitted text:

*   **Logic 1:** 3V Sine Wave (Carrier ON)
*   **Logic 0:** 0V Flat Line (Carrier OFF)

Output on the terminal should look like as shown below:

```
--- Transmitting: HelloShrike123 ---
Sending 'H' -> Code 01 -> 000001
Sending 'e' -> Code 02 -> 000010
Sending 'l' -> Code 03 -> 000011
Sending 'l' -> Code 03 -> 000011
Sending 'o' -> Code 04 -> 000100
Sending 'S' -> Code 05 -> 000101
Sending 'h' -> Code 06 -> 000110
Sending 'r' -> Code 07 -> 000111
Sending 'i' -> Code 08 -> 001000
Sending 'k' -> Code 09 -> 001001
Sending 'e' -> Code 02 -> 000010
Sending '1' -> Code 51 -> 110011
Sending '2' -> Code 52 -> 110100
Sending '3' -> Code 53 -> 110101
```

The signal will look like a structured sequence of bursts separated by silence, representing the binary data of the text string.
