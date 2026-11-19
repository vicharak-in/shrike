# shrike_tracerunner

**Difficulty:** Advanced  
**Uses MCU:** Yes (ESP32-S3)  
**External Hardware:** 8-Channel Digital IR Sensor Bar (TCRT5000), Dual 360° Continuous Rotation Servos (FS90R / SG90-360), 2WD Robot Chassis, 5V Regulated Power Supply / Battery  

---

## Overview

`shrike_tracerunner` is an autonomous line-following robot built using the **FPGA + MCU co-design** of the **Vicharak Shrike-Fi** (ESP32-S3 + Renesas ForgeFPGA SLG47910).

The design implements real-time hardware-accelerated control:
- **ForgeFPGA (50 MHz RTL):** Line centroid decoding ($[-7, +7]$), 2-stage pipelined fixed-point PID calculation with anti-windup accumulator clamp, differential motor mixing with line-loss pivot memory, 50 ms SPI safety watchdog, and direct 50 Hz continuous rotation RC servo pulse generation ($1000\,\mu\text{s} - 2000\,\mu\text{s}$).
- **ESP32-S3 (1 kHz Control Loop):** High-frequency 8-channel IR sensor sampling, initial bitstream bootstrap over SPI on power-up, full-duplex 4-byte SPI telemetry packets at 2.0 MHz, interactive USB serial CLI, and a zero-dependency wireless Web PID tuning dashboard over local Wi-Fi AP.

---

## Compatibility

| Board | MCU | Firmware | Status |
|---|---|---|---|
| Shrike-fi | ESP32-S3 | `firmware/arduino-ide/shrike_line_follower/` | ✅ Tested (Simulation & Firmware Verified) |
| Shrike-lite | RP2040 | — | Untested |
| Shrike | RP2350 | — | Untested |

> The FPGA bitstream is synthesized for the Renesas ForgeFPGA SLG47910 and can interface to RP2040/RP2350 with corresponding SPI pin mapping.

---

## Hardware Setup

### 1. 8-Channel IR Sensor Bar $\rightarrow$ ESP32-S3 GPIO
Power the sensor module from the Shrike-Fi **3.3V** rail:
- `D0 (Far Right)` $\rightarrow$ **GPIO 1**
- `D1 (Right Outer)` $\rightarrow$ **GPIO 2**
- `D2 (Right Mid)` $\rightarrow$ **GPIO 4**
- `D3 (Right Center)` $\rightarrow$ **GPIO 5**
- `D4 (Left Center)` $\rightarrow$ **GPIO 6**
- `D5 (Left Mid)` $\rightarrow$ **GPIO 7**
- `D6 (Left Outer)` $\rightarrow$ **GPIO 15**
- `D7 (Far Left)` $\rightarrow$ **GPIO 16**

### 2. Dual Continuous Rotation Servos $\rightarrow$ PMOD Connector J5
The servos receive 50 Hz PWM control pulses directly from the ForgeFPGA on PMOD J5:

| Servo Signal | PMOD J5 Pin | FPGA Net / Pin | Description |
| :--- | :---: | :---: | :--- |
| **Left Servo Signal** (Orange/White) | **Pin 5** | `F_GPIO9` (Pin 24) | `pwm_left_out` (50 Hz RC pulse) |
| **Right Servo Signal** (Orange/White) | **Pin 6** | `F_GPIO8` (Pin 23) | `pwm_right_out` (50 Hz RC pulse, mirrored) |
| **Hardware Enable** | **Pin 7** | `F_GPIO11` (Pin 2) | `motor_en_out` (High when armed) |
| **Servo Power (+5V)** | External Buck Converter | External 5V Rail | **Do NOT power from 3.3V rail** |
| **Servo Ground (GND)** | Ground Rail | Common GND | Must share ground with Shrike-Fi |

> [!CAUTION]
> **Never power servos from the 3.3V rail or directly from FPGA pins.** Servos draw 150–400 mA under load and will brown out the board. Power servo VCC from a dedicated 5.0V buck converter sharing a common star ground with Shrike-Fi.

> [!WARNING]
> PMOD pins 9 through 12 (`F_GPIO13..14`) are hardwired internally on the Shrike-Fi PCB to the ESP32-to-FPGA SPI communication bus. Do not connect external wires to PMOD pins 9–12.

---

## Quick Start (Pre-Built Bitstream)

1. Connect Shrike-Fi via USB-C.
2. Flash `bitstream/shrike_tracerunner.bin` directly using ShrikeFlash, OR let the ESP32-S3 firmware stream it on boot.
3. Open `firmware/arduino-ide/shrike_line_follower/shrike_line_follower.ino` in Arduino IDE 2.x.
4. Select board **ESP32S3 Dev Module** and upload.
5. Open Serial Monitor at **115200 baud**.

---

## Build From Source

### 1. FPGA Bitstream (Verilog)
1. Launch **Go Configure Software Hub (GCSH)** (v6.56 or newer).
2. Open `shrike_tracerunner.ffpga`.
3. Click **Synthesize** $\rightarrow$ **Generate Bitstream**.
4. The synthesized bitstream is generated in `ffpga/build/bitstream/FPGA_bitstream_MCU.bin`.

### 2. Verification & HDL Simulation
To run the cycle-accurate Icarus Verilog testbench:
```bash
iverilog -o sim.vvp ffpga/sim/tb_pid_top.v ffpga/src/pid_top.v
vvp sim.vvp
```
To run the Python golden reference model unit tests:
```bash
pytest tests/
```

### 3. Firmware (Arduino IDE)
1. Open `firmware/arduino-ide/shrike_line_follower/shrike_line_follower.ino`.
2. Configure Wi-Fi or pin settings in `config.h` if customized.
3. Compile and upload to the ESP32-S3.

---

## How It Works

```text
 [ 8-Channel IR Sensor Bar ]
             |
             v (8 digital GPIO lines)
  +-----------------------+
  |    ESP32-S3 (MCU)     | --- Sensor sampling & SPI master
  +-----------------------+
             |
             | 4-Byte Full-Duplex SPI (2.0 MHz, 1 kHz loop)
             v
  +-----------------------+
  |  ForgeFPGA (SLG47910) | --- PRIMARY REAL-TIME CONTROL ENGINE
  |  - Centroid Decoder   |     (50 MHz clock, deterministic execution)
  |  - 2-Stage Pipeline   |
  |  - Fixed-Point PID    |
  |  - Anti-Windup Clamps |
  |  - Motor Mixer        |
  |  - 50ms SPI Watchdog  | --- Auto-failsafe if communication drops
  |  - 50 Hz Servo Engine | --- 1000us - 2000us RC servo pulses (1500us neutral)
  +-----------------------+
             |
             v (PMOD J5 Pins 5 & 6)
   [ Dual 360° Continuous Rotation Servos ]
```

### SPI Telemetry Protocol (4-Byte Full-Duplex @ 2 MHz)
- **MOSI Frame:** `[Cmd / Mode]` `[Base Speed]` `[Gain Kp / Ki / Kd]` `[Sensor Mask / Target]`
- **MISO Frame:** `[Status / Watchdog]` `[Calculated Error]` `[PWM Left]` `[PWM Right]`

---

## Expected Output

### Serial Console (115200 baud)
```text
[BOOT] Vicharak Shrike-Fi PID Line Follower Initializing...
[BOOT] Streaming 46408 bytes to ForgeFPGA...
[BOOT] ForgeFPGA successfully configured and running!
[WIFI] Access Point started: SSID "Shrike-TraceRunner"
[WEB] Dashboard running at http://192.168.4.1/
[READY] System armed. PID Loop active @ 1000 Hz.
```

### Web Tuning Dashboard
Connect to Wi-Fi SSID `Shrike-TraceRunner` and open `http://192.168.4.1/` on any mobile device or browser to view live error gauges, adjust $K_p/K_i/K_d$ sliders in real time, and toggle emergency stop without cables.
