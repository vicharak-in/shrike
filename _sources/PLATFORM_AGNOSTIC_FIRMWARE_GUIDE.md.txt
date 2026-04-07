# Writing Platform-Agnostic Firmware for Shrike

This guide explains how to write a single firmware source file that runs on all boards in the Shrike family — Shrike-Lite (RP2040), Shrike (RP2350), and Shrike-fi (ESP32-S3) — without maintaining separate codebases.

The FPGA side is identical across all boards (same SLG47910 ForgeFPGA, same bitstream). Only the host MCU changes. This guide covers how to handle those MCU differences cleanly.

---

## The Problem

Each board in the Shrike family uses a different host MCU:

| Board | MCU | Arduino Core | MicroPython Platform |
|-------|-----|-------------|---------------------|
| Shrike-Lite | RP2040 | `arduino-pico` (Earle Philhower) | `rp2` |
| Shrike | RP2350 | `arduino-pico` (Earle Philhower) | `rp2` |
| Shrike-fi | ESP32-S3 | `arduino-esp32` (Espressif) | `esp32` |

The differences typically fall into three categories:

1. **Pin assignments** — Different GPIOs for the FPGA interconnect, SPI, UART
2. **Peripheral initialization** — Different SPI class instances, UART ports
3. **Platform APIs** — Filesystem, Wi-Fi (ESP32 only), deep sleep, etc.

The goal is to isolate these differences into a small, clearly marked section at the top of each file, while keeping the core application logic shared.

---

## Arduino IDE — Using `#ifdef`

### How It Works

The Arduino build system defines architecture macros at compile time based on the selected board. These macros let you conditionally compile different code blocks.

| Board Selected | Macro Defined |
|---------------|--------------|
| Any RP2040 board | `ARDUINO_ARCH_RP2040` |
| Any RP2350 board | `ARDUINO_ARCH_RP2040` (same core) |
| Any ESP32 board | `ARDUINO_ARCH_ESP32` |

> **Note:** RP2350 uses the same `arduino-pico` core as RP2040 and defines the
> same `ARDUINO_ARCH_RP2040` macro. If you ever need to distinguish between
> RP2040 and RP2350 specifically, check for `PICO_RP2350` which is defined
> only on RP2350 builds.

### Pattern 1 — Pin Definition Block

The simplest and most common case. Put all pin definitions in a single block at the top.

```cpp
// =============================================================
// Platform Configuration
// =============================================================

#ifdef ARDUINO_ARCH_RP2040
  // Shrike-Lite (RP2040) / Shrike (RP2350)
  #define FPGA_SPI_SS    1
  #define FPGA_SPI_SCK   2
  #define FPGA_SPI_MOSI  3
  #define FPGA_SPI_MISO  0
  #define FPGA_EN        13
  #define FPGA_PWR       12

  #define UART_TX_PIN    0
  #define UART_RX_PIN    1


#elif defined(ARDUINO_ARCH_ESP32)
  // Shrike-fi (ESP32-S3)
  #define FPGA_SPI_SS    10
  #define FPGA_SPI_SCK   12
  #define FPGA_SPI_MOSI  11
  #define FPGA_SPI_MISO  13
  #define FPGA_EN        5
  #define FPGA_PWR       4

  #define UART_TX_PIN    17
  #define UART_RX_PIN    18

#else
  #error "Unsupported board. Please use RP2040, RP2350, or ESP32-S3."
#endif

// =============================================================
// Application Code (shared across all platforms)
// =============================================================

void setup() {
  Serial.begin(115200);
  pinMode(INTER_0, INPUT);
  // ... rest of setup
}

void loop() {
  int val = digitalRead(INTER_0);
  // ... rest of application logic
}
```

**Key points:**
- The `#else #error` block catches unsupported boards at compile time
- All platform-specific code is contained in ONE block
- Everything after the block is 100% shared

### Pattern 2 — SPI Instance Handling

RP2040 and ESP32 initialize SPI differently. RP2040's default `SPI` object works fine, but ESP32 needs an explicit HSPI instance to avoid conflicts with its internal flash.

```cpp
#include <SPI.h>
#include <ShrikeFlash.h>

#ifdef ARDUINO_ARCH_RP2040
  // Default SPI works on RP2040/RP2350
  ShrikeFlash fpga;

#elif defined(ARDUINO_ARCH_ESP32)
  // ESP32 needs a dedicated HSPI instance
  SPIClass _hspi(HSPI);
  ShrikeFlash fpga(FPGA_EN, FPGA_PWR, FPGA_SPI_SS,
                   FPGA_SPI_SCK, FPGA_SPI_MOSI, FPGA_SPI_MISO);
#endif

void setup() {
  Serial.begin(115200);

  #ifdef ARDUINO_ARCH_ESP32
    _hspi.begin(FPGA_SPI_SCK, FPGA_SPI_MISO, FPGA_SPI_MOSI, FPGA_SPI_SS);
    fpga.begin(&_hspi);
  #else
    fpga.begin();
  #endif

  fpga.flash("/bitstream.bin");
}
```

> **Why HSPI?** ESP32's default SPI bus (VSPI) is often shared with internal
> flash. Using HSPI avoids the mutex crash that occurs when ShrikeFlash
> tries to access SPI while FreeRTOS is managing the flash bus.
> This was a real bug that was fixed during the ESP32 port of ShrikeFlash.

### Pattern 3 — Distinguishing RP2040 from RP2350

For most Shrike examples, RP2040 and RP2350 are interchangeable. But if you need to detect the specific chip (for example, to use RP2350-only features like extra GPIO or security functions):

```cpp
#ifdef ARDUINO_ARCH_RP2040
  #ifdef PICO_RP2350
    // RP2350-specific code
    #define MCU_NAME "RP2350"
  #else
    // RP2040-specific code
    #define MCU_NAME "RP2040"
  #endif
#elif defined(ARDUINO_ARCH_ESP32)
  #define MCU_NAME "ESP32-S3"
#endif

void setup() {
  Serial.begin(115200);
  Serial.print("Running on: ");
  Serial.println(MCU_NAME);
}
```

### Pattern 4 — Feature Flags for Optional Capabilities

ESP32-S3 has Wi-Fi and Bluetooth. RP2040/RP2350 don't. Use feature flags instead of scattering `#ifdef` throughout your code:

```cpp
// Feature detection
#ifdef ARDUINO_ARCH_ESP32
  #define HAS_WIFI       1
  #define HAS_BLUETOOTH  1
#else
  #define HAS_WIFI       0
  #define HAS_BLUETOOTH  0
#endif

void setup() {
  Serial.begin(115200);

  #if HAS_WIFI
    WiFi.begin("ssid", "password");
    Serial.println("Wi-Fi connecting...");
  #else
    Serial.println("Wi-Fi not available on this board");
  #endif
}
```

**Why feature flags?** They self-document what each platform can do. A contributor reading the code sees `HAS_WIFI` and immediately understands the intent, rather than parsing `ARDUINO_ARCH_ESP32` and guessing why it's there.

### Pattern 5 — Platform Abstraction Header (Advanced)

For complex examples with many platform differences, extract everything into a shared header:

```
firmware/
├── arduino-ide/
│   ├── uart_sum.ino
│   └── shrike_platform.h
```

**shrike_platform.h:**
```cpp
#ifndef SHRIKE_PLATFORM_H
#define SHRIKE_PLATFORM_H

#ifdef ARDUINO_ARCH_RP2040
  #define PLATFORM_NAME     "RP2040"
  #define FPGA_SPI_SS       1
  #define FPGA_SPI_SCK      2
  #define FPGA_SPI_MOSI     3
  #define FPGA_SPI_MISO     0
  #define FPGA_EN           13
  #define FPGA_PWR          12
  #define HAS_WIFI          0
  #define HAS_BLUETOOTH     0

#elif defined(ARDUINO_ARCH_ESP32)
  #define PLATFORM_NAME     "ESP32-S3"
  #define FPGA_SPI_SS       10
  #define FPGA_SPI_SCK      12
  #define FPGA_SPI_MOSI     11
  #define FPGA_SPI_MISO     13
  #define FPGA_EN           5
  #define FPGA_PWR          4
  #define HAS_WIFI          1
  #define HAS_BLUETOOTH     1

#else
  #error "Unsupported board"
#endif

#endif // SHRIKE_PLATFORM_H
```

**uart_sum.ino:**
```cpp
#include "shrike_platform.h"
#include <ShrikeFlash.h>

// Clean application code — no #ifdefs needed here
void setup() {
  Serial.begin(115200);
  Serial.print("Shrike running on: ");
  Serial.println(PLATFORM_NAME);

  pinMode(INTER_0, OUTPUT);
  // ...
}
```

> **When to use this:** If your `#ifdef` block exceeds ~20 lines in the main
> sketch, extract it into a header. For simple examples (pin changes only),
> keep it inline — the header adds a file without adding clarity.

---

## MicroPython — Using `sys.platform`

### How It Works

MicroPython doesn't have a preprocessor. Instead, you detect the platform at runtime using `sys.platform`:

| Board | `sys.platform` |
|-------|----------------|
| Shrike-Lite (RP2040) | `'rp2'` |
| Shrike (RP2350) | `'rp2'` |
| Shrike-fi (ESP32-S3) | `'esp32'` |

### Pattern 1 — Pin Configuration Dict

```python
import sys
from machine import Pin, UART, SPI

# =============================================================
# Platform Configuration
# =============================================================

if sys.platform == 'rp2':
    CONFIG = {
        'platform':      'RP2040/RP2350',
        'fpga_spi_ss':   1,
        'fpga_spi_sck':  2,
        'fpga_spi_mosi': 3,
        'fpga_spi_miso': 0,
        'fpga_en':       13,
        'fpga_pwr':      12,
        'uart_id':       0,
        'uart_tx':       0,
        'uart_rx':       1,
        'interconnect':  [6, 7, 8, 9, 10, 11],
    }

elif sys.platform == 'esp32':
    CONFIG = {
        'platform':      'ESP32-S3',
        'fpga_spi_ss':   10,
        'fpga_spi_sck':  12,
        'fpga_spi_mosi': 11,
        'fpga_spi_miso': 13,
        'fpga_en':       5,
        'fpga_pwr':      4,
        'uart_id':       1,
        'uart_tx':       17,
        'uart_rx':       18,
        'interconnect':  [35, 36, 37, 38, 39, 40],
    }

else:
    raise RuntimeError(f"Unsupported platform: {sys.platform}")

# =============================================================
# Application Code (shared)
# =============================================================

print(f"Running on {CONFIG['platform']}")

uart = UART(CONFIG['uart_id'],
            baudrate=115200,
            tx=Pin(CONFIG['uart_tx']),
            rx=Pin(CONFIG['uart_rx']))

inter_pins = [Pin(p, Pin.IN) for p in CONFIG['interconnect']]
```

**Why a dict?** Cleaner than loose variables. You can pass `CONFIG` to functions, print it for debugging, or serialize it. It also keeps the platform block visually contained.

### Pattern 2 — UART Initialization Differences

RP2040 and ESP32 handle UART slightly differently:

```python
import sys
from machine import UART, Pin

if sys.platform == 'rp2':
    # RP2040: UART 0 with explicit pin assignment
    uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))

elif sys.platform == 'esp32':
    # ESP32: UART 1 (UART 0 is reserved for REPL)
    uart = UART(1, baudrate=115200, tx=Pin(17), rx=Pin(18))

# Shared logic — works with either uart object
def send_command(cmd):
    uart.write(cmd.encode())

def read_response():
    if uart.any():
        return uart.read()
    return None
```

> **ESP32 UART note:** UART 0 on ESP32 is typically connected to the USB-REPL.
> Always use UART 1 or UART 2 for FPGA communication on Shrike-fi.

### Pattern 3 — SPI for FPGA Bitstream Flashing

```python
import sys
from machine import SPI, Pin
import time

if sys.platform == 'rp2':
    spi = SPI(0,
              baudrate=8_000_000,
              polarity=0,
              phase=0,
              sck=Pin(2),
              mosi=Pin(3),
              miso=Pin(0))
    ss  = Pin(1, Pin.OUT, value=1)
    en  = Pin(13, Pin.OUT)
    pwr = Pin(12, Pin.OUT)

elif sys.platform == 'esp32':
    spi = SPI(1,
              baudrate=8_000_000,
              polarity=0,
              phase=0,
              sck=Pin(12),
              mosi=Pin(11),
              miso=Pin(13))
    ss  = Pin(10, Pin.OUT, value=1)
    en  = Pin(5, Pin.OUT)
    pwr = Pin(4, Pin.OUT)


# Shared flashing logic
def flash_fpga(filename):
    """Flash a bitstream to the FPGA via SPI."""
    pwr.value(0)
    time.sleep_ms(10)
    pwr.value(1)
    time.sleep_ms(10)

    with open(filename, 'rb') as f:
        data = f.read()

    ss.value(0)
    spi.write(data)
    ss.value(1)

    print(f"Flashed {len(data)} bytes from {filename}")
```

### Pattern 4 — Feature Detection at Runtime

For optional features like Wi-Fi on ESP32:

```python
import sys

def has_wifi():
    """Check if the current platform supports Wi-Fi."""
    try:
        import network
        return hasattr(network, 'WLAN')
    except ImportError:
        return False

# Usage
if has_wifi():
    import network
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    print("Wi-Fi available")
else:
    print("Wi-Fi not available on this board")
```

**Why `try/except` instead of `sys.platform`?** It's more Pythonic and future-proof. If a new board supports Wi-Fi, this code works automatically without adding another `elif`.

### Pattern 5 — Platform Config Module (Advanced)

For complex projects, extract the config into a shared module:

```
firmware/
└── micropython/
    ├── uart_sum.py
    └── shrike_config.py
```

**shrike_config.py:**
```python
"""
Platform configuration for the Shrike family.
Auto-detects the board and exports the correct pin mappings.
"""

import sys

_CONFIGS = {
    'rp2': {
        'platform':      'RP2040/RP2350',
        'spi_id':        0,
        'fpga_spi_ss':   1,
        'fpga_spi_sck':  2,
        'fpga_spi_mosi': 3,
        'fpga_spi_miso': 0,
        'fpga_en':       13,
        'fpga_pwr':      12,
        'uart_id':       0,
        'uart_tx':       0,
        'uart_rx':       1,
        'interconnect':  [6, 7, 8, 9, 10, 11],
    },
    'esp32': {
        'platform':      'ESP32-S3',
        'spi_id':        1,
        'fpga_spi_ss':   10,
        'fpga_spi_sck':  12,
        'fpga_spi_mosi': 11,
        'fpga_spi_miso': 13,
        'fpga_en':       5,
        'fpga_pwr':      4,
        'uart_id':       1,
        'uart_tx':       17,
        'uart_rx':       18,
        'interconnect':  [35, 36, 37, 38, 39, 40],
    },
}

if sys.platform not in _CONFIGS:
    raise RuntimeError(
        f"Unsupported platform: {sys.platform}. "
        f"Expected one of: {list(_CONFIGS.keys())}"
    )

board = _CONFIGS[sys.platform]
```

**uart_sum.py:**
```python
from shrike_config import board
from machine import UART, Pin

print(f"Running on {board['platform']}")

uart = UART(board['uart_id'],
            baudrate=115200,
            tx=Pin(board['uart_tx']),
            rx=Pin(board['uart_rx']))

# Clean application code — no platform checks needed
while True:
    if uart.any():
        data = uart.read()
        # process data ...
```

> **When to use this:** When multiple scripts in the same project all need
> platform config. For single-file examples, keep the config inline.

---

## Guidelines for Shrike Contributors

### When Writing a New Example

1. Start with the pin config block at the top (Pattern 1 for either language)
2. Keep all `#ifdef` / `sys.platform` checks in ONE place — don't scatter them
3. Use the `#else #error` / `raise RuntimeError` pattern to catch unsupported boards
4. Test on at least RP2040 + ESP32 before submitting (or note which boards are tested)
5. If the firmware is truly identical across boards (no pin differences), skip the platform block entirely

### When the Differences Are Too Large

Sometimes the firmware for RP2040 and ESP32 diverges significantly — different libraries, different APIs, different architecture. In that case, don't force a single file. Split into separate files:

```
firmware/
├── arduino-ide
│   ├── uart_sum_rp2040.ino
│   └── uart_sum_esp32.ino
└── micropython
    ├── uart_sum_rp2040.py
    └── uart_sum_esp32.py
```

**The rule of thumb:** If more than 40% of the code is inside `#ifdef` blocks, the "platform-agnostic" file is harder to read than two separate files. Split it.

### Decision Flowchart

```
Does the firmware differ between RP2040 and ESP32?
│
├── No  → Single file, no platform block needed
│
├── Only pin numbers differ
│   → Single file + Pattern 1 (pin config block)
│
├── Pin numbers + peripheral init differ
│   → Single file + Pattern 2 (pin config + init block)
│
├── Significant logic differences (>30% of code)
│   → Separate files per board
│
└── Shared config needed across multiple scripts
    → Extract into shrike_platform.h or shrike_config.py
```

---

## Quick Reference

### Arduino — Common Macros

| Macro | When Defined |
|-------|-------------|
| `ARDUINO_ARCH_RP2040` | RP2040 and RP2350 (arduino-pico core) |
| `PICO_RP2350` | RP2350 only |
| `ARDUINO_ARCH_ESP32` | All ESP32 variants |
| `ARDUINO_ESP32S3_DEV` | ESP32-S3 specifically |

### MicroPython — Platform Strings

| String | When Returned by `sys.platform` |
|--------|-------------------------------|
| `'rp2'` | RP2040 and RP2350 |
| `'esp32'` | All ESP32 variants |

### Pin Mapping Reference

| Function | Shrike-Lite (RP2040) | Shrike (RP2350) | Shrike-fi (ESP32-S3) |
|----------|---------------------|-----------------|---------------------|
| SPI SS | 1 | 1 | 10 |
| SPI SCK | 2 | 2 | 12 |
| SPI MOSI | 3 | 3 | 11 |
| SPI MISO | 0 | 0 | 13 |
| FPGA EN | 13 | 13 | 5 |
| FPGA PWR | 12 | 12 | 4 |

---

## Summary

The Shrike family shares the same FPGA. The only firmware differences are pin mappings and peripheral initialization on the host MCU. By isolating these differences into a clearly marked configuration block at the top of each file, you get:

- **One file to maintain** instead of two or three
- **Consistent behavior** across the entire Shrike family
- **Easy onboarding** — contributors see the pattern once and can replicate it
- **Future-proof** — when Shrike-fi ships, existing examples just need a pin block added
