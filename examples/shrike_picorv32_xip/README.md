# shrike_picorv32_xip

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

## Overview

A [PicoRV32](https://github.com/YosysHQ/picorv32) **RV32I** CPU on the SLG47910
ForgeFPGA that **executes in place from 64 KB of RAM** — enough to run real
compiled C programs, not just short instruction sequences. The FPGA is the SPI
*master* and fetches every instruction over SPI from a RAM emulated by the
board's own RP2040, so the program is never copied into the FPGA; it runs from
where it lives (**XIP** = eXecute In Place).

This is the large-program companion to the [`shrike_picorv32`](../shrike_picorv32)
example. That one loads ≤32-instruction programs into on-chip BRAM; this one
removes that ceiling — write a C program, run one command, watch it execute on
the FPGA.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/rp2040/` | ✅ Tested |
| Shrike (RP2350) | `firmware/rp2040/` | ⬜ Untested |
| Shrike-fi (ESP32-S3) | — | ⬜ Not supported |

> The FPGA bitstream is the same across boards. The host firmware is **not**
> MicroPython: the RAM emulator is PIO + chained DMA + a dedicated core, so it
> ships as a pico-sdk C program (with a pre-built `.uf2`). ESP32-S3 has no
> equivalent PIO and is not supported.

## Hardware Setup

No external hardware required. The FPGA↔RP2040 SPI bus is already wired on the
board. Note the roles are reversed from most examples: here the **FPGA drives
SCK/CS/MOSI** (it is the master) and the RP2040 answers on MISO with RAM data.

## Quick Start (Pre-Built Bitstream)

The RP2040 both hosts the RAM and configures the FPGA, so setup is a one-time
firmware flash — the FPGA bitstream is embedded in it.

> **This replaces MicroPython** on the RP2040 (unlike other examples, which run
> *on* MicroPython). The board's flash is a single UF2 slot, so this firmware
> takes it over while the example runs. Restoring MicroPython is a normal
> reflash — see below.

1. Put the board in BOOTSEL (hold BOOTSEL, tap RESET) so `RPI-RP2` appears.
2. Copy `firmware/rp2040/shrike_xip.uf2` onto it. The board reboots and
   configures the FPGA automatically.
3. Run a program:
   ```bash
   cd programs
   ./run.py demo.c
   ```
   `run.py` compiles the C, loads it into the emulated RAM, releases the CPU,
   and prints the program's output. See [`programs/README.md`](programs/README.md).

Expected result: the demo prints its self-checks and ends with `ALL OK`.

### Restoring MicroPython

To go back to the stock environment (to run the MicroPython examples again),
put the board in BOOTSEL and copy the standard Shrike MicroPython UF2 onto it —
download the one for your board from the Shrike
[Releases](https://github.com/vicharak-in/shrike/releases/) (also kept in this
repo under `archive/firmware/`). That's the whole process; it overwrites this
firmware and MicroPython is back at the next boot.

## Build From Source

### FPGA (Verilog)
1. Open `shrike_picorv32_xip.ffpga` in Go Configure Software Hub.
2. Synthesize → Generate Bitstream.
3. Copy the produced `FPGA_bitstream_MCU.bin` to
   `bitstream/shrike_picorv32_xip.bin`.

The project runs the fabric from the PLL at 25 MHz (the `pll_*` pins program it
from fabric logic, per Renesas AN-003), and pins all BRAM ports and result
signals — the committed `.ffpga` holds the complete, correct pinout.

### Firmware (pico-sdk C)
Only needed if you change the host code; the pre-built `shrike_xip.uf2` is
committed. With [pico-sdk](https://github.com/raspberrypi/pico-sdk) installed:
```bash
cd firmware/rp2040
mkdir build && cd build
cmake .. && cmake --build .
```
`shrike_xip.uf2` is produced; drag it onto the board in BOOTSEL. CMake embeds
`bitstream/shrike_picorv32_xip.bin` into the firmware automatically.

## How It Works

```
RP2040 (SPI-RAM emulator, 64 KB)  <--SPI-->  FPGA
   PIO + DMA answer read/write frames         spi_xip_master  (SPI master)
                                                    |  picorv32 mem bus
                                              picorv32  (RV32I, PC_W=16)
                                              register file in BRAM0-3
```

- **`spi_xip_master.v`** bridges PicoRV32's memory bus to a SPI master. Every
  instruction fetch and data access becomes a SPI transaction to the external
  RAM (mode 0, command `0x03` read / `0x02` write, 16-bit address). The CPU
  runs slower than from local memory but is limited only by the 64 KB space.
- **`picorv32.v`** is the same core as the `shrike_picorv32` example (register
  file in BRAM0-3, shared-adder datapath) with the program counter widened to
  16 bits (`PC_W = 16`) so it can address the full 64 KB.
- **The RP2040** (`firmware/rp2040/`) plays two roles: at boot it configures the
  FPGA from the embedded bitstream, then it emulates the 64 KB SPI RAM
  (`sram.c` / `sram.pio`, vendored from
  [MichaelBell/spi-ram-emu](https://github.com/MichaelBell/spi-ram-emu)) and
  relays the program's console output to USB. A program signals completion by
  storing to a status word; the CPU's console is bytes stored to `0xF000`.

There is no address decode in the FPGA — the SPI master *is* the bus, and
`mem_addr[15:0]` maps straight to the 64 KB RAM.

## Expected Output

```
XIP compiled-C demo
fib(18)      = 2584
primes<512   = 97
sorted       = yes
checksum     = 167433
chk/7, chk%7 = 23919, 0
ALL OK
```

The demo (`programs/demo.c`) exercises recursion (a real call stack), arrays and
structs in RAM, insertion sort, and software multiply/divide — GCC-compiled code,
not hand-written vectors — in ~2 KB of the 64 KB space.

## References

- [PicoRV32](https://github.com/YosysHQ/picorv32) by Claire Wolf (ISC licence)
- [spi-ram-emu](https://github.com/MichaelBell/spi-ram-emu) by Michael Bell (BSD-3) — the RP2040 RAM emulator
- [SLG47910 Datasheet](https://www.renesas.com/en/products/slg47910)
- [Shrike documentation](https://vicharak-in.github.io/shrike/)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)

---

## Licence

PicoRV32 retains its original ISC licence and the RAM emulator (`sram.c` /
`sram.pio`) its BSD-3 licence (headers preserved in each file). All
Shrike-specific additions (the `SHRIKE PATCH` optimisations, the SPI XIP master,
top wrapper, host firmware, and docs) are GPL-2.0 to match the rest of this repo.

