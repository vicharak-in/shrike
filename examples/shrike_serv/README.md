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

SERV processes **one bit per clock cycle**, so it is slow (roughly 40–80 cycles
per instruction) but tiny: the whole SoC fits in **109 of the 140 CLBs** (78%),
leaving comfortable headroom on a 1K-LUT-class fabric. The bit-serial datapath is
entirely internal, so from the outside SERV looks like an ordinary word-level CPU
with a Wishbone memory bus.

Two design choices make the core both fit and stay useful:

1. **Register file in distributed RAM.** SERV's 32 registers (plus the CSRs) live
   in fabric distributed RAM (`serv_rf_ram.v`), not in block RAM. That frees
   **all eight** BRAM slices for program memory.
2. **A unified 4 KB memory.** All 8 BRAM slices form one flat 4 KB space
   (`serv_mem_bram.v`) holding code, data, and stack together. 4 KB is large
   enough to run the **actual upstream [`riscv-tests`](https://github.com/riscv-software-src/riscv-tests)
   `rv32ui` binaries** — the official per-instruction conformance suite — not
   hand-written stand-ins.

The firmware ships that suite: **41 self-checking programs, one per RV32I
instruction** (`add`, `xor`, `beq`, `lw`, …), which together cover the complete
RV32I base ISA. Each test writes its verdict to a memory-mapped GPIO latch
driving two FPGA pins hardwired to RP2040 GPIO14/15; the MCU reads those two bits
and prints PASS/FAIL over USB.

**A passing test latches exactly 3** (both bits high). `1` means it ran but a
tested instruction computed the wrong value; `0` means the CPU never reached its
store (trap / hang — the latch clears on every reload). The tests are the
standard RISC-V conformance vectors, so a full `PASS=41` is direct evidence that
the complete RV32I base ISA executes correctly on hardware.

**One bitstream, three things to do.** Because the design is runtime-programmable,
the same bitstream runs whatever program you load:

1. **The rv32ui conformance suite** — proof the full RV32I ISA runs on silicon.
2. **Your own compiled C** — write C, `programs/run.py` builds it, loads it, and
   reports the pass/fail result (see `demo.c`).
3. **An interactive `serv>` monitor** — a shell you talk to from a laptop
   terminal over the board's UART: `fib 20`, `primes 100`, `calc 6 * 7`,
   `peek`/`poke` memory, `led on`, a guessing game, and more. The bitstream adds
   a small memory-mapped UART + LED so the CPU can talk back. See
   **[COMMANDS.md](COMMANDS.md)** for every command, and the *Interactive
   Monitor* section below.

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

## System Architecture

```
MCU --SPI--> spi_target --> bootloader FSM --writes--> memory (BRAM0..7, 4 KB)
SERV --wb_mem bus--> memory (BRAM0..7)        (fetch + load/store, 1-cycle ack)
SERV --wb_ext bus--> MMIO decode {result latch, UART, LED, cycle counter}
SERV <--distributed RAM--> register file       (32 regs + CSRs, off BRAM)
result latch --> GPIO17 / GPIO18 -> RP2040 GPIO15 / GPIO14   (suite / C flow)
uart_tx/rx <---> GPIO4 / GPIO6 <---> RP2040 UART0 <--USB--> laptop   (monitor)
```

- **Bootloader / SPI** (`spi_target.v` + the FSM in `shrike_serv_top.v`):
  receives bytes (Mode 0, MSB-first, 8-bit) and either dispatches a command or
  streams a program byte into the unified memory. The CPU is held in reset during
  loading and released to run on command.
- **Unified memory** (`serv_mem_bram.v`): 1024 words across all 8 BRAM slices as
  two byte-laned banks. Written by the loader and by CPU stores; read by fetch
  and loads (synchronous, 1-cycle — `wb_mem` ack is asserted the cycle the data
  is valid).
- **Register file** (`serv_rf_ram.v`): all 32 registers plus the CSRs in fabric
  distributed RAM, off the BRAM budget entirely.
- **MMIO** (`wb_ext`, decoded on `adr[4:2]` in `shrike_serv_top.v`): a small set
  of memory-mapped registers in the `0x4000_0000` region — the result latch, the
  UART, the LED, and a cycle counter (map below). The result latch clears
  whenever the CPU is (re)loaded, so a stale result is never read back.
- **UART** (`uart_tx.v` / `uart_rx.v`, reused from the `uart_sum` example):
  115200 8N1 at the 25 MHz fabric clock, used by the interactive monitor.

### Memory-mapped I/O (`0x4000_0000` region)

| Address | Access | Meaning |
|---|---|---|
| `0x4000_0000` | write | result latch — low 2 bits → GPIO17/18 (bit1 = PASS if value==1, bit0 = done) |
| `0x4000_0010` | write / read | UART: write transmits the low byte; read returns the last received byte |
| `0x4000_0014` | read | UART status — bit0 = RX byte valid, bit1 = TX busy |
| `0x4000_0018` | write | LED — bit0 → on-board FPGA LED (GPIO16) |
| `0x4000_001C` | read | free-running 24-bit cycle counter |

The result latch and the UART sit at different addresses, so a conformance test's
pass/fail store never collides with the monitor's UART traffic.

### SPI load protocol

| Byte | Meaning |
|---|---|
| `0xA0` | Enter load: halt CPU, reset the write pointer |
| 4096 bytes | Program image — 1024 words × 4 bytes, **little-endian**, zero-padded to the fixed length |
| `0xA2` | Run: release the CPU |
| `0xA3` | Halt: hold the CPU in reset (re-arm before a new `0xA0`) |

The control bytes are sent as their own chip-select frames; the 4 KB payload is
streamed in one frame.

---

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike-lite board via USB.
2. Copy `bitstream/shrike_serv.bin`, `firmware/micropython/shrike_serv.py`, and
   the `firmware/micropython/serv_tests/` directory to the board filesystem
   (e.g. via the Thonny file panel).
3. Run `shrike_serv.py`.
4. Observe `SERV rv32ui on hardware: PASS=41 FAIL=0 DEAD=0 / 41` over USB serial.

To run a single test instead of the whole sweep, `import shrike_serv` and call
`run_test("serv_tests/add.bin")` — it returns `3` for PASS. The same bitstream
executes whatever you load; nothing is re-synthesized.

---

## Running & Editing the Suite

### File locations

| File | Location | Purpose |
|---|---|---|
| `shrike_serv.bin` | board filesystem | The bitstream. `shrike.flash()` opens it by filename on the board, so it must be copied to the board once. It does not change when programs change. |
| `shrike_serv.py` | board filesystem | The host driver: flashes the bitstream, streams each test, reads the result latch. |
| `serv_tests/*.bin` | board filesystem | The 41 conformance test images, streamed into the CPU one at a time. |

At run time the CPU fetches and executes from on-die BRAM, streamed in over SPI.
The host only flashes the bitstream and loads each program image.

### Development workflow

Copy the three items to the board once:

```bash
uvx mpremote connect <PORT> fs cp bitstream/shrike_serv.bin :shrike_serv.bin
uvx mpremote connect <PORT> fs cp firmware/micropython/shrike_serv.py :shrike_serv.py
uvx mpremote connect <PORT> fs cp -r firmware/micropython/serv_tests :
```

Then run the suite:

```bash
uvx mpremote connect <PORT> exec "import shrike_serv"
```

`<PORT>` is `/dev/cu.usbmodem*` on macOS/Linux or `COMx` on Windows;
`uvx mpremote connect list` reports it. The name may change between connections.

### Standalone operation

To run without a host attached, copy the driver to the board as `main.py`;
MicroPython executes `main.py` at boot and `flash_bitstream()` re-flashes the
(volatile) bitstream each time:

```bash
uvx mpremote connect <PORT> fs cp firmware/micropython/shrike_serv.py :main.py
```

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

The headline demo: a `serv>` shell running **on the CPU** that you drive from a
laptop terminal. The RP2040 bridges your USB serial to the FPGA's UART, so typing
in your terminal talks straight to the bit-serial core.

```bash
cd programs
./run.py monitor.c --shell        # compile the monitor, load it, open the terminal
```

or, from a board already carrying `shrike_serv.bin` + `monitor.bin`:

```bash
mpremote connect <PORT> run firmware/micropython/shrike_serv_monitor.py
```

Then type at the prompt (`Ctrl-]` exits the bridge):

```
serv> fib 20
6765
serv> calc 6 * 7
42
serv> primes 100
25
serv> led on
led on
```

The monitor understands `help`, `echo`, `fib`, `primes`, `fact`, `calc`, `add`,
`sort`, `peek`, `poke`, `dump`, `guess`, `led`, and `cycles` — see
**[COMMANDS.md](COMMANDS.md)** for what each does. It is just a C program
(`programs/monitor.c`, ~3.8 KB): add a case to its `run()` dispatcher, rerun
`./run.py monitor.c --shell`, and your command is live — no re-synthesis.

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

## References

- [SERV](https://github.com/olofk/serv) by Olof Kindgren (ISC licence)
- [riscv-tests](https://github.com/riscv-software-src/riscv-tests) — the `rv32ui` conformance suite
- [SLG47910 Datasheet](https://www.renesas.com/en/products/slg47910)
- [Shrike documentation](https://vicharak-in.github.io/shrike/)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)

---

## Licence

SERV retains its original ISC licence (`ffpga/src/serv_LICENSE`, and the headers
preserved at the top of each `serv_*.v` / `servile*.v` file). All Shrike-specific
additions (the unified BRAM memory, SPI bootloader, top wrapper, firmware, docs)
are GPL-2.0 to match the rest of this repo.
