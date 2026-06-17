# Vector Predictor

**Difficulty:** Intermediate
**Uses MCU:** Yes
**External Hardware:** None

## Overview

This example executes a compact machine learning model directly on the Shrike's RP2040 microcontroller without relying on host PC inference or FPGA fabric. Users provide a seed word's ID via the Serial Monitor, prompting the board to compute vector layer normalizations, run cosine similarity matching, and stream back continuous text variants from its internal 512-word vocabulary. This project serves as a hands-on look at exporting trained neural weights into static C headers and running optimized vector matching operations on low-power hardware.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` | ✅ Tested |
| Shrike (RP2350) | `firmware/arduino-ide/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware or custom wiring required. Only the Shrike-Lite board connected to a computer over USB is needed.

It does not uses FPGA.

## Quick Start 

1. Connect your Shrike-Lite board to your computer via USB.

2. Open firmware/arduino-ide/onboard_vector_predictor.ino in the Arduino IDE.

3. Select Vicharak Shrike Lite as your target board and pick the matching serial COM port.

4. Upload the sketch.

5. Open the Serial Monitor and configure the speed to 115200 baud.

6. Type an input parameter token ID from 0 to 511 into the input bar and press Send.

7. Follow the prompt to choose your text generation mode configuration (0 for strict math, 1 for balanced, 2 for high creative variance).

## Build From Source

### Firmware (Arduino)
1. Open firmware/arduino-ide/onboard_vector_predictor.ino in the Arduino IDE.

2. Ensure model_data.h and vocab_data.h are positioned in the exact same sketch directory.

3. Select your core micro development board configuration and click Upload.

## How It Works

Each inference execution cycle reads the multi-dimensional vector array row corresponding to the active token and calculates a custom layer normalization loop to maintain a zero mean and unit variance. That output vector is then cross-evaluated against all alternate rows inside the 512-word vocabulary table using an on-chip cosine similarity algorithm.

To ensure varied text output structures, the firmware processes two additional optimization behaviors:

1. Interactive Randomness Modes: Rather than locking strictly into a single highest scoring prediction, the loop identifies the top 3 closest math matches. Depending on the runtime mode configuration, the processor filters its selection distributions to balance accurate math alongside creative variance.

2. Context Window Tracking Buffer: The script maintains a rolling history of the 5 last generated tokens. Active tokens stored within this memory track receive a specific dot-product penalty multiplier, preventing the system from falling into repetitive loops or phrasing patterns.

## Expected Output

Each successful generation prints out the accepted seed identifier, streams 12 subsequent word strings separated by spacing boundaries, and logs a completion sequence confirmation flag. Output vocabulary trends and phrase selections vary dynamically depending on your original input seed index choice and text mode parameter configuration.
