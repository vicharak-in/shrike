# ⚡ Hardware-Accelerated Smart Spell-Checking Keyboard

This project implements a hybrid hardware-software system using an **RP2040 Microcontroller** and a **Shrike-Lite FPGA**. It acts as a "Smart Keyboard" that intercepts misspelled words, corrects them in real-time using a frequency dictionary, processes the data through custom FPGA silicon via SPI, and types the corrected sentence directly into your PC using a custom Python HID Background Interface.

## 🧗 Difficulty Level: Advanced
This is a multidisciplinary engineering project that bridges three distinct domains. It requires patience and a willingness to debug across software and silicon boundaries.
* **PC Software (Advanced):** Requires understanding of OS-level keyboard hooks, multi-threading, and serial port management in Python.
* **Embedded Software (Moderate):** Requires understanding of MicroPython, SPI Master protocols, and strict RAM management / garbage collection (the RP2040 has only 264KB of RAM for the dictionary).
* **Digital Logic / FPGA (Advanced):** Requires understanding of Verilog, RTL synthesis, SPI Target implementations, and nanosecond clock domain crossing / synchronization.

---

## 🏗️ The Architecture Pipeline

This system uses an asymmetrical processing architecture where the PC, the microcontroller, and the FPGA do exactly what they are best at.

### 1. The Bridge: Python PC Companion Script (HID Interface)
The Python script running on the host PC is the critical bridge between the hardware and the Operating System. 
* **OS-Level Interception:** It uses a background keyboard hook to silently track user keystrokes globally, completely independent of the active application.
* **Fast-Typing Buffer:** It utilizes a threaded lock to memorize keys pressed *while* waiting for the hardware processing to finish. This ensures fast typists do not lose their flow or have their current word overwritten.
* **Dynamic Injection:** It calculates the exact length of the typo, fires a precise barrage of `Backspace` commands to clear the error, and injects the FPGA-corrected word directly into the active window.
* **Context-Aware:** Features auto-launching capabilities and application-specific overrides (like injecting `ESC` to cancel Chrome's Omnibox autocomplete before correcting).

### 2. The Brain: RP2040 (MicroPython)
The RP2040 acts as the **SPI Master** and high-level system coordinator. 
* **Spell Checking Engine:** It loads a highly optimized 1,000-word frequency dictionary (`top1000.txt`) into its RAM and runs an edit-distance algorithm to find the most probable correct spelling of a mistyped word.
* **Hardware Coordinator:** It chunks the corrected string into individual bytes, manages the Chip Select (`CS`) line, and pumps the SPI Clock to communicate with the FPGA.

### 3. The Muscle: Shrike-Lite FPGA (Verilog)
The Shrike-Lite FPGA acts as the **SPI Target** and low-level hardware pipeline.
* **Hardware Echo & Pipelining:** Currently, the FPGA receives the corrected bytes from the RP2040, registers them into its internal flip-flops, and echoes the final result back across the MISO line on the very next SPI transaction. 
* **Nanosecond Synchronization:** The FPGA operates on a strict 50MHz internal clock. The Verilog logic utilizes a 3-stage synchronizer to catch the RP2040's `CS` drop and align the incoming 100kHz SPI clock to its internal domains.
* **Safe State Logic:** Features internal hardwired resets to prevent floating voltage lock-ups.

---

## 🔌 Hardware Wiring Guide

To replicate this project, you must ensure a **shared Ground (GND)** between the RP2040 and the Shrike-Lite, and wire the SPI bus to the exact default hardware pins:

| Signal | RP2040 Pin | Shrike-Lite FPGA Pin | Description |
| :--- | :--- | :--- | :--- |
| **MOSI (TX)** | `GP19` (Pin 25) | `spi_mosi` | Data from RP2040 to FPGA |
| **MISO (RX)** | `GP16` (Pin 21) | `spi_miso` | Data from FPGA back to RP2040 |
| **SCK** | `GP18` (Pin 24) | `spi_sck` | SPI Clock (Driven by RP2040) |
| **CS / SS** | `GP5` (Pin 7) | `spi_ss_n` | Chip Select (Active Low) |
| **GND** | Any `GND` Pin | Any `GND` Pin | **CRITICAL:** Shared reference voltage |

*(Note: Ensure your Go Configure `.cst` file maps the Verilog variables to the correct physical header pins on your specific Shrike-Lite board).*

---

## 🚀 How It Works (The Data Flow)

1. **Input:** The user types a misspelled string (e.g., `"teh"`). The Python PC Script intercepts it in the background the moment the Spacebar is pressed.
2. **Software Correction:** The PC passes the string to the RP2040 via serial. The RP2040 detects the error, checks the frequency dictionary, and corrects `"teh"` to `"the"`.
3. **SPI Transmission:** The RP2040 wraps the string in `\x00` dummy bytes (to flush the hardware pipeline) and sends it over MOSI to the FPGA.
4. **Hardware Synchronization:** A deliberate `5µs` micro-delay in the RP2040 code allows the FPGA's 50MHz clock to register the Chip Select drop before the data transmission begins, preventing dropped bits.
5. **Hardware Echo:** The FPGA registers the bytes and streams the final result back to the RP2040 over MISO, which is immediately forwarded back to the PC script.
6. **HID Output:** The Python PC script calculates the typo length, rapidly sends `Backspace` commands to delete the error, and dynamically types the corrected string seamlessly into the user's active application.

---

## 🛠️ Setup & Installation

### FPGA Setup
1. Open the Go Configure IDE.
2. Load `top.v` and `spi_target.v` into your project.
3. Apply your `.cst` Physical Constraints file to map the SPI pins and the 50MHz Clock.
4. Synthesize and flash the bitstream to the Shrike-Lite.

### RP2040 Setup
1. Flash your RP2040 with standard MicroPython.
2. Ensure your Python script is named exactly `main.py` and upload it to the root of your microcontroller (this ensures it auto-boots native logic).
3. Upload the `top1000.txt` dictionary file to the root of your microcontroller.

### Running the System
1. Plug both devices in and ensure the SPI jumper wires are connected.
2. Close all IDEs (like Thonny) to free up the COM port.
3. Run the PC Companion Python script as an Administrator on your host machine.
4. Select your target application (Notepad, Chrome, etc.) from the terminal menu. 
5. Start typing and watch the hardware magically fix your spelling in real-time!

---
*Built with Python, Verilog, and a lot of debugging over serial ports.*
