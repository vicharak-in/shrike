# shrike_picorv32

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

## Overview

This example runs Claire Wolf's [PicoRV32](https://github.com/YosysHQ/picorv32)
**RV32I** CPU on the SLG47910 ForgeFPGA of a Shrike-lite board, and makes it
**runtime-programmable**: the host MCU streams a program into the FPGA over SPI
and starts the CPU — no re-synthesis, no new bitstream. Flash the bitstream once,
then load and run any number of programs.

The full 32-register RV32I core fits the 1K-LUT-class fabric with both its
register file and a 32-word instruction memory in on-die BRAM, rewritten at
runtime over SPI. It ships a conformance suite — themed, self-checking programs
that together cover the complete RV32I base ISA — each reporting PASS/FAIL on two
GPIO pins the MCU reads back.

## Expected Output

```
Flashing PicoRV32 bitstream to FPGA...
[shrike_flash] FPGA programming done.
regalu: testing add sub sll srl sra and or xor slt sltu
result = 3 -> PASS  (verified: add sub sll srl sra and or xor slt sltu)
```

## Compatibility

| Board | MCU | Status |
|---|---|---|
| Shrike-lite | RP2040 | Tested and working |
| Shrike | RP2350 | Untested |
| Shrike-fi | ESP32-S3 | Untested |

> The FPGA bitstream is the same across all boards; only the MCU firmware pin
> map differs.

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

The FPGA never drives MISO — results come back on the two GPIO result pins — so
the CPU is reset and run entirely via SPI commands.

## How It Works

```
MCU --SPI--> spi_target --> bootloader --> instruction RAM (BRAM4..7, 32 words)
picorv32 <--mem bus--> instruction RAM      (fetch, 1-cycle wait)
picorv32 <--mem bus--> register file (BRAM0..3, 32 regs)
picorv32 --store 0x4xxxxxxx--> result latch --> GPIO17/18 --> RP2040
```

The MCU streams a program into the 32-word instruction RAM over SPI while the CPU
is held in reset, then releases it to run. Both the register file (BRAM0-3) and
the instruction RAM (BRAM4-7) live in on-die BRAM instead of fabric flip-flops,
which is what lets the full 32-register core fit. A store to any `0x4xxxxxxx`
address latches the low 2 bits onto the result pins (it clears on every reload).
Because the SLG47910 BRAM read is synchronous, the core carries a 1-cycle
read-latency fix (`CF1`) so register and instruction reads return valid data.

Sources: `picorv32.v` (core + `SHRIKE PATCH` size optimisations),
`shrike_picorv32_top.v` (top + SPI bootloader + result latch),
`picorv32_imem_bram.v` (instruction RAM), `picorv32_regs_bram.v` (register file).

## Quick Start (Pre-Built Bitstream)

Copy the bitstream to the board's filesystem and run the driver — with Thonny or
`mpremote`, whichever you prefer (the driver flashes the bitstream into the FPGA
itself at runtime, so the `.bin` just needs to be on the board).

**Thonny (GUI):** use the file panel to copy `bitstream/shrike_picorv32.bin` to
the board, then open `firmware/micropython/shrike_picorv32.py` and Run it.

**mpremote (CLI):** `pip install mpremote` (auto-detects the board):
```bash
mpremote fs cp bitstream/shrike_picorv32.bin :shrike_picorv32.bin
mpremote run firmware/micropython/shrike_picorv32.py
```

Either way, observe `result = 3 -> PASS` over USB serial. To run another part of
the suite, uncomment a different `ACTIVE = ...` line and re-run.

## Running & Editing Programs

Edit `shrike_picorv32.py` and re-run it (in Thonny, or `mpremote run` — which
executes your local copy, so no re-copy needed). Uncomment a different
`ACTIVE = ...` line to switch tests, or add your own program to `TESTS` (below).
To run standalone at boot (no host attached), save the file on the board as
`main.py`.

## Build From Source

### Step 1 — Open in Go Configure

Launch Go Configure Software Hub and open the included `shrike_picorv32.ffpga`
(target chip **SLG47910 (BB)**). It lists every source in order and holds the
complete pinout. From scratch, add the sources with the top module last:
`picorv32_regs_bram.v`, `picorv32.v`, `picorv32_imem_bram.v`, `spi_target.v`,
`shrike_picorv32_top.v`.

### Step 2 — Enable BRAM

The register file uses BRAM0-3 and the instruction RAM uses BRAM4-7, so enable
**both** BRAM banks (North = BRAM0-3, South = BRAM4-7). The BRAM ports and bank
clock feeds must also be pinned — the committed `.ffpga` holds all of these.

### Step 3 — Clock + generate

The fabric runs from the PLL at 25 MHz (the `pll_*` pins program it from fabric
logic, per Renesas AN-003; dividers give `50 MHz × 21 / (1×7×6) = 25 MHz`). Click
**Synthesize** then **Generate Bitstream**, and copy the produced
`FPGA_bitstream_MCU.bin` to `bitstream/shrike_picorv32.bin`.

## The RV32I Conformance Suite

`firmware/micropython/shrike_picorv32.py` holds several themed, self-checking
≤32-word programs in a `TESTS` dictionary. Together they cover the complete RV32I
base ISA — all 37 instructions:

| Program (`ACTIVE`) | Instructions tested |
|---|---|
| `regalu` | add sub sll srl sra and or xor slt sltu |
| `immalu` | addi slli srli srai andi ori xori slti sltiu lui auipc |
| `branch` | beq bne blt bge bltu bgeu (taken **and** not-taken) |
| `jumps`  | jal jalr (transfer **and** link register) |
| `loads`  | lw lh lhu lb lbu (sign/zero-extension) |
| `store_sw` / `store_sh` / `store_sb` | sw / sh / sb |

Pick one with an `ACTIVE = ...` line and run. A pass latches **3** (both bits);
`1` = ran but wrong value, `0` = never reached the store (trap/hang). Each program
was validated so injecting a fault into any instruction it tests makes it stop
returning 3, so a pass confirms those instructions are correct.

To run your own program, add a `name: (description, [words])` entry to `TESTS`,
point `ACTIVE` at it, and re-run — no re-synthesis. Programs are capped at **32
words** (`PC_W = 7` in `picorv32.v`, an area optimisation matching the instruction
RAM depth). The 2 result bits give a readable range of 0-3.

## PicoRV32 Configuration

Locked parameters in `shrike_picorv32_top.v` for a minimal full-RV32I build:

| Parameter | Value | Reason |
|---|---|---|
| `ENABLE_REGS_16_31`    | 1 | full RV32I — all 32 registers |
| `ENABLE_REGS_DUALPORT` | 0 | single read port — matches the BRAM regfile |
| `BARREL_SHIFTER`       | 0 | serial shift — avoids a 32-bit mux tree |
| `COMPRESSED_ISA`       | 0 | no RVC decoder |
| `CATCH_MISALIGN` / `CATCH_ILLINSN` | 0 | no trap logic |
| `ENABLE_MUL` / `DIV` / `IRQ` / `COUNTERS` | 0 | no M-ext / IRQ / CSR counters |

The core in `picorv32.v` also carries the `SHRIKE PATCH` size optimisations (BRAM
register file, shared-adder datapath, 7-bit PC, narrowed memory interface) plus
two correctness fixes (`CF1` read-latency wait-state, `CF2` ECALL/EBREAK halt);
`grep "SHRIKE PATCH"` / `grep "CORRECTNESS FIX"` finds every site.

## Licence

PicoRV32 retains its original ISC licence (header preserved in `picorv32.v`). All
Shrike-specific additions (the `SHRIKE PATCH` optimisations, BRAM register file,
instruction RAM, SPI bootloader, top wrapper, firmware, docs) are GPL-2.0 to match
the rest of this repo.
