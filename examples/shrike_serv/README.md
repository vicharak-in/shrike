# shrike_serv

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

---

## Overview

This example runs Olof Kindgren's [SERV](https://github.com/olofk/serv)
**bit-serial RV32I** soft CPU on the SLG47910 ForgeFPGA of a Shrike-lite board,
and makes it **runtime-programmable**: the host MCU streams an RV32I program into
the FPGA over SPI and starts the CPU — **no re-synthesis, no new bitstream**. Flash
the bitstream once, then load and run any number of programs.

The example demonstrates two results: that a *bit-serial, full RV32I CPU* fits
inside a 1K-LUT-class ForgeFPGA, and that its unified instruction+data memory
lives in on-die BRAM that can be rewritten at runtime over SPI.

The firmware ships an **RV32I conformance suite**: several themed, self-checking
programs (`TESTS` in `shrike_serv.py`) that together cover a large subset of the
RV32I base ISA. Each program writes its verdict to a memory-mapped GPIO latch
driving two FPGA pins hardwired to RP2040 GPIO14/15; the MCU reads those two bits
and prints PASS/FAIL over USB. You pick which program runs by uncommenting one
`ACTIVE = ...` line.

**A passing program latches exactly 3** (both bits high). `1` means it ran but a
tested instruction computed the wrong value; `0` means the CPU never reached its
store (trap / illegal / hang — the latch clears on every reload).

## Expected Output

```
Flashing SERV Core bitstream to FPGA...
[shrike_flash] FPGA programming done.
regalu: testing add sub sll srl sra and or xor slt sltu
result = 3 -> PASS  (verified: add sub sll srl sra and or xor slt sltu)
```

---

## Compatibility

| Board | MCU | Status |
|---|---|---|
| Shrike-lite | RP2040 | Tested and working |
| Shrike | RP2350 | Untested |
| Shrike-fi | ESP32-S3 | Untested |

> The FPGA bitstream is the same across all boards; only the MCU firmware pin
> map differs.

---

## Hardware Setup

No external hardware required. SPI and the two result pins are already wired
between the FPGA and the RP2040 on the Shrike-lite PCB:

| FPGA pin | Signal | RP2040 pin | Direction |
|---|---|---|---|
| GPIO3  | `spi_sck`     | GPIO2  | MCU → FPGA |
| GPIO4  | `spi_ss_n`    | GPIO1  | MCU → FPGA |
| GPIO5  | `spi_mosi`    | GPIO3  | MCU → FPGA |
| GPIO17 | `result_bit0` | GPIO15 | FPGA → MCU |
| GPIO18 | `result_bit1` | GPIO14 | FPGA → MCU |

The FPGA never drives MISO — the result comes back on the two GPIO result pins as
plain logic levels. No MISO pin is needed; the CPU is reset/run entirely via SPI
commands.

---

## System Architecture

```
MCU --SPI--> spi_target --> bootloader FSM --writes--> BRAM0..3 (unified IMEM+DMEM)
servile (SERV CPU) --Wishbone--> BRAM0..3              (instruction + data fetch)
servile (SERV CPU) --Wishbone--> servant_mux --> servant_gpio  (GPIO latch)
                                             --> servant_timer (timer/IRQ)
serv_rf_ram (LUT RAM) <--> servile                     (register file, 576x2-bit)
gpio_latch ----------> GPIO17 / GPIO18 -> RP2040 GPIO15 / GPIO14
```

- **Bootloader / SPI** (`spi_target.v` + FSM in `shrike_top.v`): receives bytes
  (Mode 0, MSB-first, 8-bit) and either dispatches a command or streams a program
  byte into the unified RAM. The CPU is held in reset during loading and released
  to run on command.
- **Unified RAM** (`servant_ram.v`): 128 words across BRAM0-3, one byte lane per
  slice. Written by the SPI loader, read/written by the CPU over Wishbone.
- **Register file** (`serv_rf_ram.v`): 576×2-bit, inferred as LUT RAM by GoHub
  — too irregular for explicit BRAM.
- **GPIO result latch**: a store to any `0x4xxxxxxx` address latches the low 2
  bits of the stored word onto `result_bit0/1`. It clears whenever the CPU is
  (re)loaded, so a stale result is never read back.

### SPI load protocol

| Byte | Meaning |
|---|---|
| `0xA3` | Halt: hold the CPU in reset (re-arm before a new `0xA0`) |
| `0xA0` | Enter load: halt CPU, reset the write pointer |
| 512 bytes | Program image — 128 words × 4 bytes, **little-endian** |
| `0xA2` | Run: release the CPU |

Each byte is sent as its own chip-select frame.

---

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike-lite board via USB.
2. Copy `bitstream/shrike_serv.bin` to the board filesystem (e.g. via the
   Thonny file panel).
3. Run `firmware/micropython/shrike_serv.py`.
4. Observe `result = 3 -> PASS` over USB serial.

---

## Running & Editing Programs

### File locations

| File | Location | Purpose |
|---|---|---|
| `shrike_serv.bin` | board filesystem | The bitstream. `shrike.flash()` opens it by filename on the board, so it must be copied to the board once. It does not change when programs are edited. |
| `shrike_serv.py` | your computer | The programs and driver. Edit this file here; it is the source of truth. |

### Which copy of `shrike_serv.py` runs

| Command | Copy executed |
|---|---|
| `mpremote ... run shrike_serv.py` | The file on your computer. mpremote streams it to the board's RAM and runs it; the board's stored copy is not used. |
| `mpremote ... exec "import shrike_serv"`, or running the board's copy in Thonny, or saving it as `main.py` | The copy stored on the board. |

### Development workflow

Copy the bitstream once:

```bash
uvx mpremote connect <PORT> fs cp bitstream/shrike_serv.bin :shrike_serv.bin
```

Then edit `firmware/micropython/shrike_serv.py` on your computer and run it:

```bash
uvx mpremote connect <PORT> run firmware/micropython/shrike_serv.py
```

To switch tests, uncomment a different `ACTIVE = ...` line and re-run. No
bitstream copy needed.

`<PORT>` is `/dev/cu.usbmodem*` on macOS/Linux or `COMx` on Windows;
`uvx mpremote connect list` reports it.

### Standalone operation

To run without a host attached, copy the file to the board as `main.py`:

```bash
uvx mpremote connect <PORT> fs cp firmware/micropython/shrike_serv.py :main.py
```

The bitstream is volatile and must be re-flashed after every power cycle;
`main.py` does this on boot via `flash_bitstream()`.

---

## The RV32I Conformance Suite

`firmware/micropython/shrike_serv.py` holds several themed, self-checking
programs in a `TESTS` dictionary:

| Program (`ACTIVE`) | Instructions tested |
|---|---|
| `regalu`  | add sub sll srl sra and or xor slt sltu |
| `immalu`  | addi slli srli srai andi ori xori slti sltiu lui auipc |
| `branch`  | beq bne blt bge bltu bgeu (each checked **both** taken and not-taken) |
| `loads`   | lw lh lhu lb lbu (with sign/zero-extension) |

The arithmetic programs **sum every operation's result and compare the 32-bit
total** to a precomputed checksum, so a wrong answer in any one instruction shifts
the sum and fails. The branch program uses **poison instructions**: a missed or
wrong transfer lands on a fail marker rather than passing silently.

---

## How to Change the Computation

Add your own entry to the `TESTS` dictionary in `firmware/micropython/shrike_serv.py`
(a name → `(description, [words])` pair), point `ACTIVE` at it, and re-run.
**No re-synthesis or new bitstream is needed.** A trivial program that drives
result = 1:

```python
"demo": ("addi sw", [
    0x00100513,   # addi x10, x0, 1   -> x10 = 1
    0x400004B7,   # lui  x9, 0x40000  (GPIO base)
    0x00A4A023,   # sw   x10, 0(x9)   -> latch bits = 1
    0x0000006F,   # jal  x0, 0        (halt)
]),
```

For larger programs, write RV32I assembly, assemble it with a `riscv*-elf`
toolchain (`-march=rv32i -mabi=ilp32`), and paste the resulting word encodings
in. The firmware pads the rest of the memory with `NOP`.

### Result output width

The design exposes 2 result bits (`result_bit0`, `result_bit1`), so the readable
range is 0-3. For wider results, add more `result_bit*` pins to `shrike_top.v`,
widen the GPIO latch, and update the firmware to read the extra RP2040 GPIOs.

---

## Build From Source

### Step 1 — Open in Go Configure

Launch Go Configure Software Hub, **New Project**, target chip **SLG47910 (BB)**
— or open the included `shrike_serv.ffpga` directly to skip manual setup.

If rebuilding from scratch, add the Verilog files:

```
ffpga/src/shrike_top.v
ffpga/src/spi_target.v
ffpga/src/servant_ram.v
ffpga/src/serv_rf_ram.v
ffpga/src/servant_gpio.v
ffpga/src/servant_timer.v
ffpga/src/servant_mux.v
ffpga/src/servile_arbiter.v
ffpga/src/servile_mux.v
ffpga/src/servile_rf_mem_if.v
ffpga/src/serv_rf_if.v
ffpga/src/serv_rf_ram_if.v
ffpga/src/serv_bufreg.v
ffpga/src/serv_bufreg2.v
ffpga/src/serv_alu.v
ffpga/src/serv_csr.v
ffpga/src/serv_ctrl.v
ffpga/src/serv_decode.v
ffpga/src/serv_immdec.v
ffpga/src/serv_mem_if.v
ffpga/src/serv_state.v
ffpga/src/serv_compdec.v
ffpga/src/serv_aligner.v
ffpga/src/serv_debug.v
ffpga/src/serv_top.v
ffpga/src/servile.v
```

### Step 2 — Enable BRAM

Enable the **North BRAM bank** (BRAM0-3) in the project's BRAM configuration.
The register file is inferred as LUT RAM by GoHub and does not require a BRAM
bank.

### Step 3 — IO Planner

Assign:

| Signal | Resource |
|---|---|
| `clk`      | `OSC_CLK` |
| `clk_en`   | `OSC_EN`  |
| `spi_sck`  | `GPIO3`   |
| `spi_ss_n` | `GPIO4`   |
| `spi_mosi` | `GPIO5`   |

Assign BRAM ports in IO planner

### Step 4 — Synthesize and generate bitstream

Click **Synthesize** then **Generate Bitstream**. Copy the produced
`FPGA_bitstream_MCU.bin` to `bitstream/shrike_serv.bin`.

---

## References

- [SERV](https://github.com/olofk/serv) by Olof Kindgren (Apache-2.0)
- [SLG47910 Datasheet](https://www.renesas.com/en/products/slg47910)
- [Shrike documentation](https://vicharak-in.github.io/shrike/)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)

---

## Licence

SERV retains its original Apache-2.0 licence (headers preserved in the upstream
source files). All Shrike-specific additions (`shrike_top.v`, `servant_ram.v`,
`spi_target.v`, firmware, docs) are GPL-2.0 to match the rest of this repo.
