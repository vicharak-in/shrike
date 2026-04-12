# SERV RISC-V CPU on Shrike-lite

> **Difficulty: Advanced**
> World's first documented port of a RISC-V soft CPU to the Renesas SLG47910 ForgeFPGA.

This example runs [SERV](https://github.com/olofk/serv) — the world's smallest
RISC-V CPU (RV32I, bit-serial) — directly on the SLG47910 FPGA fabric of the
Shrike-lite board. The RP2040 flashes the bitstream, waits, reads two GPIO pins,
and prints the computation result over USB serial.

```
SERV RISC-V computed: 1 + 2 = 3
```

---

## Compatibility

| Board | MCU | Status |
|---|---|---|
| Shrike-lite | RP2040 | Tested and working |
| Shrike | RP2350 | Untested — pin map differs |
| Shrike-fi | ESP32-S3 | Untested |

---

## Why this is significant

The SLG47910 uses Renesas GreenPAK macrocell primitives — a completely different
architecture from the Lattice iCE40 or Xilinx parts that SERV was designed for.
Synthesising SERV here required identifying and fixing two undocumented toolchain
failures, plus one unexpected hardware behaviour:

| # | Finding | Detail |
|---|---|---|
| 1 | BRAM init crash | `$readmemh` → RAMSRL overflow → compiler panic → fixed by Nuclear ROM |
| 2 | Silent PNR lobotomy | `$mem` → RAMSRL → silent routing fail → CPU frozen at PC=0 → fixed by `ram_style=registers` |
| 3 | IO Planner auto-routing | GPIO17/18 must NOT be manually assigned — see section below |

Full analysis: [`docs/toolchain_failures.md`](docs/toolchain_failures.md)

---

## Critical IO Planner behaviour — read before synthesising

**Do NOT manually assign `result_bit0`, `result_bit0_en`, `result_bit1`, or
`result_bit1_en` to GPIO17/GPIO18 in the Go Configure IO Planner.**

### Why this works without explicit mapping

The Shrike-lite PCB has 0-ohm resistors that hardwire FPGA GPIO17 → RP2040
GPIO15 and FPGA GPIO18 → RP2040 GPIO14 internally. These are the only two FPGA
GPIO pins with direct RP2040 connections that are not already claimed by the SPI
configuration bus (GPIO3–6) or the enable pins (EN, PWR).

When you mark signals with `(* iopad_external_pin *)` in Verilog but do not
assign them in the IO Planner, Go Configure's Yosys automatically routes them to
the next available free GPIO — which is GPIO17 and GPIO18. Because those pins
are hardwired to RP2040 GPIO14/15 on the PCB, the result reaches the RP2040
without any explicit mapping.

**When you manually assign GPIO17_OUT / GPIO17_OE in the IO Planner, the
explicit entry can conflict with or override the automatic routing, breaking the
connection and causing the CPU output to disappear.**

### Working IO Planner mapping (exact)

| Signal | Go Configure resource | Notes |
|---|---|---|
| `clk` | `OSC_CLK` | Required |
| `clk_en` | `OSC_EN` | Required |
| `result_bit0` | *(not assigned)* | Auto-routed to GPIO17 |
| `result_bit0_en` | *(not assigned)* | Auto-routed to GPIO17_OE |
| `result_bit1` | *(not assigned)* | Auto-routed to GPIO18 |
| `result_bit1_en` | *(not assigned)* | Auto-routed to GPIO18_OE |

---

## Resource utilisation (verified on hardware)

| Resource | Used | Available | % |
|---|---|---|---|
| CLB LUT5s | 516 | 1120 | 46.1 |
| FFs | 230 | 1120 | 20.5 |
| CLB FFs | 225 | 1120 | 20.1 |
| CLBs | 109 | 140 | 77.9 |
| GPIOs | 6 | 19 | 31.6 |
| OSCs | 1 | 1 | 100 |

---

## Hardware required

- Shrike-lite (SLG47910 + RP2040)
- USB-C cable
- Multimeter or oscilloscope (optional — for physical pin verification)

---

## Directory structure

```
serv_riscv_shrike_lite/
├── ffpga/
│   ├── serv_shrike_top.v        ← Shrike top-level (Go Configure entry point)
│   ├── nuclear_rom.v            ← case()-based instruction ROM (no BRAM)
│   ├── serv_rf_ram_shrike.v     ← FF register file (replaces serv_rf_ram.v)
│   └── serv/                   ← SERV RTL files (clone from olofk/serv)
├── bitstream/
│   └── FPGA_bitstream_MCU.bin  ← pre-built bitstream, flash directly
├── firmware/
│   └── main.py                 ← MicroPython: flash FPGA + read result + print
├── docs/
│   ├── toolchain_failures.md   ← detailed failure + IO mapping analysis
│   └── assets/
│       └── serial_output.png   ← verified serial output screenshot
└── README.md
```

---

## Setup

### Step 1 — Get SERV RTL files

```bash
git clone https://github.com/olofk/serv
cp serv/rtl/*.v your_project/ffpga/serv/
```

> **Do not copy `serv_rf_ram.v`** — use `serv_rf_ram_shrike.v` instead.
> See `docs/toolchain_failures.md` — Failure 2 for why.

### Step 2 — Edit serv_rf_top.v

Find the `serv_rf_ram` instantiation and change it:

```verilog
// BEFORE (causes silent PNR failure)
serv_rf_ram #(.DEPTH(32), .RF_W(RF_W)) rf_ram (...);

// AFTER
serv_rf_ram_shrike #(.DEPTH(16), .RF_W(RF_W)) rf_ram (...);
```

### Step 3 — Build bitstream in Go Configure

> Skip if using the pre-built bitstream from `bitstream/`.

1. Open Go Configure → Develop → Forge FPGA → double-click **SLG47910 (BB)**
2. Name project `serv_riscv_shrike_lite` → Project Settings → first value each → OK
3. Double-click FPGA Core block

**Add files in order:**
```
ffpga/serv/serv_state.v
ffpga/serv/serv_decode.v
ffpga/serv/serv_immdec.v
ffpga/serv/serv_bufreg.v
ffpga/serv/serv_bufreg2.v
ffpga/serv/serv_alu.v
ffpga/serv/serv_mem_if.v
ffpga/serv/serv_csr.v
ffpga/serv/serv_ctrl.v
ffpga/serv/serv_rf_if.v
ffpga/serv/serv_rf_ram_if.v
ffpga/serv_rf_ram_shrike.v      ← custom file, NOT serv_rf_ram.v
ffpga/serv/serv_rf_top.v        ← edited in Step 2
ffpga/serv/serv_top.v
ffpga/nuclear_rom.v
ffpga/serv_shrike_top.v         ← top module
```

4. Click **Synthesize** → wait for green tick

5. **IO Planner — map ONLY these two signals:**

   | Signal | Resource |
   |---|---|
   | `clk` | `OSC_CLK` |
   | `clk_en` | `OSC_EN` |

   **Leave all result_bit signals UNASSIGNED.** They auto-route to GPIO17/18.

6. Click **Generate Bitstream** → wait for green tick

7. Bitstream location:
   ```
   project/ffpga/build/bitstream/FPGA_bitstream_MCU.bin
   ```
   > Some Go Configure versions name this `FPGA_bitstream_FLASH_MEM.bin` —
   > use whichever `.bin` file is in the `bitstream/` subfolder (45 KB).

### Step 4 — Flash and run (Thonny + MicroPython)

1. Flash Shrike-lite MicroPython UF2 if not done: hold BOOT + plug USB-C → drag UF2 to drive

2. Open **Thonny** → connect to MicroPython RP2040 (bottom-right)

3. View → Files → copy bitstream to board → rename to `serv_shrike.bin`

4. Open `firmware/main.py` → click **Run**

### Expected serial output

```
Flashing SERV bitstream to FPGA...
[shrike_flash] FPGA reset done
[shrike_fpga] Starting FPGA flash...
[shrike_fpga] flashing: serv_shrike.bin
[shrike_flash] FPGA programming done.
SERV RISC-V computed: 1 + 2 = 3
```

---

## Physical verification (optional)

After running, the FPGA GPIO pins hold their state indefinitely:

| RP2040 header pin | FPGA pin | Expected |
|---|---|---|
| GPIO15 | GPIO17 (result bit 0) | ~3.3 V |
| GPIO14 | GPIO18 (result bit 1) | ~3.3 V |
| GND | GND reference | 0 V |

Result = 3 = `0b11` → both pins HIGH simultaneously.

| GPIO15 | GPIO14 | Result | Diagnosis |
|---|---|---|---|
| 3.3 V | 3.3 V | 3 | Correct |
| 0 V | 0 V | 0 | CPU frozen — `sw` never executed |

---

## How it works

### RISC-V program (baked into `nuclear_rom.v`)

```asm
addi  x1, x0, 1        # x1 = 1
addi  x2, x0, 2        # x2 = 2
add   x3, x1, x2       # x3 = 3  ← the computation
lui   x4, 0x40000      # x4 = 0x40000000  (GPIO base address)
sw    x3, 0(x4)        # store result → latches GPIO17=1, GPIO18=1
jal   x0, 0            # halt (infinite loop)
```

### Data flow

```
Go Configure synthesises SERV + Nuclear ROM + GPIO decoder
           ↓  (at 50 MHz, takes ~4 µs)
sw x3, 0(x4) fires → dbus_dat[1:0] = 0b11 → gpio_result register latched
           ↓
FPGA internal signal → auto-routed to GPIO17 + GPIO18
           ↓  (via PCB 0-ohm resistors, hardwired)
RP2040 GPIO15 = HIGH (bit 0)
RP2040 GPIO14 = HIGH (bit 1)
           ↓
result = (bit1<<1)|bit0 = 3
           ↓
Thonny: "SERV RISC-V computed: 1 + 2 = 3"
```

---

## Toolchain notes

See [`docs/toolchain_failures.md`](docs/toolchain_failures.md) for complete analysis.

- Do **not** use `serv_rf_ram.v` — `$mem` → RAMSRL → silent routing failure → CPU frozen at PC=0.
- Do **not** use `$readmemh` — BRAM init broken → 800+ RAMSRL cells → compiler crash.
- Do **not** manually assign GPIO17/18 in IO Planner — auto-routing is required.

---

## References

- [SERV — The SErial RISC-V CPU](https://github.com/olofk/serv) by Olof Kindgren (ISC licence)
- [SLG47910 Datasheet](https://www.renesas.com/en/products/slg47910)
- [Shrike-lite documentation](https://vicharak-in.github.io/shrike/)
- [Shrike-lite pinouts](https://vicharak-in.github.io/shrike/shrike_pinouts.html)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)

---

## Licence

GPL-2.0 — consistent with the Shrike repository licence.
SERV RTL files retain their original ISC licence headers.
