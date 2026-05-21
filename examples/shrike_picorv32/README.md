# shrike_picorv32

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None

---

## Overview

This example runs Claire Wolf's [PicoRV32](https://github.com/YosysHQ/picorv32)
RV32I soft CPU on the SLG47910 ForgeFPGA of a Shrike-lite board. The CPU
executes a hardcoded 6-instruction program (`1 + 2 = 3`) out of a `case()`
based ROM, writes the result to a memory-mapped GPIO latch, and drives two
FPGA pins that are hardwired to RP2040 GPIO14/15 through PCB 0-ohm resistors.
The RP2040 reads the result and prints it over USB serial.

The point of the example is not the arithmetic -- it is that a general-purpose
RV32I CPU fits inside a 1K-LUT-class ForgeFPGA at all. Reaching that fit
required carry-chain restructuring and several CLB-packing rewrites; every
modification from upstream PicoRV32 is tagged `SHRIKE PATCH` in
`ffpga/src/picorv32.v` so the deltas are greppable.

## Expected Output

```
Flashing PicoRV32 bitstream to FPGA...
[shrike_flash] FPGA programming done.
PicoRV32 RISC-V computed: 1 + 2 = 3
```

---

## Compatibility

| Board | MCU | Status |
|---|---|---|
| Shrike-lite | RP2040 | Tested and working |
| Shrike | RP2350 | Untested |
| Shrike-fi | ESP32-S3 | Untested |

---

## Setup

### Step 1 -- Open in Go Configure

Launch Go Configure Software Hub, **New Project**, target chip **SLG47910 (BB)**.

Or, open the included `shrike_picorv32.ffpga` directly to skip manual setup.

If rebuilding from scratch, add Verilog files in this order:
```
ffpga/src/picorv32.v
ffpga/src/picorv32_regs_bram.v
ffpga/src/nuclear_rom.v
ffpga/src/shrike_picorv32_top.v
```

Save the project as `shrike_picorv32.ffpga` in the example root.

### Step 2 -- IO Planner

Assign **ONLY** these two signals:

| Signal | Resource |
|---|---|
| `clk` | `OSC_CLK` |
| `clk_en` | `OSC_EN` |

Leave `result_bit0`, `result_bit0_en`, `result_bit1`, `result_bit1_en`
**unassigned**. Yosys auto-routes them to FPGA GPIO17/18, which are the
only pins hardwired to RP2040 GPIO14/15 via PCB 0-ohm resistors. Manually
assigning them in IO Planner conflicts with that auto-routing and silently
breaks the connection.

### Step 3 -- Synthesize and generate bitstream

Click **Synthesize** then **Generate Bitstream**. Copy the produced
`FPGA_bitstream_MCU.bin` to `bitstream/shrike_picorv32.bin`.

### Step 4 -- Flash and run

Copy `bitstream/shrike_picorv32.bin` to the board via Thonny file panel,
then run `firmware/micropython/shrike_picorv32.py`.

---

## How to Change the Computation

Each entry in `nuclear_rom.v`'s `case()` block is one 32-bit RV32I
instruction. The default program is:

```asm
addi  x1, x0, 1        # x1 = 1
addi  x2, x0, 2        # x2 = 2
add   x3, x1, x2       # x3 = 3
lui   x4, 0x40000      # x4 = 0x40000000  (GPIO MMIO base)
sw    x3, 0(x4)        # store result -> latches GPIO17=1, GPIO18=1
jal   x0, 0            # halt (jump to self)
```

### Example -- compute 4 + 5 = 9

Open `ffpga/src/nuclear_rom.v` and change the program:

```verilog
always @(*) begin
  case (i_adr[4:2])
    3'd0 : o_dat = 32'h00400093;   // addi x1, x0, 4
    3'd1 : o_dat = 32'h00500113;   // addi x2, x0, 5
    3'd2 : o_dat = 32'h002081B3;   // add  x3, x1, x2  -> x3 = 9
    3'd3 : o_dat = 32'h40000237;   // lui  x4, 0x40000
    3'd4 : o_dat = 32'h00322023;   // sw   x3, 0(x4)
    3'd5 : o_dat = 32'h0000006F;   // jal  x0, 0       (halt)
    default : o_dat = 32'h00000013; // nop
  endcase
end
```

### Encoding your own `addi` instruction

`addi xD, x0, N` puts `N` into register `xD`. Rather than hand-encoding
the RV32I bit fields, the table below covers the common cases for the
first two registers (RV32E supports x1-x15):

| Value | `addi x1, x0, N` | `addi x2, x0, N` |
|---|---|---|
| 1  | `32'h00100093` | `32'h00100113` |
| 2  | `32'h00200093` | `32'h00200113` |
| 3  | `32'h00300093` | `32'h00300113` |
| 4  | `32'h00400093` | `32'h00400113` |
| 5  | `32'h00500093` | `32'h00500113` |
| 10 | `32'h00A00093` | `32'h00A00113` |
| 20 | `32'h01400093` | `32'h01400113` |

After editing, re-synthesise in Go Configure, regenerate the bitstream,
and copy the new `FPGA_bitstream_MCU.bin` to the board as
`shrike_picorv32.bin`.

### Result output width

The design exposes 2 result bits (`result_bit0`, `result_bit1`), so the
readable range is 0-3. For wider results, add more `result_bit*` pins to
`shrike_picorv32_top.v`, extend the GPIO MMIO latch width to match, and
update `firmware/micropython/shrike_picorv32.py` to read the extra
RP2040 GPIOs. See the Shrike pinout doc for available pins.

Programs are limited to the x1-x15 register range (RV32E -- the small
config disables x16-x31 to halve regfile cost).

---

## PicoRV32 Configuration

Locked parameters in `shrike_picorv32_top.v`:

| Parameter | Value | Reason |
|---|---|---|
| `ENABLE_REGS_16_31`    | 0 | RV32E (16 registers) -- halves regfile FFs |
| `ENABLE_REGS_DUALPORT` | 0 | single read port -- saves a 16:1 mux |
| `LATCHED_MEM_RDATA`    | 1 | saves an internal capture flop |
| `TWO_CYCLE_ALU`        | 0 | single-cycle ALU collapses 1-CLB carry clusters (P11) |
| `TWO_CYCLE_COMPARE`    | 0 | single-cycle compare path (P11) |
| `BARREL_SHIFTER`       | 0 | serial shift -- avoids 32-bit mux tree |
| `TWO_STAGE_SHIFT`      | 0 | further shrink |
| `COMPRESSED_ISA`       | 0 | no RVC decoder |
| `CATCH_MISALIGN`       | 0 | no trap logic |
| `CATCH_ILLINSN`        | 0 | no trap logic |
| `ENABLE_MUL`/`DIV`     | 0 | no M extension |
| `ENABLE_IRQ`           | 0 | no interrupt logic |
| `ENABLE_COUNTERS`      | 0 | no CSR counters |
| `ENABLE_PCPI`          | 0 | no coprocessor interface |
| `ENABLE_TRACE`         | 0 | no trace port |

The default `1+2=3` program uses x1-x4, well within the RV32E x1-x15
range. See [Result output width](#result-output-width) above for the
register-range note.

---

## References

- [PicoRV32](https://github.com/YosysHQ/picorv32) by Claire Wolf (ISC licence)
- [SLG47910 Datasheet](https://www.renesas.com/en/products/slg47910)
- [Shrike documentation](https://vicharak-in.github.io/shrike/)
- [Go Configure Software Hub](https://www.renesas.com/en/software-tool/go-configure-software-hub)

---

## Licence

PicoRV32 retains its original ISC licence (header preserved at the top of
`picorv32.v`). All Shrike-specific additions (carry-split patches, ROM,
top wrapper, firmware, docs) are GPL-2.0 to match the rest of this repo.
