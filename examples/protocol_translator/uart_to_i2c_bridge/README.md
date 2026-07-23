# UART to I2C Bridge

**Difficulty:** Intermediate

**Uses MCU:** Yes (RP2040)

**External Hardware:** None for the self-test (an external I²C **slave / sensor** for real use)

## Overview

This example makes the Shrike FPGA a **UART ⇄ I²C bridge where the FPGA is the
I²C *master*** — so it can talk directly to an **external I²C slave / sensor**.

A UART peer sends a byte; the FPGA writes it to the I²C slave, reads the slave
back, and echoes the reply out on UART. So one UART byte drives **both**
directions:

```
   UART peer  ⇄  FPGA (I²C MASTER)  ⇄  External I²C SLAVE / sensor (addr 0x50)
   UART byte in ─────► I²C WRITE to slave                 (UART -> I²C)
   UART echo out ◄──── I²C READ from slave (slave reply)  (I²C -> UART)
```

Because the FPGA is the master, the thing on the I²C side **must be a slave**
(a sensor, EEPROM, etc.). This is the mirror of the `i2c_to_uart` example (where
the FPGA is the I²C slave and an external master drives it).

## Compatibility

| Board                | Firmware                | Status      |
| -------------------- | ----------------------- | ----------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested   |
| Shrike (RP2350)      | `firmware/micropython/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> RP2350 note: the board-only self-test emulates the I²C slave on the RP2040 via
> register writes at `I2C1_BASE = 0x40048000` (RP2040-specific; RP2350 differs).
> A real external sensor needs no such emulation.

## Hardware Setup

For the **board-only self-test**, the RP2040 plays two roles over the fixed
on-board wiring: the **UART peer** and an **emulated I²C slave** (the "sensor").
For real use, replace that emulated slave with an actual sensor on the I²C pins.

### Pinout (FPGA UART + I²C master)

| Function        | FPGA GPIO | FPGA PIN | RP2040 pin | Direction on FPGA |
| --------------- | :-------: | :------: | :--------: | ----------------- |
| UART RX (in)    | GPIO6     | 19       | GP0 (TX)   | input             |
| UART TX (out)   | GPIO4     | 17       | GP1 (RX)   | output            |
| I²C **SCL**     | GPIO17    | 8        | GP15       | **bidir (driven)**|
| I²C **SDA**     | GPIO18    | 9        | GP14       | bidir (open-drain)|
| Clock           | internal 50 MHz oscillator | — | — | —          |

> As an I²C **master** the FPGA **drives the clock**, so **SCL is a driven,
> open-drain pin** — it uses `o_i2c_scl` + `o_i2c_scl_oe` in addition to
> `i_i2c_scl` (unlike `i2c_to_uart`, where SCL is input-only).

### Connecting a real external I²C slave / sensor

1. Wire the sensor to the FPGA I²C pins:

   | Sensor signal | FPGA pin |
   | ------------- | -------- |
   | SDA           | PIN 9 (GPIO18) |
   | SCL           | PIN 8 (GPIO17) |
   | GND / VCC     | GND + 3V3 |

2. Add **pull-up resistors** (~4.7 kΩ) on SDA and SCL to **3V3**.
3. Set the sensor's I²C address in `top.v` → `localparam I2C_ADDR` (default `0x50`).
4. Use **3.3 V** logic.
5. The FPGA is the only master; drive the UART side from a host / the RP2040.

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike board over USB.
2. Flash `bitstream/uart_to_i2c_bridge.bin` to the FPGA.
3. Upload and run `firmware/micropython/uart_to_i2c_bridge.py`.
4. The REPL runs both directions and prints `STATUS: SUCCESS`.

## Build From Source

### FPGA (Verilog)

1. Open the project in **Go Configure Software Hub**.
2. Add the Verilog files from `ffpga/src/`:
   `top.v`, `i2c_master_core.v`, `uart_rx.v`, `uart_tx.v`.
   *(Do not add `i2c_slave_core.v` / `sync_fifo.v` — they belong to the
   slave-side variant and are unused here.)*
3. In the **I/O Planner**, assign (data → **OUT** slot, enable → **OE** slot):

   | RTL signal      | GPIO   | slot |
   | --------------- | ------ | ---- |
   | `i_uart_rx`     | GPIO6  | IN   |
   | `o_uart_tx`     | GPIO4  | OUT  |
   | `o_uart_tx_oe`  | GPIO4  | OE   |
   | `i_i2c_scl`     | GPIO17 | IN   |
   | `o_i2c_scl`     | GPIO17 | OUT  |
   | `o_i2c_scl_oe`  | GPIO17 | OE   |
   | `i_i2c_sda`     | GPIO18 | IN   |
   | `o_i2c_sda`     | GPIO18 | OUT  |
   | `o_i2c_sda_oe`  | GPIO18 | OE   |
   | `clk` / `clk_en`| internal OSC (50 MHz) | — |

   > ⚠️ Because the FPGA is the master, **SCL must be driven** — you must add
   > `o_i2c_scl` (OUT) and `o_i2c_scl_oe` (OE) on GPIO17. If SCL is left
   > input-only the master can't clock the bus and every transfer times out.
   > As always, each `*_oe` goes in the **OE** slot.

4. Generate the bitstream and program the board.

### Firmware (MicroPython)

1. Upload `firmware/micropython/uart_to_i2c_bridge.py`.
2. For the self-test it configures the RP2040 I²C1 as a slave at `0x50`
   (reply = `byte + 0x10`) via register writes. For a real sensor, delete that
   emulation and just drive the UART side.

## How It Works

For each UART byte `X` the bridge FSM runs one command cycle:

1. `uart_rx` captures `X` → sets `rx_pending`.
2. **BR_I2C_WRITE:** `i2c_master_core` performs an I²C write of `X` to the slave.
3. **BR_I2C_READ:** the FPGA performs an I²C read from the slave.
4. **BR_UART_ECHO:** the read byte is transmitted back on `o_uart_tx`.

If the slave NACKs, the FPGA returns `0xEE` as an error marker.

## Expected Output

```text
=== uart_to_i2c self-test (FPGA I2C master; RP2040 = slave) ===

Passed 32 / 32
STATUS: SUCCESS
```
