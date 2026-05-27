# PSRAM Test (Shrike fi)

This project verifies whether the PSRAM is being detected in the Shrike-Fi board.

## What `PSRAM_test.ino` does

1. Starts serial communication at `115200` baud.
2. Checks PSRAM availability using `psramFound()`.
3. Prints total PSRAM size using `ESP.getPsramSize()`.

## Requirements

- Arduino IDE
- ESP32 board package installed
## Arduino IDE Setup

1. Open `PSRAM_test.ino`.
2. In the Tools menu, select ESP32S3 Dev Module as the board [**Tools > Board**].
3. In the Tools menu, select the port to which the Shrike-Fi is connected [**Tools > Port**].
4. In the Tools menu, if PSRAM is disabled by default. Click on **PSRAM and select QSPI PSRAM**[**Tools > PSRAM**].
5. Upload the sketch.

## How to Run

1. Open **Serial Monitor**.
2. Set baud rate to **115200**.
3. Press reset.
4. Check the printed output.

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

