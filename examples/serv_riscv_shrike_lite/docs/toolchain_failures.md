# Toolchain Failure Analysis — SERV on SLG47910

**Status: All three failures encountered, all fixed, verified on hardware.**

Three novel issues were discovered while porting SERV to the SLG47910 ForgeFPGA.
No prior public documentation exists for any of them.

---

## Failure 1 — BRAM initialisation crash

### Trigger
`$readmemh("program.hex", bram)` in the instruction memory.

### Failure chain
```
$readmemh
  → Yosys attempts SLG47910_BRAM primitive with pre-loaded content
  → Forge BRAM hex initialisation fails silently
  → Yosys falls back to RAMSRL (shift-register LUT RAM)
  → 128-byte ROM in RAMSRL = ~820 CLB LUTs consumed
  → Compiler aborts: resource overflow
```

### Fix — Nuclear ROM (`ffpga/nuclear_rom.v`)
Replace `$readmemh` + BRAM with a `case()` combinational block.
Yosys maps this to a pure LUT mux tree — no BRAM, no RAMSRL, no crash.

```verilog
// WRONG
reg [31:0] bram [0:31];
initial $readmemh("program.hex", bram);

// CORRECT
always @(*) begin
  case (i_adr[4:2])
    3'd0 : o_dat = 32'h00100093;  // addi x1, x0, 1
    3'd1 : o_dat = 32'h00200113;  // addi x2, x0, 2
    ...
  endcase
end
```

---

## Failure 2 — Silent register file routing failure ("CPU lobotomy")

### Trigger
Using `serv_rf_ram.v` from the SERV repository.

### Failure chain
```
reg [RF_W-1:0] mem [0:MEM_DEPTH-1]  in serv_rf_ram.v
  → Yosys infers $mem (synchronous RAM)
  → Yosys maps to RAMSRL primitives
  → Forge PNR accepts netlist — NO ERROR REPORTED
  → Forge PNR silently fails to route RAMSRL inside serv_rf_top
  → Register file outputs unconnected in placed design
  → Every register read returns 0
  → CPU fetches instructions but all source registers = 0
  → PC never advances past 0x00000000
  → Bitstream generates "successfully" with CPU completely broken
```

### Why this is dangerous
No error is reported. The bitstream generates. The CPU starts and draws power.
The only observable symptom is GPIO14/15 remaining at 0 V after flash.

### Fix — `(* ram_style = "registers" *)` (`ffpga/serv_rf_ram_shrike.v`)

```verilog
// WRONG — in serv_rf_ram.v
reg [RF_W-1:0] mem [0:MEM_DEPTH-1];

// CORRECT — in serv_rf_ram_shrike.v
(* ram_style = "registers" *) reg [RF_W-1:0] mem [0:MEM_DEPTH-1];
```

Forces Yosys to generate individual DFFs instead of RAMSRL cells.
The Forge PNR routes standard DFFs without any issues.

---

## Failure 3 — IO Planner explicit GPIO17/18 assignment breaks output

### Trigger
Manually assigning `result_bit0 → GPIO17_OUT` and `result_bit0_en → GPIO17_OE`
(and similarly for result_bit1/GPIO18) in the Go Configure IO Planner.

### Failure chain
```
Explicit IO Planner entry: result_bit0 → GPIO17_OUT
  → Forge PNR uses explicit io_spec_in.txt routing
  → Explicit routing conflicts with or overrides Yosys auto-routing
  → GPIO17/18 output enable not correctly set in placed design
  → GPIO pins remain tri-stated or driven to wrong level
  → RP2040 GPIO14/15 read 0V — result = 0 instead of 3
  → Looks identical to Failure 2 from the outside
```

### Why auto-routing works

The Shrike-lite PCB hardwires FPGA GPIO17 → RP2040 GPIO15 and FPGA GPIO18 →
RP2040 GPIO14 via 0-ohm resistors. These are the only two FPGA GPIOs with
direct RP2040 connections that are not claimed by the SPI config bus (GPIO3–6)
or enable signals (EN, PWR).

When `result_bit0` and `result_bit1` are marked `(* iopad_external_pin *)` but
NOT assigned in the IO Planner, Yosys routes them to the next available free
GPIOs. Because GPIO17 and GPIO18 are the only remaining free pins with RP2040
connections, they receive the signals automatically.

Explicit assignment disrupts this by injecting entries into `io_spec_in.txt`
that the PNR tool cannot reconcile with the auto-routing already performed by
synthesis.

### Fix — Leave result signals UNASSIGNED in IO Planner

| Signal | IO Planner action |
|---|---|
| `clk` | Assign to `OSC_CLK` |
| `clk_en` | Assign to `OSC_EN` |
| `result_bit0` | **Do not assign** |
| `result_bit0_en` | **Do not assign** |
| `result_bit1` | **Do not assign** |
| `result_bit1_en` | **Do not assign** |

---

## Summary

| | Failure 1 | Failure 2 | Failure 3 |
|---|---|---|---|
| Trigger | `$readmemh` | `$mem` / reg array | explicit GPIO17/18 IO Planner entry |
| Yosys mapping | RAMSRL | RAMSRL | — |
| PNR behaviour | overflow crash | silent route fail | explicit/auto conflict |
| Symptom | compiler abort | CPU frozen at PC=0 | GPIO14/15 reads 0V |
| Error reported? | yes | **no** | **no** |
| Fix | `case()` ROM | `ram_style=registers` | leave unassigned |
| File | `nuclear_rom.v` | `serv_rf_ram_shrike.v` | IO Planner only |

---

## General rule for SLG47910 designs

1. Avoid `$readmemh` — use `case()` or `localparam` ROM instead.
2. Use `(* ram_style = "registers" *)` on any small reg array.
3. Never rely on explicit IO Planner entries for signals marked `iopad_external_pin`
   if Yosys auto-routing already places them correctly — verify with a multimeter
   before overriding with manual assignments.
4. Treat silent bitstream generation + 0V on expected output pins as RAMSRL
   routing failure (Failure 2) or IO Planner conflict (Failure 3), not a logic error.
