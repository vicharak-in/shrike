# shrike_serv

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

---

## Overview

This example runs Olof Kindgren's [SERV](https://github.com/olofk/serv) — the
award-winning **bit-serial RV32I** soft CPU, "the world's smallest RISC-V" — on
the SLG47910 ForgeFPGA of a Shrike-lite board, and makes it
**runtime-programmable**: the host MCU streams an RV32I program into the FPGA
over SPI and starts the CPU — **no re-synthesis, no new bitstream**. Flash the
bitstream once, then load and run any number of programs.

SERV runs one bit per clock, so it is slow (~40–80 cycles per instruction) but
tiny. Its register file sits in fabric distributed RAM, which leaves all 8 BRAM
slices free for one unified **4 KB** memory — enough to run real programs, not
just hand-written snippets. The whole example — CPU, memory, and a UART monitor —
fits in **138 of the 140 CLBs**.

**One bitstream, three things to do** — the same bitstream runs whatever you load:

1. **The rv32ui conformance suite** — the official RISC-V per-instruction tests,
   run on silicon (**41/41**), proving the complete RV32I base ISA works.
   → [Quick Start](#quick-start-pre-built-bitstream)
2. **Your own compiled C** — write C, `programs/run.py` builds it and runs it on
   the CPU. → [Writing Your Own Programs (C)](#writing-your-own-programs-c)
3. **An interactive `serv>` monitor** — a shell you drive from your terminal over
   the board's UART: `fib`, `primes`, `calc`, `peek`/`poke` memory, `led`, a
   guessing game, and more. → [Interactive Monitor](#interactive-monitor)

## Expected Output

```
Flashing SERV bitstream to FPGA...
[shrike_flash] FPGA programming done.
  PASS  add
  PASS  addi
  ...
  PASS  xor
  PASS  xori
-------------------------------------------
SERV rv32ui on hardware: PASS=41 FAIL=0 DEAD=0 / 41
ALL RV32UI TESTS PASSED ON HARDWARE
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

No external hardware required. Everything is already wired between the FPGA and
the RP2040 on the Shrike-lite PCB:

| FPGA pin | Signal | RP2040 pin | Direction |
|---|---|---|---|
| GPIO3  | `spi_sck`              | GPIO2  | MCU → FPGA (program load) |
| GPIO5  | `spi_mosi`             | GPIO3  | MCU → FPGA (program load) |
| GPIO4  | `spi_ss` / `uart_tx`   | GPIO1  | shared: SPI select while loading, then UART TX (FPGA → MCU) |
| GPIO6  | `uart_rx`              | GPIO0  | MCU → FPGA (UART, RP2040 UART0 TX) |
| GPIO17 | `result_bit0`          | GPIO15 | FPGA → MCU (suite / C flow) |
| GPIO18 | `result_bit1`          | GPIO14 | FPGA → MCU (suite / C flow) |
| GPIO16 | `led`                  | —      | on-board FPGA LED |

The SPI pins match the `shrike_picorv32` example. **Pin sharing (GPIO4):**
program-load needs an SPI chip-select and the interactive monitor needs a UART
TX; they never happen at once (the CPU is held in reset during load). So GPIO4 is
the SPI select while loading, then becomes the UART TX once the core runs
(`o_uart_tx_oe = cpu_run`). The RP2040 mirrors this: GPIO1 is the SPI CS during
load, then its UART0 RX during a monitor session. Both idle high, so the handover
has no bus contention. The conformance suite and C flow simply never use the
UART; the monitor never uses the result pins.

---

## How It Works

```
MCU --SPI--> bootloader --> 4 KB memory (all 8 BRAM slices)
SERV <--wb_mem--> memory            (fetch + load/store)
SERV <--wb_ext--> MMIO              (result latch, UART, LED)  -> GPIO / RP2040
SERV <--dist RAM--> register file
```

The MCU streams a program into the unified 4 KB BRAM over SPI while the CPU is held
in reset, then releases the core to run it. SERV keeps its register file in
distributed RAM, which frees all 8 BRAM slices for that one memory. A small block
of memory-mapped registers at `0x4000_0000` carries the pass/fail result latch (the
suite and C flow report through it, read back on GPIO), a UART (the monitor), and
the LED.

Sources: `shrike_serv_top.v` (top + SPI bootloader + MMIO), `serv_mem_bram.v`
(the 4 KB memory), `serv_rf_ram.v` (register file), `uart_tx.v` / `uart_rx.v`, and
the vendored SERV core (`serv_*.v`, `servile*.v`).

---

## Quick Start (Pre-Built Bitstream)

Copy the bitstream and tests to the board, then run the driver — with Thonny or
`mpremote`, whichever you prefer (the driver flashes the bitstream into the FPGA
itself, so the `.bin` just needs to be on the board).

**Thonny (GUI):** use the file panel to copy `bitstream/shrike_serv.bin`,
`firmware/micropython/shrike_serv.py`, and the `firmware/micropython/serv_tests/`
folder to the board, then open `shrike_serv.py` and Run it.

**mpremote (CLI):** `pip install mpremote` (auto-detects the board):
```bash
mpremote fs cp bitstream/shrike_serv.bin :shrike_serv.bin
mpremote fs cp -r firmware/micropython/serv_tests :
mpremote run firmware/micropython/shrike_serv.py
```

Either way, observe `SERV rv32ui on hardware: PASS=41 FAIL=0 DEAD=0 / 41`. For a
single test, `import shrike_serv` and call `run_test("serv_tests/add.bin")`
(returns `3` for PASS).

---

## Running & Editing the Suite

`shrike_serv.bin`, `shrike_serv.py`, and the `serv_tests/` folder live on the board
filesystem — copy them there once (Thonny's file panel, or `mpremote fs cp`).
Running `shrike_serv.py` flashes the bitstream and sweeps all 41 tests. For a
single test, `import shrike_serv` and call `run_test("serv_tests/add.bin")` (it
returns `3` for PASS). To run at boot with no host attached, copy `shrike_serv.py`
to the board as `main.py`.

---

## The RV32I Conformance Suite

`firmware/micropython/serv_tests/` holds 41 program images — the official
[`riscv-tests`](https://github.com/riscv-software-src/riscv-tests) `rv32ui`
suite, one test per instruction, built for RV32I (`-march=rv32i`) and linked to
this SoC's 4 KB memory map. **Together they cover the complete RV32I base ISA:**

| Group | Tests |
|---|---|
| Register-register ALU | `add` `sub` `and` `or` `xor` `sll` `srl` `sra` `slt` `sltu` |
| Register-immediate ALU | `addi` `andi` `ori` `xori` `slli` `srli` `srai` `slti` `sltiu` |
| Upper immediate | `lui` `auipc` |
| Branches | `beq` `bne` `blt` `bge` `bltu` `bgeu` |
| Jumps | `jal` `jalr` |
| Loads | `lb` `lbu` `lh` `lhu` `lw` |
| Stores | `sb` `sh` `sw` |
| Memory ordering | `ld_st` `st_ld` `fence_i` |
| Sanity | `simple` |

Each upstream test is self-checking: it computes known values, compares against
expected results, and branches to a fail path on any mismatch. This example
replaces the tests' trap-based reporting with a tiny memory-mapped convention —
`RVTEST_PASS` stores `1` to `0x40000000`, `RVTEST_FAIL` stores a non-`1` value —
so the verdict appears on the 2-bit GPIO result latch (**3 = PASS, 1 = FAIL,
0 = DEAD**) with no trap handler or data RAM needed. The test *bodies* are the
unmodified upstream vectors.

---

## Writing Your Own Programs (C)

The 4 KB memory is large enough to run compiled C, so `programs/` provides an
edit-compile-run loop on top of the same bitstream — **no re-synthesis**. Write a
normal C program with `int main(void)` (return `0` for PASS) and:

```bash
cd programs
./run.py demo.c                 # compile, load onto the board, run, report PASS/FAIL
./run.py demo.c --compile-only  # just build the .bin (no board needed)
```

`crt0.S` turns `main()`'s return value into the 2-bit result latch the board
reads back, so structure the program so a wrong answer changes the return value.
The bundled `demo.c` is a self-check covering recursion, an in-place sort, a
prime sieve, and libgcc multiply/divide. See `programs/README.md` for the full
flow, the 4 KB budget, and toolchain requirements.

---

## Interactive Monitor

A `serv>` shell on the CPU that you drive from your terminal. From this example's
directory (`examples/shrike_serv`):

```bash
python3 programs/serv_shell.py
```

Type commands, the CPU answers:

```
serv> fib 20
6765
serv> primes 100
25
serv> calc 6*7
42
serv> led on
led on
serv> guess
1..100, blank to give up
? 50
lower
? 42
correct!
```

UP/DOWN recall recent commands. Exit with `quit`, Ctrl-D, or Ctrl-C. Full command
list: **[programs/COMMANDS.md](programs/COMMANDS.md)**.

Needs Python 3 + `pyserial` (`pip install pyserial`), and a riscv gcc the first
run. To add your own command, edit `programs/monitor.c` and rerun
`programs/run.py monitor.c --shell`.

---

## Build From Source

### Step 1 — Open in Go Configure

Launch Go Configure Software Hub, **New Project**, target chip **SLG47910 (BB)**
— or open the included `shrike_serv.ffpga` directly to skip manual setup. The
project file lists every source in the correct order and holds the complete
pinout; opening it is the reliable path.

If rebuilding from scratch, add the Verilog sources with the top module **last**:
the vendored SERV core (`serv_*.v` and `servile*.v`), then this example's
`serv_mem_bram.v`, `spi_target.v`, `uart_tx.v`, `uart_rx.v`, and finally
`shrike_serv_top.v`.

### Step 2 — Enable BRAM

The unified memory uses all eight BRAM slices, so enable **both** BRAM banks
(North = BRAM0-3, South = BRAM4-7) in the project's BRAM configuration. Enabling
the banks is necessary but **not sufficient** — the BRAM ports and bank clock
feeds must also be pinned (Step 3).

### Step 3 — Pin assignment

Opening the included `shrike_serv.ffpga` gives the complete, correct pinout; this
step describes it for a from-scratch build.

The user-facing pins:

| Signal | Resource |
|---|---|
| `clk`      | `PLL_CLK` |
| `clk_en`   | `OSC_EN`  |
| `spi_sck`  | `GPIO3`   |
| `i_spi_ss` / `o_uart_tx` / `o_uart_tx_oe` (shared pad) | `GPIO4` |
| `spi_mosi` | `GPIO5`   |
| `i_uart_rx` | `GPIO6`  |
| `o_led` (+`_oe`) | `GPIO16` |
| `result_bit0` / `result_bit1` (+`_en`) | `GPIO17` / `GPIO18` |

`i_spi_ss`, `o_uart_tx`, and `o_uart_tx_oe` are three ports on the **same** GPIO4
pad (SPI select in while loading, UART TX out while running). Also pin every
`BRAMx_*` port and both bank clock feeds
(`REF_BRAM(0..3)/(4..7)_WRITE_CLK` and `_READ_CLK` → `clk`) so the block RAM is
wired and clocked, and the `pll_*` control pins (27) that program the PLL. The
committed `.ffpga` holds all of these; use it as the reference.

### Step 3b — Clock the fabric at 25 MHz

The fabric runs from the PLL at 25 MHz. The PLL is enabled and programmed from
fabric logic (`pll_en`, `pll_refdiv`, `pll_fbdiv`, `pll_postdiv1`,
`pll_postdiv2` — see `shrike_serv_top.v` and Renesas AN-003); the dividers give
`50 MHz × 21 / (1×7×6) = 25 MHz`.

### Step 4 — Synthesize and generate bitstream

Click **Synthesize** then **Generate Bitstream**. Copy the produced
`FPGA_bitstream_MCU.bin` to `bitstream/shrike_serv.bin`.

---

## SERV Configuration

SERV is instantiated through its `servile` convenience wrapper (core + bus
arbiter + address mux + register-file interface) in `shrike_serv_top.v`:

| Parameter | Value | Reason |
|---|---|---|
| `width`     | 1     | **Bit-serial** — one bit per clock, the smallest datapath |
| `with_csr`  | 1     | CSRs present (needed by the `riscv-tests` env) |
| `with_mdu`  | 0     | no M extension (no hardware multiply/divide) |
| `with_c`    | 0     | no compressed (RVC) decoder |
| `reset_pc`  | 0     | execution starts at address 0 |
| `sim`       | 0     | hardware build — no simulation-only MMIO |

The register file (`serv_rf_ram.v`) is mapped to fabric distributed RAM; the
unified BRAM memory (`serv_mem_bram.v`), the SPI bootloader, the result latch, and
the memory-mapped UART/LED/cycle-counter (`shrike_serv_top.v`) are this example's
additions. The UART is a pair of minimal fixed-8N1 cores (`uart_tx.v` /
`uart_rx.v`) kept small to fit alongside the CPU. The SERV core files are the
unmodified upstream sources with their ISC headers preserved.

---

## Licence

SERV retains its original ISC licence (`ffpga/src/serv_LICENSE`, and the headers
preserved at the top of each `serv_*.v` / `servile*.v` file). All Shrike-specific
additions (the unified BRAM memory, SPI bootloader, top wrapper, firmware, docs)
are GPL-2.0 to match the rest of this repo.
