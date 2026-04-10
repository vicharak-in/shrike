
# Drive PLL From Oscillator — Shrike-Lite FPGA Demo

This project implements the Renesas application note **"How to Drive PLL from Oscillator"** using the same SLG47910 FPGA found on **Shrike-Lite**. The design demonstrates selecting the PLL input clock source, using bypass mode, and adjusting PLL frequency parameters dynamically. fileciteturn0file0

It also includes a simple 4-bit counter driven by the PLL clock output, allowing real-time frequency observation on output pins.

---

## Function Summary

| Feature | Status |
|--------|--------|
| PLL driven from internal 50MHz oscillator | ✔ |
| PLL driven from external clock (GPIO2) | ✔ |
| Bypass mode support | ✔ |
| Live frequency scaling via REFDIV/FBDIV/POSTDIV1/POSTDIV2 | ✔ |
| 4-bit counter running off PLL output | ✔ |

Operation is identical to the behavior described in the reference document.  
The clock path can be switched using the `PLL_REF_CLK_SEL` input pin:

| SEL | PLL Reference Source |
|---|------------------|
| 0 | Internal 50 MHz OSC |
| 1 | External clock through GPIO2 |

---

## PLL Frequency Equation

These all are calculated in the software however can check these formualas.

From the Renesas documentation:

**FOUT = FREFF × (FBDIV / (REFDIV × POSTDIV1 × POSTDIV2))**  
Where FREFF is either internal 50 MHz or external input. fileciteturn0file0

Example configurations included in the original paper:

| FREF (MHz) | REFDIV | FBDIV | POST1 | POST2 | FOUT (MHz) |
|---|---|---|---|---|---|
| 50 | 2 | 32 | 5 | 4 | 40 |
| 50 | 3 | 40 | 7 | 7 | 13.6 |
| 50 | 1 | 16 | 4 | 2 | 100 |


---

## Included Signals

| Signal | Purpose |
|---|---|
| SEL (GPIO0) | Clock select — internal/external |
| BYP (GPIO1) | Bypass PLL direct-through clock |
| EXT_CLK (GPIO2) | External reference input |
| PLL_CLK | PLL output used as system clock |
| COUNTER[3:0] | Visual frequency check output |

When **BYP = 1**, PLL output = selected reference clock.  
When **BYP = 0**, PLL output is divided/multiplied by configured ratios. fileciteturn0file0

---

## Testing this on Shrike-Lite

1. Load bitstream using ForgeFPGA toolchain  
2. Connect logic analyzer to counter pins  
3. Toggle SEL to switch between OSC and external clock  
4. Toggle BYP to enable/disable PLL processing  
5. Observe frequency change in real time

Shrike-Lite behaves identically to the application note linked [here](https://www.renesas.com/en/document/apn/fg-006-how-drive-pll-oscillator?r=25546631)

