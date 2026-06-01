# shrike_picorv32

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

---

## Overview

This example runs Claire Wolf's [PicoRV32](https://github.com/YosysHQ/picorv32)
**RV32I** soft CPU on the SLG47910 ForgeFPGA of a Shrike-lite board, and makes it
**runtime-programmable**: the host MCU streams an RV32I program into the FPGA
over SPI and starts the CPU — **no re-synthesis, no new bitstream**. Flash the
bitstream once, then load and run any number of programs.

The example demonstrates two results: that a *general-purpose, full 32-register
RV32I CPU* fits inside a 1K-LUT-class ForgeFPGA, and that its program memory
lives in on-die BRAM that can be rewritten at runtime over SPI.

The firmware ships an **RV32I conformance suite**: several themed, self-checking
≤32-word programs (`TESTS` in `shrike_picorv32.py`) that *together cover the
complete RV32I base ISA — all 37 instructions*. Each program writes its verdict
to a memory-mapped GPIO latch driving two FPGA pins hardwired to RP2040
GPIO14/15; the MCU reads those two bits and prints PASS/FAIL over USB. You pick
which program runs by uncommenting one `ACTIVE = ...` line.

**A passing program latches exactly 3** (both bits high). `1` means it ran but a
tested instruction computed the wrong value; `0` means the CPU never reached its
store (trap / illegal / hang — the latch clears on every reload). Each program
was validated so that injecting a fault into any instruction it tests makes it
stop returning 3; a passing result therefore confirms those instructions are
correct.

Three design choices make the core fit and stay programmable:

1. **Register file in BRAM.** All 32 registers live in **4** BRAM slices
   (`picorv32_regs_bram.v`) instead of ~1024 fabric flip-flops, 5-bit addressed.
2. **Instruction RAM in BRAM.** The other 4 BRAM slices form a 32-word writable
   instruction memory (`picorv32_imem_bram.v`), filled over SPI by the bootloader
   so the program can be changed at runtime.
3. **A correctness fix (`CF1`).** The SLG47910 BRAM read is *synchronous* (data
   valid one cycle after the address), but PicoRV32's register-file interface
   assumes a combinational read. `CF1` adds a read-latency wait-state
   (`RS_READ_LATENCY = 2`) so register reads return valid data. The instruction
   fetch path takes the matching 1-cycle wait-state in the top module.

## Expected Output

```
Flashing PicoRV32 bitstream to FPGA...
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

(These are the same SPI pins as the `stack_processor` example. The FPGA never
drives MISO — the result comes back on the two GPIO result pins — so no reset or
MISO pin is needed; the CPU is reset/run entirely via SPI commands.)

---

## System Architecture

```
MCU --SPI--> spi_target --> bootloader FSM --writes--> imem (BRAM4..7)
picorv32 --mem bus--> imem (BRAM4..7)        (instruction fetch, 1-cycle wait)
picorv32 --mem bus--> GPIO decode            (store to 0x40000000 -> latch)
picorv32 <--BRAM0..3--> register file         (32 regs, 5-bit addressed)
gpio_latch ----------> GPIO17 / GPIO18 -> RP2040 GPIO15 / GPIO14
```

- **Bootloader / SPI** (`spi_target.v` + the FSM in `shrike_picorv32_top.v`):
  receives bytes (Mode 0, MSB-first, 8-bit) and either dispatches a command or
  streams a program byte into the instruction RAM. The CPU is held in reset
  during loading and released to run on command.
- **Instruction RAM** (`picorv32_imem_bram.v`): 32 words across BRAM4-7, one
  byte lane per slice. Written by the loader, read by the CPU (synchronous,
  1-cycle latency — the top inserts a fetch wait-state).
- **Register file** (`picorv32_regs_bram.v`): all 32 registers in BRAM0-3, one
  byte lane per slice, 5-bit addressed.
- **GPIO result latch**: a store to any `0x4xxxxxxx` address latches the low 2
  bits of the stored word onto `result_bit0/1`. It clears whenever the CPU is
  (re)loaded, so a stale result is never read back.

### SPI load protocol

| Byte | Meaning |
|---|---|
| `0xA0` | Enter load: halt CPU, reset the write pointer |
| 128 bytes | Program image — 32 words × 4 bytes, **little-endian** |
| `0xA2` | Run: release the CPU |
| `0xA3` | Halt: hold the CPU in reset (re-arm before a new `0xA0`) |

Each byte is sent as its own chip-select frame.

---

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike-lite board via USB.
2. Copy `bitstream/shrike_picorv32.bin` to the board filesystem (e.g. via the
   Thonny file panel).
3. Run `firmware/micropython/shrike_picorv32.py`.
4. Observe `result = 3 -> PASS` over USB serial.

To run a different part of the suite, uncomment a different `ACTIVE = ...` line
near the top of the firmware and re-run — the same bitstream executes whatever
you load. To run your own program, add it to `TESTS` (see below).

---

## Running & Editing Programs

### File locations

| File | Location | Purpose |
|---|---|---|
| `shrike_picorv32.bin` | board filesystem | The bitstream. `shrike.flash()` opens it by filename on the board, so it must be copied to the board once. It does not change when programs are edited. |
| `shrike_picorv32.py` | your computer | The programs and driver. Edit this file here; it is the source of truth. |

At run time the CPU fetches instructions from on-die BRAM, streamed in over SPI.
The host computer only flashes the bitstream and loads the selected program.

### Which copy of `shrike_picorv32.py` runs

| Command | Copy executed |
|---|---|
| `mpremote ... run shrike_picorv32.py` | The file on your computer. mpremote streams it to the board's RAM and runs it; the board's stored copy is not used. |
| `mpremote ... exec "import shrike_picorv32"`, or running the board's copy in Thonny, or saving it as `main.py` | The copy stored on the board. |

### Development workflow

Copy the bitstream once:

```bash
uvx mpremote connect <PORT> fs cp bitstream/shrike_picorv32.bin :shrike_picorv32.bin
```

Then edit `firmware/micropython/shrike_picorv32.py` on your computer and run it:

```bash
uvx mpremote connect <PORT> run firmware/micropython/shrike_picorv32.py
```

Because `run` executes the local file, no copy step is needed when editing
programs. To change what runs, edit the file and re-run:

- to switch tests, uncomment a different `ACTIVE = ...` line;
- to run your own program, add an entry to `TESTS` and set `ACTIVE` to it (see
  *How to Change the Computation*).

`<PORT>` is `/dev/cu.usbmodem*` on macOS/Linux or `COMx` on Windows;
`uvx mpremote connect list` reports it. The name may change between connections.

### Standalone operation

To run without a host attached, copy the file to the board as `main.py`;
MicroPython executes `main.py` at boot:

```bash
uvx mpremote connect <PORT> fs cp firmware/micropython/shrike_picorv32.py :main.py
```

The board's stored copy is then what runs, so re-copy it after each edit. The
bitstream is volatile and must be re-flashed after every power cycle; `main.py`
does this on boot via `flash_bitstream()`.

---

## Build From Source

### Step 1 — Open in Go Configure

Launch Go Configure Software Hub, **New Project**, target chip **SLG47910 (BB)**
— or open the included `shrike_picorv32.ffpga` directly to skip manual setup.

If rebuilding from scratch, add the Verilog files (top module last):
```
ffpga/src/picorv32_regs_bram.v
ffpga/src/picorv32.v
ffpga/src/picorv32_imem_bram.v
ffpga/src/spi_target.v
ffpga/src/shrike_picorv32_top.v
```

### Step 2 — Enable BRAM

The register file uses BRAM0-3 and the instruction RAM uses BRAM4-7, so enable
**both** BRAM banks (North = BRAM0-3, South = BRAM4-7) in the project's BRAM
configuration.

### Step 3 — IO Planner

Assign:

| Signal | Resource |
|---|---|
| `clk`      | `OSC_CLK` |
| `clk_en`   | `OSC_EN`  |
| `spi_sck`  | `GPIO3`   |
| `spi_ss_n` | `GPIO4`   |
| `spi_mosi` | `GPIO5`   |

Leave `result_bit0/1`, `result_bit0/1_en`, and all `BRAMx_*` ports
**unassigned**. Yosys auto-routes the result bits to FPGA GPIO17/18 (the only
pins hardwired to RP2040 GPIO14/15 via PCB 0-ohm resistors) and the `BRAMx_*`
ports to the on-die BRAM. Manually assigning those conflicts with the
auto-routing and silently breaks the connection.

### Step 4 — Synthesize and generate bitstream

Click **Synthesize** then **Generate Bitstream**. Copy the produced
`FPGA_bitstream_MCU.bin` to `bitstream/shrike_picorv32.bin`.

---

## The RV32I Conformance Suite

`firmware/micropython/shrike_picorv32.py` holds several themed, self-checking
≤32-word programs in a `TESTS` dictionary. **Together they cover the complete
RV32I base ISA — all 37 instructions:**

| Program (`ACTIVE`) | Instructions tested |
|---|---|
| `regalu`   | add sub sll srl sra and or xor slt sltu |
| `immalu`   | addi slli srli srai andi ori xori slti sltiu lui auipc |
| `branch`   | beq bne blt bge bltu bgeu (each checked **both** taken and not-taken) |
| `jumps`    | jal jalr (control transfer **and** link register) |
| `loads`    | lw lh lhu lb lbu (with sign/zero-extension) |
| `store_sw` / `store_sh` / `store_sb` | sw / sh / sb |

Pick one by uncommenting a single `ACTIVE = ...` line and running the file. The
arithmetic programs **sum every operation's result and compare the 32-bit total**
to a precomputed checksum, so a wrong answer in any one instruction shifts the
sum and fails (no masking). The branch/jump programs use **poison instructions**:
a missed or wrong transfer lands on a fail marker rather than passing silently.

Each program was machine-validated so that injecting a fault into any instruction
it tests makes it stop returning 3, so a passing result confirms those
instructions are implemented correctly.

> **Why these encodings:** the SoC has no general data RAM (see *System
> Architecture*). Stores are observable only through the GPIO result latch, so
> each store width is tested as the sole store of a known value; loads read back
> known words planted in the instruction RAM. The result encoding (3 = PASS,
> 1 = FAIL, 0 = DEAD) fits the 2-bit latch.

---

## How to Change the Computation

Add your own entry to the `TESTS` dictionary in
`firmware/micropython/shrike_picorv32.py` (a name → `(description, [words])`
pair), point `ACTIVE` at it, and re-run. **No re-synthesis or new bitstream is
needed.** A trivial program that drives result = 1:

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
in. The firmware pads the rest of the 32-word memory with `NOP`.

### Program size limit

The program counter is narrowed to **7 bits** (`localparam PC_W = 7` in
`picorv32.v`) — an area optimisation that caps the program at **128 bytes = 32
instruction words**, exactly the depth of the BRAM instruction RAM as wired.
Programs longer than 32 words wrap and must be kept within this limit. Raising it
requires increasing `PC_W` and widening the shared adder, a fabric-area
trade-off.

### Result output width

The design exposes 2 result bits (`result_bit0`, `result_bit1`), so the readable
range is 0-3. For wider results, add more `result_bit*` pins to
`shrike_picorv32_top.v`, widen the GPIO latch, and update the firmware to read
the extra RP2040 GPIOs. See the Shrike pinout doc for available pins.

---

## PicoRV32 Configuration

Locked parameters in `shrike_picorv32_top.v`:

| Parameter | Value | Reason |
|---|---|---|
| `ENABLE_REGS_16_31`    | 1 | **Full RV32I** — all 32 registers (`x0..x31`) |
| `ENABLE_REGS_DUALPORT` | 0 | single read port — matches the BRAM regfile, saves a mux |
| `LATCHED_MEM_RDATA`    | 1 | saves an internal capture flop |
| `TWO_CYCLE_ALU`        | 0 | single-cycle ALU collapses 1-CLB carry clusters |
| `TWO_CYCLE_COMPARE`    | 0 | single-cycle compare path |
| `BARREL_SHIFTER`       | 0 | serial shift — avoids a 32-bit mux tree |
| `TWO_STAGE_SHIFT`      | 0 | further shrink |
| `COMPRESSED_ISA`       | 0 | no RVC decoder |
| `CATCH_MISALIGN`       | 0 | no trap logic |
| `CATCH_ILLINSN`        | 0 | no trap logic |
| `ENABLE_MUL`/`DIV`     | 0 | no M extension |
| `ENABLE_IRQ`           | 0 | no interrupt logic |
| `ENABLE_COUNTERS`      | 0 | no CSR counters |
| `ENABLE_PCPI`          | 0 | no coprocessor interface |
| `ENABLE_TRACE`         | 0 | no trace port |

In addition to these stock parameters, the core in `ffpga/src/picorv32.v`
carries the `SHRIKE PATCH` modifications (numbered P1–P13) — the BRAM register
file, the carry-split / shared adder datapath, and the 7-bit PC — plus two
correctness fixes (CF1 read-latency wait-state, CF2 ECALL/EBREAK halt). A
legend at the top of the file lists them; `grep "SHRIKE PATCH"` or
`grep "CORRECTNESS FIX"` in `ffpga/src/picorv32.v` finds every site. The SPI
bootloader and instruction RAM live in `shrike_picorv32_top.v` and
`picorv32_imem_bram.v`.

---

## References

- [PicoRV32](https://github.com/YosysHQ/picorv32) by Claire Wolf (ISC licence)
- [SLG47910 Datasheet](https://www.renesas.com/en/products/slg47910)
- [Shrike documentation](https://vicharak-in.github.io/shrike/)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)

---

## Licence

PicoRV32 retains its original ISC licence (header preserved at the top of
`picorv32.v`). All Shrike-specific additions (the `SHRIKE PATCH` optimisations,
BRAM register file, instruction RAM, SPI bootloader, top wrapper, firmware,
docs) are GPL-2.0 to match the rest of this repo.
