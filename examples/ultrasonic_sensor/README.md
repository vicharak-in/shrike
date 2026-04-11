# ultrasonic_sensor

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** Ultrasonic Sensor (e.g., HC-SR04), Level Shifting (recommended)

## Overview

Ultrasonic sensors measure distance by sending a short trigger pulse and timing the returning echo. This project implements a fully digital ultrasonic distance measurement module in the FPGA on the Shrike-Lite board.

The module:

* Generates the trigger signal
* Measures echo duration
* Calculates distance
* Determines whether an object is within a configured range

To understand the working principle, refer to:
https://lastminuteengineers.com/arduino-sr04-ultrasonic-sensor-tutorial/

---

## Compatibility

| Board                | Firmware                | Status     |
| -------------------- | ----------------------- | ---------- |
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` | ✅ Tested   |
| Shrike (RP2350)      | `firmware/arduino-ide/` | ✅ Tested   |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

---

## Hardware Setup

### Block Diagram

![SHrikeLite Ultrasonic block diagram](ffpga/images/ultrasonic_blockdiagram.svg "Block diagram")

---

### Pin Usage for Testing

#### 1. Direct FPGA Output (Standalone Test)

| FPGA Pin | Signal Name     | Direction | Description                        |
| -------- | --------------- | --------- | ---------------------------------- |
| F0       | echo            | Input     | Echo pin from ultrasonic sensor    |
| F1       | trig            | Output    | Trigger pulse to ultrasonic sensor |
| F2       | object_detected | Output    | High when object is in range       |

#### 2. FPGA → MCU Interconnect

| Pin        | Signal Name     | Direction | Description                     |
| ---------- | --------------- | --------- | ------------------------------- |
| F0         | echo            | Input     | Echo pin from ultrasonic sensor |
| F1         | trig            | Output    | Trigger pulse                   |
| F3 + GPIO2 | object_detected | Output    | Detection signal to MCU         |

> Ensure pin mapping matches FPGA constraints and firmware.

---

### Safety NOTE

The `echo` pin of most ultrasonic sensors (e.g., HC-SR04) outputs **5V**, while the FPGA operates at **3.3V**.

To prevent damage:

* Use a **10 kΩ series resistor**, OR
* Use a **voltage divider / level shifter**

**Direct connection may damage FPGA or sensor.**

---

## Quick Start (Pre-Built Bitstream)

1. Connect ultrasonic sensor to FPGA
2. Upload `bitstream/ultrasonic.bin` using ShrikeFlash
3. Upload Arduino firmware
4. Observe detection events on serial terminal

---

## Build From Source

### FPGA (Verilog)

1. Open project in Go Configure Software Hub
2. Add modules and configure parameters
3. Generate bitstream

### Firmware (Arduino)

1. Open `shrikeLite_ultrasonic.ino`
2. Upload to RP2040
3. Open serial monitor

---

## How It Works

### FPGA Modules

1. **ultrasonic_sensor**

   * Generates `trig` pulse
   * Measures `echo` pulse width
   * Determines distance range
   * Outputs clean `object_detected`

2. **top**

   * Instantiates multiple sensors
   * Controlled via `NUM_SENSORS`

---

## Features

* Multi-channel support (`NUM_SENSORS`)
* Configurable trigger pulse width
* Adjustable detection range
* Built-in debounce filtering
* Clean digital outputs

---

## Top Module Interface

| Signal               | Direction | Description            |
| -------------------- | --------- | ---------------------- |
| `clk`                | In        | System clock (50 MHz)  |
| `echo`               | In        | Echo input             |
| `trig`               | Out       | Trigger pulse (~10 µs) |
| `object_detected`    | Out       | Detection output       |
| `trig_en`            | Out       | Always 1               |
| `object_detected_en` | Out       | Always 1               |
| `clk_en`             | Out       | Always 1               |

---

## Parameters Used

### `NUM_SENSORS`

```id="p1"
parameter NUM_SENSORS = 1
```

### `CLK_FREQ`

```id="p2"
parameter CLK_FREQ = 50_000_000
```

### `TRIG_PULSE_US`

```id="p3"
parameter TRIG_PULSE_US = 10
```

### `MAX_DIST_CM`

```id="p4"
parameter MAX_DIST_CM = 20
```

### `SOUND_SPEED_CM_PER_US`

* Speed of sound = 343 m/s
* Converted = 0.0343 cm/µs
* Round trip → divide by 2

```id="p5"
localparam SOUND_SPEED_CM_PER_US = 0.0343 / 2;
```

---

### `MAX_ECHO_TIME_US`

```id="p6"
localparam MAX_ECHO_TIME_US = MAX_DIST_CM / SOUND_SPEED_CM_PER_US;
```

---

### `MAX_COUNT`

```id="p7"
localparam MAX_COUNT = (MAX_ECHO_TIME_US * (CLK_FREQ / 1_000_000));
```

---

### `DEBOUNCE_CNT_LIMIT`

```id="p8"
localparam DEBOUNCE_CNT_LIMIT = 5_00_000;
```

Debounce formula:

```id="p9"
DEBOUNCE_CNT_LIMIT = Debounce_Time / CLK_FREQ
```

---

## Firmware Overview

* `shrikeLite_ultrasonic.ino`

  * Reads FPGA detection signal
  * Prints detection events

---

## Quick Steps (Arduino IDE)

1. Connect hardware as per block diagram
2. Connect board via USB
3. Open Arduino IDE
4. Load sketch
5. Copy bitstream to data folder
6. Upload filesystem (LittleFS)
7. Open serial monitor

---

## Serial Logs

```text id="log1"
(event) When object is in range:
The object is detected

(event) When object is not in range:
The object is not detected
```

---

## Expected Output

* `object_detected = HIGH` → object within range
* `object_detected = LOW` → no object

---

## Notes

* Output can be routed to FPGA GPIO or RP2040

* Refer to pinout:
  https://github.com/vicharak-in/shrike/blob/main/docs/shrike_pinouts.md

* Detection is stable due to debounce filtering
