# shrike_serv

> **Difficulty: Advanced**
> World's first documented port of a RISC-V soft CPU to the Renesas SLG47910 ForgeFPGA.

This example runs [SERV](https://github.com/olofk/serv) — the world's smallest
RISC-V CPU (RV32I, bit-serial) — directly on the SLG47910 FPGA fabric of the
Shrike board. The RP2040/RP2350 flashes the bitstream, reads two GPIO pins, and
prints the computation result over USB serial.

```
SERV RISC-V computed: 1 + 2 = 3
```

---

## Compatibility

| Board | MCU | Status |
|---|---|---|
| Shrike-lite | RP2040 | Tested and working |
| Shrike | RP2350 | Untested — pin map may differ |
| Shrike-fi | ESP32-S3 | Untested |

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

## Directory structure

```
shrike_serv/
├── ffpga/
│   ├── shrike_serv.ffpga        ← Go Configure project file
│   ├── serv_shrike_top.v        ← Shrike top-level wrapper
│   ├── nuclear_rom.v            ← case()-based instruction ROM
│   ├── serv_rf_ram_shrike.v     ← FF register file (replaces serv_rf_ram.v)
│   └── serv/                   ← SERV RTL (clone from olofk/serv)
├── bitstream/
│   └── shrike_serv.bin         ← pre-built bitstream
├── firmware/
│   └── micropython/
│       └── shrike_serv.py      ← MicroPython: flash + read + print
└── README.md
```

---

## Setup

### Step 1 — Get SERV RTL files

```bash
git clone https://github.com/olofk/serv
cp serv/rtl/*.v ffpga/serv/
```

> **Do not copy `serv_rf_ram.v`** — use `serv_rf_ram_shrike.v` instead.

### Step 2 — Edit serv_rf_top.v

Find the `serv_rf_ram` instantiation and replace it:

```verilog
// BEFORE
serv_rf_ram #(.DEPTH(32), .RF_W(RF_W)) rf_ram (...);

// AFTER
serv_rf_ram_shrike #(.DEPTH(16), .RF_W(RF_W)) rf_ram (...);
```

### Step 3 — Open the project in Go Configure

Open `ffpga/shrike_serv.ffpga` directly in Go Configure Software Hub.
All sources are pre-configured. If rebuilding from scratch, add files in this order:

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
ffpga/serv_rf_ram_shrike.v      ← NOT serv_rf_ram.v
ffpga/serv/serv_rf_top.v
ffpga/serv/serv_top.v
ffpga/nuclear_rom.v
ffpga/serv_shrike_top.v
```

**IO Planner — assign ONLY:**

| Signal | Resource |
|---|---|
| `clk` | `OSC_CLK` |
| `clk_en` | `OSC_EN` |

**Leave all `result_bit*` signals unassigned** — see toolchain note 3 below.

Click **Synthesize** then **Generate Bitstream**. Output: `ffpga/build/bitstream/FPGA_bitstream_MCU.bin`

### Step 4 — Flash and run

1. Hold BOOT + plug USB-C → drag Shrike MicroPython UF2 to drive (first time only)
2. Open **Thonny** → connect MicroPython RP2040 (bottom-right)
3. View → Files → copy `bitstream/shrike_serv.bin` to board
4. Open `firmware/micropython/shrike_serv.py` → click **Run**

### Expected output

```
Flashing SERV bitstream to FPGA...
[shrike_flash] FPGA programming done.
SERV RISC-V computed: 1 + 2 = 3
```

---

## Physical verification (multimeter)

GPIO pins stay latched after execution:

| RP2040 pin | FPGA pin | Expected |
|---|---|---|
| GPIO15 | GPIO17 (result bit 0) | ~3.3 V |
| GPIO14 | GPIO18 (result bit 1) | ~3.3 V |

Result = 3 = `0b11` → both pins HIGH simultaneously.

---

## How it works

### RISC-V program (in `nuclear_rom.v`)

```asm
addi  x1, x0, 1        # x1 = 1
addi  x2, x0, 2        # x2 = 2
add   x3, x1, x2       # x3 = 3
lui   x4, 0x40000      # x4 = 0x40000000  (GPIO base)
sw    x3, 0(x4)        # store result → latches GPIO17=1, GPIO18=1
jal   x0, 0            # halt
```

### Data flow

```
SERV executes at 50 MHz inside SLG47910 FPGA fabric
  ↓  sw x3, 0(x4) fires
gpio_result register latches dbus_dat[1:0] = 0b11
  ↓  auto-routed to FPGA GPIO17 + GPIO18
  ↓  via PCB 0-ohm resistors (hardwired on Shrike-lite)
RP2040 GPIO15 = HIGH, GPIO14 = HIGH
  ↓
result = (bit1<<1)|bit0 = 3
  ↓
"SERV RISC-V computed: 1 + 2 = 3"
```

---

## Toolchain notes (novel findings for SLG47910)

Three undocumented issues were found and fixed during development.

### 1. BRAM initialisation crash

**Trigger:** `$readmemh("program.hex", bram)` in instruction memory.

**Failure chain:**
```
$readmemh → Yosys attempts SLG47910_BRAM with pre-loaded content
         → Forge BRAM hex init fails silently
         → Falls back to RAMSRL (shift-register LUT RAM)
         → 128-byte ROM in RAMSRL = ~820 CLB LUTs
         → Compiler aborts: resource overflow
```

**Fix:** Replace with `case()` combinational block → pure LUT mux tree,
no BRAM, no RAMSRL, no crash. See `ffpga/nuclear_rom.v`.

---

### 2. Silent register file routing failure

**Trigger:** Using `serv_rf_ram.v` from the SERV repository.

**Failure chain:**
```
reg [RF_W-1:0] mem [0:MEM_DEPTH-1]
  → Yosys infers $mem → maps to RAMSRL
  → Forge PNR accepts netlist — NO ERROR REPORTED
  → Forge PNR silently fails to route RAMSRL inside serv_rf_top
  → Register file outputs disconnected in placed design
  → Every register read returns 0
  → CPU frozen at PC=0x00000000 indefinitely
  → Bitstream generates "successfully"
```

**Fix:** `(* ram_style = "registers" *)` attribute forces Yosys to generate
individual DFFs instead of RAMSRL. PNR routes standard DFFs cleanly.
See `ffpga/serv_rf_ram_shrike.v`.

---

### 3. IO Planner explicit GPIO17/18 assignment breaks output

**Trigger:** Manually assigning `result_bit0 → GPIO17_OUT` in IO Planner.

**Why it happens:** FPGA GPIO17/18 are the only FPGA pins hardwired to RP2040
GPIO14/15 via PCB 0-ohm resistors (not used by SPI config bus or EN/PWR pins).
When `result_bit*` signals carry `(* iopad_external_pin *)` but are NOT assigned
in IO Planner, Yosys auto-routes them to the only available free pins with RP2040
connections — GPIO17 and GPIO18. Explicit IO Planner entries in `io_spec_in.txt`
conflict with this auto-routing and break the connection silently.

**Fix:** Assign ONLY `clk → OSC_CLK` and `clk_en → OSC_EN` in IO Planner.
Leave all `result_bit*` signals unassigned.

---

## References

- [SERV — The SErial RISC-V CPU](https://github.com/olofk/serv) by Olof Kindgren (ISC licence)
- [SLG47910 Datasheet](https://www.renesas.com/en/products/slg47910)
- [Shrike documentation](https://vicharak-in.github.io/shrike/)
- [Shrike pinouts](https://vicharak-in.github.io/shrike/shrike_pinouts.html)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)

---

## Licence

GPL-2.0 — consistent with the Shrike repository licence.
SERV RTL files retain their original ISC licence headers.
