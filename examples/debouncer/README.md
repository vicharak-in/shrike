# Debouncer Module

Mechanical switches do not change state cleanly when pressed or released. Instead, they bounce rapidly between HIGH and LOW for a few milliseconds, which can cause multiple false triggers in digital logic. A debounce circuit solves this by checking whether the input has remained stable for a fixed period. If the signal stays unchanged long enough, it is accepted as the new valid state; otherwise, it is ignored. This ensures the output is clean, stable, and free from glitches caused by mechanical bouncing.

## Block Diagram
![SHrikeLite debouncer block diagram](ffpga/images/debouncer_blockdiagram.svg "Block diagram")

---
## FPGA overview
- This project consists of two modules :   
    1) `debouncer :` This module contains a hardware debouncer for cleaning noisy input signals such as mechanical switches or push-buttons used as inputs in the Shrike-Lite FPGA. This module ensures that the output only changes state when the input remains stable for a defined duration.
    2) `top : ` A multi-channel top module that instantiates multiple debouncer modules using a generate loop. The number of debouncer instances is controlled by the parameter `NUM_PORTS` 

---

## Features
- Configurable multi-channel support using `NUM_PORTS`
- Eliminates the unwanted bounces made by mechanical swithes  
- Default 10 ms debounce at 50 MHz (can be configurable) 
- Clean, stable output (`o_pulse`)

---

## Module Interface

| Signal        | Direction | Description                          |
|---------------|-----|--------------------------------------|
| `clk`         | In  | System clock (50 MHz typical)        |
| `i_pulse`     | In  | Raw mechanical switch/button input   |
| `o_pulse`     | Out | Debounced output                     |
| `o_pulse_en`  | Out | Output enable (always 1)             |
| `clk_en`      | Out | Clock enable (always 1)              |

---
### Parameters Used
- `DEBOUNCE_CNT_LIMIT :` Parameter to adjust the Debounce duration. This parameter controls the amount of time the input signal must stay unchanged before the module updates the output.
- `NUM_PORTS :` Parameter to adjust the number of the debouncer instances to generate.  
---

## Debounce Time Calculation
The debounce duration is controlled by:

```verilog
localparam DEBOUNCE_CNT_LIMIT = 5_00_000;  // ~10 ms at 50 MHz
```
To change debounce time:
``` 
DEBOUNCE_CNT_LIMIT = (Debounce_Time / Clock_Period)

In this example: 
Debounce_Time = 10 ms (0.1s)
Clock_Period  = 20 ns (for 50MHz)

DEBOUNCE_CNT_LIMIT = Debounce_Time / Clock_Period
                   = 0.01 s / 20 ns
                   = 500,000 cycles
```
--- 

## Pin Usage for Testing
This design was tested using two different output configurations:
#### 1. Direct FPGA Output (Standalone Test)
| FPGA Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| F0       | i_pulse     | Input     | Raw switch/button input signal    |
| F1       | o_pulse     | Output    | Debounced, clean output signal    |

#### 2. FPGA Output Routed to RP2040 MCU (FPGA → MCU Interconnect Test)

|  Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| F0   | i_pulse     | Input     | Raw switch/button input signal    |
| F3 and GPIO2(RP2040)     | o_pulse     | Output    | Debounced, clean output signal    |

When testing through the RP2040 MCU, load the Arduino sketch that reads the FPGA interconnect pin. The pin number in your FPGA constraints must match what is used in the Arduino code.

> **Note:**  
> The output signal `o_pulse` can connected to standard GPIO pin of FPGA, or can also be connected to the RP2040 MCU on the Shrike‑Lite board through any FPGA-to-RP2040 interconnect pins. For details on available interconnections and pin mapping, refer to the [Shrike‑Lite pinout reference](https://github.com/vicharak-in/shrike-lite/blob/main/Docs/shrike_pinouts.md).


## Output Capture

The following screenshot shows the `i_pulse` input (raw switch signal) and the `o_pulse` output (debounced signal) captured on a logic analyzer:

![Debounced Output](ffpga/images/debouncer_output.png)

---
## Firmware Overview
- Firmware support to use FPGA as debouncer for buttons.
    1) `arduino-ide :` shrikeLite_debouncer.ino - demonstrates how to read a debounced button signal on an RP2040 pin from FPGA.
---

Read the firmware file(s) under [firmware](firmware) directory to get an overview on how to interface and test the debouncer example on ShrikeLite.

### Quick steps for Arduino IDE
- Connect the board as per the [block diagram](https://github.com/UpendraReddi/shrike-lite/tree/dev-debouncer/examples/debouncer#block-diagram).
- Connect the board to your machine via USB.
- Open [Arduino IDE](https://github.com/vicharak-in/shrike-lite/blob/main/Docs/getting_started.md#using-it-with-arduinoide) and select the correct board configuration.
- Copy the code or open the ino file in the Arduino IDE.
- Copy the [generated](https://github.com/vicharak-in/shrike-lite/blob/main/Docs/generating_your_first_bitstream.md) [bitstream](ffpga/src/) to [data](https://github.com/vicharak-in/shrike-lite/blob/582c17b042aa2b085ea4249943b5e8b3290207ab/Docs/getting_started.md#step-4-programming-the-fpga-from-arduinoide) folder.
- Build and upload the file system ([littleFS](https://github.com/vicharak-in/shrike-lite/blob/582c17b042aa2b085ea4249943b5e8b3290207ab/Docs/getting_started.md#step-2-adding-the-littlefs-tool)) and the sketch.
- Open the [serial terminal](https://docs.arduino.cc/software/ide-v2/tutorials/ide-v2-serial-monitor/) and view the logs after button press and release events.

### Serial Logs

- **Reading button without debouncer (Read the [sketch](firmware/arduino-ide/shrikeLite_debouncer.ino) for more information)**
```text
The button is released

(Event) Single button press and release :

The button is pressed
The button is released
The button is pressed
The button is released
The button is pressed
The button is released
The button is pressed
The button is released
The button is pressed
The button is released
```

> **Observation:**  
> For a single button press and release event, multiple press and release events have been detected.

- **Reading button with debouncer on FPGA**
```text
[ShrikeFlash] Initialized successfully
[ShrikeFlash] Starting FPGA flash...
[ShrikeFlash] Flashing: /debouncer_generic.bin
[ShrikeFlash] File size: 46408 bytes
[ShrikeFlash] FPGA programming done.
[ShrikeFlash] Time: 309 ms, Rate: 146.67 KB/s
The button is released

(event) On button Press:
The button is pressed

(event) On button Release:
The button is released
```

> **Observation:**  
> For a single button press and release event, the associated events have been reported succesfully.
> No multiple event log reported as the previous one.
