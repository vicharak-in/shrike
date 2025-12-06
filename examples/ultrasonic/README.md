## Ultrasonic Sensor Module
Ultrasonic sensors measure distance by sending a short trigger pulse and timing the returning echo. This project implements a fully-digital ultrasonic distance measurement module in the FPGA on the Shrike-Lite board. The module generates the trigger signal, measures the echo duration, calculates the distance, and determines whether an object is within a configured range.

To understand the working principle of Ultrasonic Sensor distance sensing, refer to:
[Ultrasonic Sensor Tutorial](https://lastminuteengineers.com/arduino-sr04-ultrasonic-sensor-tutorial/).

---
## Block Diagram
![SHrikeLite Ultrasonic block diagram](ffpga/images/ultrasonic_blockdiagram.svg "Block diagram")

## Overview on FPGA side
- This project consists of two modules :   
    1) `ultrasonic_sensor :` This module implements the ultrasonic interface.
        - Generates a `trig` pulse
        - Measures the `echo` pulse width
        - Computes whether the object is within the configured distance range.
        - Provides a debounced(noise less) output `object_detected`
    2) `top : ` A multi-channel top module that instantiates multiple ultrasonic_sensor modules using a generate loop. 
        - The number of sensors is controlled by the `NUM_SENSORS` parameter. 

---

## Features
- Configurable multi-channel support using `NUM_SENSORS`
- Configurable trigger pulse width 
- Adjustable maximum detection range 
- Built-in debounce filter to eliminate noise in detection output
- Generates clean `trig` and `object_detected` signals

---

## Top Module Interface

| Signal        | Direction | Description                          |
|---------------|-----|--------------------------------------|
| `clk`         | In  | System clock (50 MHz typical)        |
| `echo`        | In  | Echo input from ultrasonic sensors   |
| `trig`        | Out | Trigger pulse output (10 µs default) |
| `object_detected`  | Out | High if object detected within range              |
| `trig_en`     | Out | Output enable for trig (always 1)              |
| `object_detected_en`      | Out | Output enable for detection output (always 1)  |
| `clk_en`      | Out | Clock enable (always 1)              |

---

## Parameters Used
#### `NUM_SENSORS :` 
- Parameter to configure number of ultrasonic sensor interfaces to generate.
    - `parameter NUM_SENSORS = 1`
#### `CLK_FREQ :` 
- Parameter to represent the System clock frequency in Hz.
    -  `parameter CLK_FREQ = 50_000_000`
#### `TRIG_PULSE_US :` 
- Parameter to configure Trigger pulse width in µs.
     - `parameter TRIG_PULSE_US = 10`
#### `MAX_DIST_CM :` 
- Parameter to configure the Maximum valid detection distance in cm. 
    - `parameter MAX_DIST_CM = 20`
#### `SOUND_SPEED_CM_PER_US :` 
- This value is the Speed of Sound, which is `343 (m/s)`. 
    - Let’s convert the speed of sound from meters per second (m/s) to centimeters per microsecond (cm/µs), which comes out to be `0.0343 cm/µs`. 
    -  The pulse duration represents the round-trip time – the time it took for sound to travel to the object and back to the sensor. So to get the actual distance, we need to divide by 2: ` => (0.0343/2) in cm/µs`
    - `localparam SOUND_SPEED_CM_PER_US = 0.0343 / 2;`
#### `MAX_ECHO_TIME_US : `
- This parameter is to calculate the maximum echo time that it will take from the sensor to max distance range we configured ` MAX_DIST_CM`. It determines as:
    - `localparam MAX_ECHO_TIME_US  = MAX_DIST_CM/SOUND_SPEED_CM_PER_US;`
#### `MAX_COUNT :`
- This parameter is to represent number of clock cycles corresponding to the maximum echo time: `MAX_ECHO_TIME_US`.
    - `localparam MAX_COUNT = (MAX_ECHO_TIME_US * (CLK_FREQ / 1_000_000));`
#### `DEBOUNCE_CNT_LIMIT :`
- Clock cycles used for output-debounce filtering.
    - `localparam DEBOUNCE_CNT_LIMIT = 5_00_000;  // ~10 ms at 50 MHz`
    - To change debounce time:
`DEBOUNCE_CNT_LIMIT = (Debounce_Time / CLK_FREQ)`
---

## Pin Usage for Testing
This design was tested using two different output configurations:
#### 1. Direct FPGA Output (Standalone Test)
| FPGA Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| F0       | echo     | Input     | Echo pin from ultrasonic sensor    |
| F1       | trig     | Output    | Trigger pulse to ultrasonic sensor    |
| F2       | object_detected     | Output    | Signal goes high if object is in range     |

#### 2. FPGA Output Routed to RP2040 MCU (FPGA → MCU Interconnect Test)

|  Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| F0   | echo     | Input     | Echo pin from ultrasonic sensor    |
| F1       | trig     | Output    | Trigger pulse to ultrasonic sensor    |
| F3 and GPIO2(RP2040)     | object_detected     | Output    | Signal goes high if object is in range    |


When testing through the RP2040 MCU, load the Arduino sketch that reads the FPGA interconnect pin. The pin number in your FPGA constraints must match what is used in the Arduino code.

> **Note:**  
> The output signal `object_detected` can connected to standard GPIO pin of FPGA, or can also be connected to the RP2040 MCU on the Shrike‑Lite board through any FPGA-to-RP2040 interconnect pins. For details on available interconnections and pin mapping, refer to the [Shrike‑Lite pinout reference](https://github.com/vicharak-in/shrike-lite/blob/main/Docs/shrike_pinouts.md).
---

### Safety NOTE:
The `Echo pin` of most ultrasonic sensors `(such as HC-SR04)` outputs a 5V signal, while the Shrike-Lite FPGA board operates at 3.3V logic. 

To avoid damaging the FPGA or the sensor:
- Use a 10 kΩ series resistor on the Echo line  or
- Use a proper voltage divider or level shifter to convert 5V → 3.3V.

- Connecting the Echo pin directly to the FPGA without level shifting may permanently damage the FPGA GPIO pin or ultrasonic sensor.

---
## Firmware Overview
- Firmware support to use FPGA as Object Detector for ultrasonic.
    1) `arduino-ide :` shrikeLite_ultrasonic.ino - demonstrates how to read a object detection signal on an RP2040 pin from FPGA.
---

Read the firmware file(s) under [firmware](firmware) directory to get an overview on how to interface and test the ultrasonic example on ShrikeLite.

### Quick steps for Arduino IDE
- Connect the board as per the [block diagram](https://github.com/UpendraReddi/shrike-lite/tree/dev-ultrasonic_sensor/examples/ultrasonic#block-diagram).
- Connect the board to your machine via USB.
- Open [Arduino IDE](https://github.com/vicharak-in/shrike-lite/blob/main/Docs/getting_started.md#using-it-with-arduinoide) and select the correct board configuration.
- Copy the code or open the ino file in the Arduino IDE.
- Copy the [generated](https://github.com/vicharak-in/shrike-lite/blob/main/Docs/generating_your_first_bitstream.md) [bitstream](ffpga/src/) to [data](https://github.com/vicharak-in/shrike-lite/blob/582c17b042aa2b085ea4249943b5e8b3290207ab/Docs/getting_started.md#step-4-programming-the-fpga-from-arduinoide) folder.
- Build and upload the file system ([littleFS](https://github.com/vicharak-in/shrike-lite/blob/582c17b042aa2b085ea4249943b5e8b3290207ab/Docs/getting_started.md#step-2-adding-the-littlefs-tool)) and the sketch.
- Open the [serial terminal](https://docs.arduino.cc/software/ide-v2/tutorials/ide-v2-serial-monitor/) and view the logs after button press and release events.

### Serial Logs

- **Logs got for  object detection with ultrasonic project on FPGA**
```text
[ShrikeFlash] Initialized successfully
[ShrikeFlash] Starting FPGA flash...
[ShrikeFlash] Flashing: /ultrasonic.bin
[ShrikeFlash] File size: 46408 bytes
[ShrikeFlash] FPGA programming done.
[ShrikeFlash] Time: 309 ms, Rate: 146.67 KB/s
[ShrikeFlash] Initialized successfully
[ShrikeFlash] Starting FPGA flash...
[ShrikeFlash] Flashing: /ultrasonic.bin
[ShrikeFlash] File size: 46408 bytes
[ShrikeFlash] FPGA programming done.
[ShrikeFlash] Time: 309 ms, Rate: 146.67 KB/s

(event) When object is in range:
The object is detected

(event) When object is not in range:
The object is not detected
```

> **Observation:**  
> If the Object is in range or not, it reports the event accordingly

