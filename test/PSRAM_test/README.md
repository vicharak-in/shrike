# PSRAM_test (Shrike-fi)

**Difficulty:** Beginner  
**Uses MCU:** Yes  
**External Hardware:** None

## Overview

This example verifies whether PSRAM is detected on the Shrike-fi (ESP32-S3) board.  
You will learn how to enable PSRAM in Arduino IDE, check availability using `psramFound()`, and print total PSRAM size using `ESP.getPsramSize()`.

## Compatibility

|       Board          |       Firmware          |     Status      |
|----------------------|-------------------------|-----------------|
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` |Does not Support |
| Shrike (RP2350)      | `firmware/arduino-ide/` |Does not support |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` |    Tested       |

## Hardware Setup

No external hardware required.

## Quick Start

1. Connect your Shrike-fi board via USB.    
2. Open `PSRAM_test.ino` in Arduino IDE.
3. In **Tools > Board**, select **ESP32S3 Dev Module**.
4. In **Tools > Port**, select the connected device port.
5. In **Tools > PSRAM**, select **QSPI PSRAM** (if not already enabled).
6. Upload the sketch.
7. Open Serial Monitor at `115200` baud.
8. Expected result: PSRAM detection status and size are printed.

### Firmware (Arduino)

1. Open `PSRAM_test.ino` in Arduino IDE.
2. Select **ESP32S3 Dev Module**.
3. Enable **QSPI PSRAM** in **Tools > PSRAM**.
4. Upload to Shrike-fi.

## How It Works

The sketch initializes serial communication at `115200` baud, then calls `psramFound()` to check if external PSRAM is available.  
If found, it reads and prints the PSRAM size in bytes using `ESP.getPsramSize()`. This confirms both detection and usable memory capacity.

## Expected Output

If PSRAM is available:

```text
PSRAM Found
Size of PSRAM: <number> bytes
```

If PSRAM is not available:

```text
PSRAM NOT Found
```
