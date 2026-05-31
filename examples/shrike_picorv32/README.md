# shrike_picorv32

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

---

## Overview

This example runs Claire Wolf's [PicoRV32](https://github.com/YosysHQ/picorv32)
**RV32I** soft CPU on the SLG47910 ForgeFPGA of a Shrike-lite board. The point
of the example is that a *general-purpose, full 32-register RV32I CPU* fits
inside a 1K-LUT-class ForgeFPGA at all.

The CPU executes a baked-in **instruction-variety self-test** out of a `case()`
based ROM. A single accumulator (`x10`) is threaded through 27 distinct RV32I
opcodes; the final value is written to a memory-mapped GPIO latch, which drives
two FPGA pins hardwired to RP2040 GPIO14/15 through PCB 0-ohm resistors. The
RP2040 reads those two bits and prints PASS/FAIL over USB serial.

**A correct RV32I core leaves the result at exactly 3** (both bits high). Any
other value means an instruction misbehaved.

Fitting a full RV32I core in this fabric required two things:

1. **Area work** — the register file is moved out of fabric flip-flops into the
   on-die BRAM (`picorv32_regs_bram.v`), and the adder/compare/shift datapaths
   are restructured to suit the SLG47910's 4-bit carry chains. Every change
   from upstream PicoRV32 is tagged `SHRIKE PATCH` in `ffpga/src/picorv32.v` so
   the deltas are greppable.
2. **A correctness fix** — the SLG47910 BRAM read is *synchronous* (data valid
   one cycle after the address), but PicoRV32's register-file interface assumes
   a combinational read. Without a fix, register reads return stale data and the
   CPU computes garbage. Correctness fix `CF1` adds a read-latency wait-state
   (`RS_READ_LATENCY = 2`) that stalls until the BRAM read data is valid. This
   is why the self-test passes here.

## Expected Output

```
Flashing PicoRV32 bitstream to FPGA...
[shrike_flash] FPGA programming done.
PicoRV32 RV32I self-test result = 3 -> PASS (all 27 opcodes correct)
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

No external hardware required. The two result pins (FPGA GPIO17/18) are already
wired to RP2040 GPIO15/14 on the Shrike-lite PCB.

---

## System Architecture

```
picorv32 ---mem bus---> nuclear_rom        (instruction fetch, 1-cycle ack)
picorv32 ---mem bus---> GPIO decode         (store to 0x40000000 -> latch)
picorv32 <--BRAMx_*---> 8x on-die BRAM      (register file via PICORV32_REGS)
gpio_latch -----------> GPIO17 / GPIO18 --> RP2040 GPIO15 / GPIO14
```

- **Instruction ROM** (`nuclear_rom.v`): a combinational `case (mem_addr[6:2])`
  block returning one 32-bit RV32I instruction per word. No `$readmemh`, so
  there is no RAM-inference fallback for Yosys to choke on.
- **Register file** (`picorv32_regs_bram.v`): all 32 registers live in eight
  512x8 BRAM slices instead of fabric FFs. The 32 registers are split low/high
  (BRAM0-3 = `x0..x15`, BRAM4-7 = `x16..x31`); see the file header for the
  addressing scheme.
- **GPIO result latch**: a store to any `0x4xxxxxxx` address latches the low 2
  bits of the stored word onto `result_bit0/1`.

---

## Quick Start (Pre-Built Bitstream)

1. Connect the Shrike-lite board via USB.
2. Copy `bitstream/shrike_picorv32.bin` to the board filesystem (e.g. via the
   Thonny file panel).
3. Run `firmware/micropython/shrike_picorv32.py`.
4. Observe `... result = 3 -> PASS` over USB serial.

---

## Build From Source

### Step 1 — Open in Go Configure

Launch Go Configure Software Hub, **New Project**, target chip **SLG47910 (BB)**
— or open the included `shrike_picorv32.ffpga` directly to skip manual setup.

If rebuilding from scratch, add the Verilog files:
```
ffpga/src/picorv32_regs_bram.v
ffpga/src/picorv32.v
ffpga/src/nuclear_rom.v
ffpga/src/shrike_picorv32_top.v
```

### Step 2 — Enable BRAM

The register file uses all **8 BRAM slices**, so enable **both** BRAM banks
(North = BRAM0-3, South = BRAM4-7) in the project's BRAM configuration.

### Step 3 — IO Planner

Assign **ONLY** these two signals:

| Signal | Resource |
|---|---|
| `clk` | `OSC_CLK` |
| `clk_en` | `OSC_EN` |

Leave `result_bit0/1`, `result_bit0/1_en`, and all `BRAMx_*` ports
**unassigned**. Yosys auto-routes the result bits to FPGA GPIO17/18 (the only
pins hardwired to RP2040 GPIO14/15 via PCB 0-ohm resistors) and the `BRAMx_*`
ports to the on-die BRAM. Manually assigning them conflicts with that
auto-routing and silently breaks the connection.

### Step 4 — Synthesize and generate bitstream

Click **Synthesize** then **Generate Bitstream**. Copy the produced
`FPGA_bitstream_MCU.bin` to `bitstream/shrike_picorv32.bin`.

---

## The Self-Test Program

The ROM (`nuclear_rom.v`, with each word commented) runs 27 distinct RV32I
opcodes in exactly 32 instruction words:

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

Each entry in `nuclear_rom.v`'s `case (mem_addr[6:2])` block is one 32-bit
RV32I instruction word. To run your own program, replace the entries. For a
trivial example that drives result = 1:

```verilog
always @(*) begin
  case (mem_addr[6:2])
    5'd0 : rom_data = 32'h00100513;   // addi x10, x0, 1   -> x10 = 1
    5'd1 : rom_data = 32'h400004B7;   // lui  x9, 0x40000  (GPIO base)
    5'd2 : rom_data = 32'h00A4A023;   // sw   x10, 0(x9)   -> latch bit0 = 1
    5'd3 : rom_data = 32'h0000006F;   // jal  x0, 0        (halt)
    default : rom_data = 32'h00000013; // nop
  endcase
end
```

The easiest workflow is to write RV32I assembly, assemble it with a `riscv*-elf`
toolchain (`-march=rv32i -mabi=ilp32`), and paste the resulting word encodings
into the `case`. After editing, re-synthesise, regenerate the bitstream, and
copy the new `FPGA_bitstream_MCU.bin` to the board as `shrike_picorv32.bin`.

### Program-size limit (important)

The program counter is narrowed to **7 bits** (`localparam PC_W = 7` in
`picorv32.v`) — an area optimisation that costs nothing for small programs but
caps the program at **128 bytes = 32 instruction words**. The ROM's `case`
decodes `mem_addr[6:2]` accordingly. Programs longer than 32 words will wrap;
keep yours within the budget.

### Result output width

The design exposes 2 result bits (`result_bit0`, `result_bit1`), so the readable
range is 0-3. For wider results, add more `result_bit*` pins to
`shrike_picorv32_top.v`, widen the GPIO latch to match, and update the firmware
to read the extra RP2040 GPIOs. See the Shrike pinout doc for available pins.

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
`grep "CORRECTNESS FIX"` in `ffpga/src/picorv32.v` finds every site.

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
BRAM register file, ROM, top wrapper, firmware, docs) are GPL-2.0 to match the
rest of this repo.
