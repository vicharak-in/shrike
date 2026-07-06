## FPGA Source Files

Each module performs a dedicated function within the CORDIC processing pipeline, enabling hardware computation of **SIN**, **COS**, and **TAN** for digital communication applications.

| File | Purpose | Functionality |
|------|---------|---------------|
| **top.v** | Top-level FPGA module | Integrates all FPGA modules, manages system control, and connects the SPI interface, quadrant reduction, CORDIC engine, and linear divider into a complete hardware processing pipeline. |
| **spi_target.v** | SPI Communication Interface | Implements the FPGA SPI target, receives angle data from the RP2040, decodes SPI commands, and returns hardware-generated SIN, COS, and TAN values to the host through dedicated registers. |
| **quadrant.v** | Quadrant Reduction | Reduces any input angle to the first quadrant before CORDIC processing while recording the original quadrant information for correct sign restoration of the final outputs. |
| **cordic_core.v** | CORDIC Rotation Engine | Implements an 8-iteration fixed-point Rotation Mode CORDIC algorithm to compute hardware-generated sine and cosine values using only shift, add, and subtract operations. |
| **atan_rom.v** | Arctangent Lookup Table | Stores the precomputed arctangent constants (`atan(2⁻ⁱ)`) required during each CORDIC iteration, eliminating the need for runtime trigonometric calculations. |
| **linear_divide.v** | Linear CORDIC Divider | Computes the tangent value using the hardware-generated sine and cosine outputs through a 6-iteration shift-add linear division algorithm, avoiding conventional hardware dividers. |
