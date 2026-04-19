# morse_blink

**Difficulty:** Intermediate

**Uses MCU:** Yes (micropython firmware)

**External Hardware:** None

## Overview

Receives ASCII characters from the RP2040 over UART and blinks the onboard LED in standard Morse code. Dot duration is ~200 ms; dashes are 3× that. The FPGA idles between characters, so strings can be paced from the MCU side.

Supported characters: A–Z (case-insensitive), 0–9. Unsupported characters are silently ignored.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested |
| Shrike (RP2350) | `firmware/micropython/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware is required.

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB
2. Upload `bitstream/morse_blink.bin` using shrike.flash
3. Then use `send_morse_string` from firmware micropython to flash any string in morse code.
   example: `send_morse_string("hi")`

## Build From Source

### FPGA (Verilog)
1. Open `morse_blink.ffpga` in Go Configure Software Hub
2. Click Synthesize → Generate Bitstream
3. Output will be in `ffpga/build/`

## How It Works

The design is built around a three-state FSM (`IDLE → ON → OFF`) running on the 50 MHz system clock.

**State machine**

In `IDLE`, the FSM waits for a valid byte from the UART RX module. When one arrives, the byte is decoded into an 8-bit `morse_pattern` register and a 4-bit `morse_len` counter using a direct character-to-pattern lookup table. Bit `0` in the pattern represents a dot; bit `1` represents a dash. Symbols are stored MSB-first so they can be read out sequentially by incrementing `index`. Once decoded, the FSM moves to `ON`.

In `ON`, the LED is driven high for either `DOT_TIME` or `DASH_TIME` cycles, depending on the current bit in `morse_pattern`. When the counter expires the FSM moves to `OFF`.

In `OFF`, the LED is driven low for exactly `DOT_TIME` cycles (the standard inter-element gap). After the gap, if more symbols remain the FSM returns to `ON` for the next one; otherwise it returns to `IDLE`.

**Timing**

`DOT_TIME` is derived as `CLK / 5`, giving 200 ms at 50 MHz. `DASH_TIME` is `3 × DOT_TIME` (600 ms), matching the standard Morse ratio. To change blink speed, adjust the divisor directly in the Verilog source; all other timing scales automatically.

## MCU Firmware Script (MicroPython)

**How it works**

A MicroPython script serves as the firmware for this example. It runs automatically upon boot if it is saved as "`main.py`" on the board storage. Otherwise you may include "`import morse_blink`" in your `main.py`. 

The command for flashing the FPGA is commented out. To flash the FPGA, you must uncomment it and change the argument to the relative path of your bitstream on the shrike board.

Once run, it defines and automatically calls a function `morse_loop()` which lets you interactively input sentences and watch them be blinked on the LED in Morse code by the FPGA. Under the hood it sends each character of your input string to the FPGA one by one through UART over internally connected pins. Why the characters are sent with some wait between them is explained in the next subsection. 

In MicroPython REPL if you do not wish to invoke the interactive input loop; you also have the option to send a single string manually by using the `send_morse_string()` method defined in the script. 

**Why the MCU paces sends**

The UART RX module (taken from the `uart_sum` example [here](https://github.com/vicharak-in/shrike/blob/main/examples/uart_sum/ffpga/src/uart_rx.v)) asserts `data_valid` for one clock cycle when a complete byte has been received. The FPGA only samples `data_valid` in `IDLE`, so any byte that arrives while the FSM is in `ON` or `OFF` is silently dropped. There is no input buffer by design. This keeps the hardware minimal and the timing deterministic, but it means the MCU must wait for the FPGA to finish blinking before sending the next character. The companion script handles this with `char_duration()`, which estimates the total blink time for each character and adds a small margin.

**Notes**

- Any characters received from the MCU are ignored if some other character is currently being blinked.
- No inter-letter gap state exists in the FPGA. The 7-dot word gap and any letter spacing are entirely the MCU's responsibility.
- Characters with no valid mapping (unsupported bytes) set `morse_len` to zero and the FSM stays in `IDLE`, effectively dropping them.

## Expected Output

You will see an LED on the circuit board blink in morse code corresponding to whatever string you provided to the `send_morse_string` function. 
