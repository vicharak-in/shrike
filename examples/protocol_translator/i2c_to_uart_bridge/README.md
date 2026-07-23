# I2C to UART Bridge

**Difficulty:** Intermediate

**Uses MCU:** Yes

**External Hardware:** None for the self-test (an external I²C **master** for real use)

## Overview

This example turns the Shrike FPGA into a **bidirectional I²C ⇄ UART bridge**.

On this bridge the **FPGA is an I²C *slave*** (address `0x50`) with a full-duplex
UART link on the other side. An **external I²C master** drives the I²C bus and
talks to the FPGA; whatever it writes comes out on UART, and whatever arrives on
UART is handed back the next time the master reads. The two directions are
independent:

```
   External I²C MASTER  ⇄  FPGA (I²C slave @ 0x50)  ⇄  UART peer
   master WRITE 0x50 ───────────────────────────────►  byte out on UART TX
   master READ  0x50 ◄───────────────────────────────  byte in from UART RX
```

Because I²C is a master/slave bus, the device on the I²C side **must be a
master** (a host MCU, a Raspberry Pi, a bench I²C tool, …). A plain sensor is a
slave and will **not** work here — for a sensor you want the `uart_to_i2c`
example instead (there the FPGA is the I²C master).

## Compatibility

| Board                | Firmware                | Status      |
| -------------------- | ----------------------- | ----------- |
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested   |
| Shrike (RP2350)      | `firmware/micropython/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ⬜ Untested |

> The FPGA bitstream is the same across all boards. The RP2350 self-test uses
> the RP2040 I²C register addresses only where noted (not needed here — the
> RP2040 is a plain I²C master in this example).

## Hardware Setup

For the **board-only self-test** no external parts are needed: the RP2040 plays
the external I²C master (over its own I²C1) **and** the UART peer, all through
the fixed on-board RP2040↔FPGA wiring.

### Pinout (FPGA I²C slave + UART)

| Function        | FPGA GPIO | FPGA PIN | RP2040 pin | Direction on FPGA |
| --------------- | :-------: | :------: | :--------: | ----------------- |
| UART RX (in)    | GPIO6     | 19       | GP0 (TX)   | input             |
| UART TX (out)   | GPIO4     | 17       | GP1 (RX)   | output            |
| I²C **SCL**     | GPIO17    | 8        | GP15       | **input only**    |
| I²C **SDA**     | GPIO18    | 9        | GP14       | bidir (open-drain)|
| Clock           | internal 50 MHz oscillator | — | — | —          |

> As an I²C **slave** the FPGA never drives the clock, so **SCL is input-only**
> (no `o_i2c_scl`). SDA is open-drain: `o_i2c_sda` is held `0` and the line is
> pulled low only when `o_i2c_sda_oe` is high.

### Connecting a real external I²C master

1. Wire the master to the FPGA I²C pins:

   | Master signal | FPGA pin |
   | ------------- | -------- |
   | SDA           | PIN 9 (GPIO18) |
   | SCL           | PIN 8 (GPIO17) |
   | GND           | any GND (shared) |

2. Add **pull-up resistors** (~4.7 kΩ) on SDA and SCL to **3V3**.
3. Use **3.3 V** logic (level-shift a 5 V master).
4. The FPGA answers at I²C address **`0x50`**.
5. **Only one master on the bus** — if an external master is connected, do **not**
   also run I²C on the RP2040; load a UART-only script there.

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike board over USB.
2. Flash `bitstream/i2c_to_uart_bridge.bin` to the FPGA (ShrikeFlash / `shrike.flash`).
3. Upload and run `firmware/micropython/i2c_to_uart_bridge.py` on the RP2040.
4. Watch the REPL — it runs both directions and prints `STATUS: SUCCESS`.

## Build From Source

### FPGA (Verilog)

1. Open the project in **Renesas Go Configure Software Hub**.
2. Add the Verilog files from `ffpga/src/`:
   `top.v`, `i2c_slave_core.v`, `sync_fifo.v`, `uart_rx.v`, `uart_tx.v`.
3. In the **I/O Planner**, assign (data → **OUT** slot, enable → **OE** slot):

   | RTL signal      | GPIO   | slot |
   | --------------- | ------ | ---- |
   | `i_uart_rx`     | GPIO6  | IN   |
   | `o_uart_tx`     | GPIO4  | OUT  |
   | `o_uart_tx_oe`  | GPIO4  | OE   |
   | `i_i2c_scl`     | GPIO17 | IN   |
   | `i_i2c_sda`     | GPIO18 | IN   |
   | `o_i2c_sda`     | GPIO18 | OUT  |
   | `o_i2c_sda_oe`  | GPIO18 | OE   |
   | `clk` / `clk_en`| internal OSC (50 MHz) | — |

   > ⚠️ Common mistake: putting `o_i2c_sda_oe` in the OUT slot and `o_i2c_sda`
   > in the OE slot. That ties the enable to constant 0 so the FPGA never drives
   > SDA and never ACKs (`i2c.scan()` returns `[]`). The `*_oe` signal always
   > goes in the **OE** slot.

4. Generate the bitstream and program the board.

### Firmware (MicroPython)

1. Upload `firmware/micropython/i2c_to_uart_bridge.py`.
2. Run it. The RP2040 uses `machine.I2C(1)` as master and `machine.UART(0)` as
   the peer — no register pokes needed.

## How It Works

- **I²C → UART:** an I²C write to `0x50` fires `o_rx_valid` in `i2c_slave_core`;
  the byte is pushed into a small FIFO that the UART transmitter drains onto
  `o_uart_tx`.
- **UART → I²C:** each byte received by `uart_rx` is stored in a *latest-byte
  register*; when the master reads `0x50`, the FPGA returns that byte. A register
  (not a pop-on-read FIFO) is used here so the read is robust to real I²C timing.

The two paths never block each other, so the bridge is genuinely two-way.

## Expected Output

```text
I2C scan: ['0x50']

=== UART <-> I2C bidirectional self-test ===

-- Direction 1: I2C write -> UART out --
-- Direction 2: UART in -> I2C read --

Passed 64 / 64
STATUS: SUCCESS
```
