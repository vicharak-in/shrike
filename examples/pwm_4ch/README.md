# pwm_4channel

**Difficulty:** Intermediate

**Uses MCU:** No

**External Hardware:** None

## Overview

This example demonstrates a **4-channel PWM system implemented on FPGA**, where each channel drives an LED with independently controlled PWM frequency and duty-cycle modulation.

The PWM outputs are enhanced with a **dynamic ramp (breathing effect)**, showing how duty cycle can be varied over time using hardware logic. Additionally, the design includes sequential control and auxiliary blinking patterns on extra LEDs.

This example teaches multi-channel PWM generation, duty-cycle control, and sequencing using FPGA.

## Compatibility

| Board                | Firmware                | Status   |
| -------------------- | ----------------------- | -------- |
| Shrike-Lite (RP2040) | `firmware/arduino-ide/` | ✅ Tested |
| Shrike (RP2350)      | `firmware/arduino-ide/` | ✅ Tested |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ✅ Tested |

> FPGA bitstream is the same across all boards.

---

## Hardware Setup

No external hardware required.

* Uses onboard LEDs (`led_0` → `led_7`)
* Internal oscillator enabled via `osc_en`

---

## Quick Start (Pre-Built Bitstream)

1. Connect Shrike board via USB
2. Upload `bitstream/pwm_4channel.bin` using ShrikeFlash
3. Expected result:

   * LEDs 0–3 show PWM-based brightness variation
   * LEDs 4–7 show sequential blinking patterns

---

## Build From Source

### FPGA (Verilog)

1. Open project in Go Configure Software Hub
2. Use:

   * `DemoSequentialBreathing` (top module)
   * `breathing` (PWM engine)
3. Configure I/O mapping
4. Generate bitstream

### Firmware

No firmware required for this example.

---

## How It Works

The design consists of:

---

### 1. 4-Channel PWM Engine

Channels:

* `led_0`
* `led_1`
* `led_2`
* `led_3`

Each channel is an instance of the `breathing` module.

#### PWM Parameters

| LED   | PWM Frequency | Ramp Multiplier |
| ----- | ------------- | --------------- |
| LED 0 | 50 Hz         | 1               |
| LED 1 | 100 Hz        | 1               |
| LED 2 | 500 Hz        | 2               |
| LED 3 | 1000 Hz       | 2               |

---

### PWM Core Logic

The PWM is implemented using:

* `cnt_pwm_reg` → PWM counter
* `cnt_duty_reg` → duty cycle
* `dir_reg` → ramp direction

```verilog id="pwm1"
out <= (dir_reg==0)
       ? ((cnt_pwm_reg < cnt_duty_reg) ? 1 : 0)
       : ((cnt_pwm_reg < cnt_duty_reg) ? 0 : 1);
```

* Duty cycle increases/decreases automatically → breathing effect
* Frequency controlled via clock division

---

### Timing Control

```verilog id="pwm2"
localparam CNT_SLOW = IN_CLK_HZ / PWM_FREQ_HZ / (2**DEPTH);
```

* Controls PWM update rate
* Ensures correct frequency generation

---

### Completion Signal

Each PWM channel generates a `done` signal:

```verilog id="pwm3"
assign done = ~dir_fedge[0] & dir_fedge[1];
```

* Indicates one full breathing cycle complete
* Used for sequencing

---

## Sequential Control Logic

* `seq_counter` selects active LED
* `en = 8'b1 << seq_counter` enables one channel at a time

```verilog id="pwm4"
assign en = 8'b1 << seq_counter;
assign next = |done;
```

* When a channel completes → next channel is activated

---

## Additional LED Patterns (LED 4–7)

| LED   | Frequency |
| ----- | --------- |
| LED 4 | 1 Hz      |
| LED 5 | 2 Hz      |
| LED 6 | 4 Hz      |
| LED 7 | 8 Hz      |

```verilog id="pwm5"
localparam BLINK_1HZ = 25_000_000;
localparam BLINK_2HZ = 12_500_000;
localparam BLINK_4HZ = 6_250_000;
localparam BLINK_8HZ = 3_125_000;
```

* Each LED blinks 10 times before moving to next state

---

## Expected Output

* LED 0–3 → PWM-based brightness variation (breathing)
* LED 4–7 → sequential blinking at increasing frequencies
* System cycles continuously

---

## Notes

* This is a **multi-channel PWM system with dynamic duty cycle modulation**

* Fully hardware-driven (no MCU required)

* Demonstrates:

  * Multi-channel PWM
  * Duty-cycle control
  * Frequency scaling
  * State-machine sequencing

* Based on provided Verilog implementation 
