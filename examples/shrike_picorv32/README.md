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
bitstream once, then load and run as many programs as you like.

The point of the example is twofold: that a *general-purpose, full 32-register
RV32I CPU* fits inside a 1K-LUT-class ForgeFPGA at all, and that its program
memory lives in on-die BRAM you can rewrite at runtime over SPI.

The bundled program is an **instruction-variety self-test**. A single
accumulator (`x10`) is threaded through 27 distinct RV32I opcodes; the final
value is written to a memory-mapped GPIO latch driving two FPGA pins hardwired
to RP2040 GPIO14/15. The MCU reads those two bits and prints PASS/FAIL over USB.

**A correct RV32I core leaves the result at exactly 3** (both bits high). Any
other value means an instruction misbehaved.

Three things make this fit *and* stay programmable:

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
Loading 32-word program over SPI...
PicoRV32 result = 3 -> PASS (RV32I instruction-variety self-test)
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
4. Observe `... result = 3 -> PASS` over USB serial.

To run a different program, edit the `PROGRAM` list in the firmware and re-run —
the same bitstream executes whatever you load.

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

## The Bundled Self-Test Program

The `PROGRAM` in the firmware runs 27 distinct RV32I opcodes in 32 words:

```
addi add sub  and or xor  andi ori xori  sll srl sra  slli srli srai
slt sltu slti  lui  beq bne blt bge bltu bgeu  jal  sw
```

It first threads `x10` through the arithmetic / logic / shift / set-less-than
ops (in both register and immediate forms), then exercises **every branch type
as a "must-not-take" gate**: if any branch wrongly fires, control jumps to the
halt loop and *skips* the result store, leaving the GPIO result at 0 (fail).
The final `jal` must jump over a poison instruction. If everything executed
correctly, `x10 == 3`, it is stored to `0x40000000`, and both result bits read
high.

This is what makes the example a discriminating test rather than a demo: a core
with the read-latency, branch, or register bugs that a naive port exhibits will
*not* land on 3.

---

## How to Change the Computation

Edit the `PROGRAM` list in `firmware/micropython/shrike_picorv32.py` — a list of
32-bit RV32I instruction words (up to 32) — and re-run the script. **No
re-synthesis or new bitstream is needed.** For a trivial example that drives
result = 1:

```python
PROGRAM = [
    0x00100513,   # addi x10, x0, 1   -> x10 = 1
    0x400004B7,   # lui  x9, 0x40000  (GPIO base)
    0x00A4A023,   # sw   x10, 0(x9)   -> latch bit0 = 1
    0x0000006F,   # jal  x0, 0        (halt)
]
```

The easiest workflow is to write RV32I assembly, assemble it with a `riscv*-elf`
toolchain (`-march=rv32i -mabi=ilp32`), and paste the resulting word encodings
into `PROGRAM`. The firmware pads the rest of the 32-word memory with `NOP`.

### Program-size limit (important)

The program counter is narrowed to **7 bits** (`localparam PC_W = 7` in
`picorv32.v`) — an area optimisation that caps the program at **128 bytes = 32
instruction words**, exactly the depth of the BRAM instruction RAM as wired.
Programs longer than 32 words will wrap; keep yours within the budget. (Widening
means bumping `PC_W` and widening the shared adder — a fabric/area trade-off.)

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
