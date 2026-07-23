# SPI to I2C Bridge

**Difficulty:** Intermediate

**Uses MCU:** Yes (RP2040)

**External Hardware:** None for the self-test (an external I²C **slave / sensor** for real use)

## Overview

This example makes the Shrike FPGA an **SPI ⇄ I²C bridge**. The **FPGA is an SPI
*slave*** on one side and the **I²C *master*** on the other. An SPI host (the
RP2040) sends a command byte; the FPGA writes it to an external I²C slave/sensor,
reads the slave back, and returns the reply on the next SPI read:

```
   SPI host (master)  ⇄  FPGA (SPI slave + I²C MASTER)  ⇄  I²C slave / sensor (0x50)
   SPI write X ─────► I²C WRITE X to slave                    (SPI -> I²C)
               ─────► I²C READ  slave (reply)
   SPI read    ◄───── reply byte on MISO                      (I²C -> SPI)
```

Each value uses **two SPI transactions**: a command byte, then a dummy
read-back to clock the reply out on MISO. A transaction-tracking flag discards
that dummy, so **`0x00` is a fully legal payload**.

## Compatibility

| Board                | Firmware                | Status      |
| -------------------- | ----------------------- | ----------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested   |
| Shrike (RP2350)      | `firmware/micropython/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> RP2350 note: the board-only self-test emulates the I²C slave on the RP2040 via
> register writes at `I2C1_BASE = 0x40048000` (RP2040-specific; RP2350 differs).

## Hardware Setup

For the **board-only self-test** the RP2040 plays the **SPI master** and also
**emulates the I²C slave** (the "sensor"), all over the fixed on-board wiring.
For real use, put an actual sensor on the I²C pins.

### Pinout (FPGA SPI slave + I²C master)

| Function        | FPGA GPIO | FPGA PIN | RP2040 pin | Direction on FPGA |
| --------------- | :-------: | :------: | :--------: | ----------------- |
| SPI SCLK        | GPIO3     | 16       | GP2        | input             |
| SPI SS / CS     | GPIO4     | 17       | GP1        | input             |
| SPI MOSI        | GPIO5     | 18       | GP3        | input             |
| SPI MISO        | GPIO6     | 19       | GP0        | output            |
| I²C **SCL**     | GPIO17    | 8        | GP15       | **bidir (driven)**|
| I²C **SDA**     | GPIO18    | 9        | GP14       | bidir (open-drain)|
| Clock           | internal 50 MHz oscillator | — | — | —          |

> SPI: the FPGA is the **slave**, so SCLK/SS/MOSI are inputs and MISO is the only
> output (`o_spi_miso_oe = ~i_spi_ss`). I²C: the FPGA is the **master**, so
> **SCL is driven** (`o_i2c_scl` + `o_i2c_scl_oe`), like `uart_to_i2c`.

### Connecting a real external I²C slave / sensor

1. Wire the sensor to the FPGA I²C pins:

   | Sensor signal | FPGA pin |
   | ------------- | -------- |
   | SDA           | PIN 9 (GPIO18) |
   | SCL           | PIN 8 (GPIO17) |
   | GND / VCC     | GND + 3V3 |

2. Add **pull-up resistors** (~4.7 kΩ) on SDA and SCL to **3V3**, 3.3 V logic.
3. Set the sensor address in `top.v` → `localparam TARGET_SLAVE_ADDR` (default `0x50`).
4. The SPI host (RP2040) stays the SPI master and drives the command/read-back.

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike board over USB.
2. Flash `bitstream/spi_to_i2c_bridge.bin` to the FPGA.
3. Upload and run `firmware/micropython/spi_to_i2c_bridge.py`.
4. The REPL runs both directions and prints `STATUS: SUCCESS`.

## Build From Source

### FPGA (Verilog)

1. Open the project in **Go Configure Software Hub**.
2. Add the Verilog files from `ffpga/src/`:
   `top.v`, `spi_slave.v`, `i2c_master_core.v`.
   *(Do not add `i2c_slave_core.v` / `sync_fifo.v` — unused in this variant.)*
3. In the **I/O Planner**, assign (data → **OUT** slot, enable → **OE** slot):

   | RTL signal      | GPIO   | slot |
   | --------------- | ------ | ---- |
   | `i_spi_sck`     | GPIO3  | IN   |
   | `i_spi_ss`      | GPIO4  | IN   |
   | `i_spi_mosi`    | GPIO5  | IN   |
   | `o_spi_miso`    | GPIO6  | OUT  |
   | `o_spi_miso_oe` | GPIO6  | OE   |
   | `i_i2c_scl`     | GPIO17 | IN   |
   | `o_i2c_scl`     | GPIO17 | OUT  |
   | `o_i2c_scl_oe`  | GPIO17 | OE   |
   | `i_i2c_sda`     | GPIO18 | IN   |
   | `o_i2c_sda`     | GPIO18 | OUT  |
   | `o_i2c_sda_oe`  | GPIO18 | OE   |
   | `clk` / `clk_en`| internal OSC (50 MHz) | — |

   > ⚠️ The FPGA is the I²C master, so **SCL must be driven** — add `o_i2c_scl`
   > (OUT) and `o_i2c_scl_oe` (OE) on GPIO17. Each `*_oe` goes in the **OE** slot
   > (this includes `o_spi_miso_oe` and `o_i2c_sda_oe`). A missing SCL drive or a
   > swapped OUT/OE hangs the I²C bus.

4. Generate the bitstream and program the board.

### Firmware (MicroPython)

1. Upload `firmware/micropython/spi_to_i2c_bridge.py`.
2. For the self-test it configures the RP2040 I²C1 as a slave at `0x50`
   (reply = `byte + 0x05`) via register writes. For a real sensor, drop that
   emulation and just drive the SPI side.

## How It Works

For each SPI command byte `X` the bridge FSM runs:

1. `spi_slave` captures `X` → sets `rx_pending` (unless it is the dummy
   read-back byte, which `expect_readback` discards).
2. **BR_I2C_WRITE:** `i2c_master_core` writes `X` to the I²C slave.
3. **BR_WAIT_SLAVE:** a short turnaround delay.
4. **BR_I2C_READ:** the FPGA reads the slave; the byte is placed in the SPI TX
   buffer (`0xEE` on NACK).
5. The SPI host's next (dummy) read clocks that byte out on MISO.

## Expected Output

```text
=== SPI <-> I2C self-test (FPGA SPI slave + I2C master; RP2040 = SPI master + I2C slave) ===

Passed 32 / 32
STATUS: SUCCESS
```
