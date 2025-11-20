# Debouncer Module

Mechanical switches do not change state cleanly when pressed or released. Instead, they bounce rapidly between HIGH and LOW for a few milliseconds, which can cause multiple false triggers in digital logic. A debounce circuit solves this by checking whether the input has remained stable for a fixed period. If the signal stays unchanged long enough, it is accepted as the new valid state; otherwise, it is ignored. This ensures the output is clean, stable, and free from glitches caused by mechanical bouncing.

---
## Overview
This project contains a hardware debouncer module for cleaning noisy input signals such as mechanical switches or push-buttons used as inputs in the Shrike-Lite FPGA. The module ensures that the output only changes state when the input remains stable for a defined duration.

---

## Features
- Eliminates the unwanted bounces made by mechanical swithes  
- Default 10 ms debounce at 50 MHz  
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

## Debounce Timing
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

## Pin Usage for Testing

| FPGA Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| F0       | i_pulse     | Input     | Raw switch/button input signal    |
| F1       | o_pulse     | Output    | Debounced, clean output signal    |

## Pin Usage for Testing

| FPGA Pin | Signal Name | Direction | Description                       |
|----------|-------------|-----------|-----------------------------------|
| F0       | i_pulse     | Input     | Raw switch/button input signal    |
| F1       | o_pulse     | Output    | Debounced, clean output signal    |

> **Note:**  
> The F1 pin used for `o_pulse` is a standard GPIO pin. This output can also be connected to the RP2040 MCU on the Shrike‑Lite board through any FPGA-to-RP2040 interconnect pins. For details on available interconnections and pin mapping, refer to the [Shrike‑Lite pinout reference](https://github.com/vicharak-in/shrike-lite/blob/main/Docs/shrike_pinouts.md).

## Output Capture

The following screenshot shows the `i_pulse` input (raw switch signal) and the `o_pulse` output (debounced signal) captured on a logic analyzer:

![Debounced Output](ffpga/images/debouncer_output.png)


