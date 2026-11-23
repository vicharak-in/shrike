# Developer Notes & Hardware Technical Audit

Technical notes, verified hardware interconnects, electrical safety, and toolchain audit details for the Shrike-TraceRunner project.

---

## 1. FPGA Control Datapath & Servo Pulse Generation

The control datapath is targeted for the **Renesas ForgeFPGA SLG47910** (BB silicon) on the Shrike-Fi board:

- **Clock Source**: 50 MHz internal relaxation oscillator (`OSC_CLK`).
- **Control Pipeline**: 2-stage synchronous pipeline:
  - **Stage 1 (Centroid & PID Arithmetic)**: 8-bit sensor decode $\to$ signed error $[-7, +7]$ $\to$ proportional, integral (with $\pm 511$ anti-windup clamp), and backward-difference derivative calculation $\to$ scaled steering term ($\gg 4$).
  - **Stage 2 (Differential Motor Mixer & Pulse Generator)**: Differential mixing ($PWM_L = \text{speed} - \text{steer}$, $PWM_R = \text{speed} + \text{steer}$) $\to$ 50 Hz RC servo pulse translation.
- **50 Hz Continuous Rotation Servo Pulse Engine**:
  - Period: $20\,\text{ms}$ ($1,000,000$ cycles at 50 MHz).
  - Microsecond tick prescaler: divide-by-50 counter generates a precise $1\,\mu\text{s}$ timebase.
  - Active pulse range: $1000\,\mu\text{s}$ to $2000\,\mu\text{s}$.
  - Neutral / zero-rotation center: $1500\,\mu\text{s}$ ($PWM = 100$).
  - Chassis symmetry: Right servo pulse is mirrored in hardware ($1500 - (PWM_R - 100) \times 3$) because continuous servos face opposite directions on a 2-wheel differential chassis.
  - Zero-creep silence: When disarmed (`is_armed == 0` or `CMD == 0x00`), target pulse widths are forced to 0, producing a flat 0V DC signal. This completely prevents continuous rotation servos from jittering or creeping when stopped.
- **RTL Safety Interlocks**:
  - **Power-on Safe Reset**: All servo outputs and `motor_en_out` are held strictly LOW during power-on reset.
  - **Hardware SPI Watchdog**: A 50 ms timeout counter ($2,500,000$ cycles at 50 MHz) automatically asserts `watchdog_tripped` and drops `motor_en_out` to 0 if valid SPI frames cease.
  - **Checksum Verification**: Any SPI frame failing the XOR checksum immediately asserts `parity_error_flag` and drops `motor_en_out` to 0.
  - **Zero-Speed Interlock**: If `base_speed == 0`, motor outputs remain strictly 0 even if `line_lost` is asserted.

---

## 2. SPI Protocol & Timing (ESP32-S3 $\leftrightarrow$ ForgeFPGA)

The Shrike-Fi connects the ESP32-S3 and ForgeFPGA via 4 dedicated SPI lines:
- `SCK`: ESP32 GPIO 12 $\to$ FPGA Pin 3 (PMOD J5 Pin 10)
- `SS_N`: ESP32 GPIO 10 $\to$ FPGA Pin 4 (PMOD J5 Pin 9)
- `MOSI`: ESP32 GPIO 11 $\to$ FPGA Pin 5 (PMOD J5 Pin 12)
- `MISO`: FPGA Pin 6 $\to$ ESP32 GPIO 13 (PMOD J5 Pin 11)

Bus config: 2.0 MHz SPI clock, Mode 0 (`CPOL=0, CPHA=0`), MSB first.

### 1 kHz Loop Feasibility:
- A 4-byte SPI transaction at 2.0 MHz takes:
  $$T_{\text{tx}} = \frac{32\text{ bits}}{2\text{ MHz}} = 16.0\,\mu\text{s}$$
- In a 1 kHz (1,000 $\mu$s) control loop:
  - SPI transmission overhead: $16\,\mu\text{s}$ (only **1.6% bus utilization**).
  - Remaining CPU time for ESP32 sensor read and serial handling: $984\,\mu\text{s}$ (98.4%).
- 1 kHz deterministic updates operate with wide timing margins.

### Packet Format (4 bytes full-duplex per 1 ms cycle)

```text
Downlink (MCU -> FPGA):
  Byte 0: CMD       (0x00 = Disarm, 0x10 = Run, 0x20 = Set Kp, 0x21 = Set Ki, 0x22 = Set Kd, 0xFF = Reset)
  Byte 1: SENSORS   (Bit 7 = Far Left ... Bit 0 = Far Right. 1 = Line detected)
  Byte 2: SPEED     (Base forward motor PWM, 0-255)
  Byte 3: CHECKSUM  (CMD ^ SENSORS ^ SPEED)

Uplink (FPGA -> MCU):
  Byte 0: STATUS    (Bit 7: Heartbeat, Bit 6: Line Lost, Bit 5: I-Sat, Bit 4: Steer-Sat,
                     Bit 3: Parity Err, Bit 2: Last Dir, Bit 1: Watchdog Trip, Bit 0: Armed)
  Byte 1: PWM_LEFT  (Calculated Left motor speed, 0-255)
  Byte 2: PWM_RIGHT (Calculated Right motor speed, 0-255)
  Byte 3: ERROR     (Signed line error, -7 to +7)
```

---

## 3. Power Architecture & Electrical Safety

- **Battery Protection**: 2S Li-ion battery pack (7.4V nominal, 6.0V–8.4V operating range) MUST use a 2S BMS protection board with over-discharge cut-off ($\le 3.0\text{V/cell}$ / 6.0V total), overcharge protection, and short-circuit protection.
- **Over-Current Protection**: A master toggle switch and an inline **3A fast-acting fuse** must be installed on the battery positive lead.
- **Regulated Servo Supply**:
  - Servos must **never** be powered from the 3.3V rail or FPGA pins.
  - A dedicated DC-DC step-down buck converter adjusted to **5.0V DC** (rated $\ge 2.5\text{A}$) supplies the continuous rotation servo VCC leads.
- **Regulated Logic Supply**: The Shrike-Fi 5V input header is powered from the regulated 5.0V buck rail.
- **Common Ground**: Strict star ground topology tying Battery (-), Buck GND, Shrike-Fi GND, and Servo GNDs at a single point to prevent ground loops.

---

## 4. Current Verification & Testing Status

| Stage | Feature / Component | Status | Verification Method |
| :--- | :--- | :---: | :--- |
| **RTL Source** | Centroid error encoder | Implemented | Verilog source (`line_position_encoder.v`) |
| **RTL Source** | 2-stage pipelined PID controller | Implemented | Verilog source (`pid_controller.v`) |
| **RTL Source** | Differential mixer & memory pivot | Implemented | Verilog source (`motor_mixer.v`) |
| **RTL Source** | 50 Hz continuous servo pulse engine | Implemented | Verilog source (`pid_top.v`) |
| **RTL Source** | SPI slave & watchdog failsafe | Implemented | Verilog source (`spi_target.v`, `pid_top.v`) |
| **Simulation** | Python golden model & servo tests | **PASSED** | `pytest tests/` (13/13 assertions passing) |
| **Static Check**| Verilator lint & static timing | **PASSED** | Verilator v5.034 (0 errors, 0 warnings) |
| **Synthesis** | Generic Yosys Netlist Elaboration | **PASSED** | Yosys v59 AST elaboration (clean hierarchy) |
| **Simulation** | HDL Timing Simulation (89.1 ms) | **PASSED** | Icarus Verilog (`tb_pid_top.v`, 5/5 hardware tests) |
| **Vendor Flow** | Renesas ForgeFPGA Place & Route | **PASSED** | Go Configure Hub v6.56 ($F_{max} = 38.64\,\text{MHz}$) |
| **Bitstream** | FPGA SRAM bitstream packing | **PASSED** | Packed into `pid_bitstream.h` (46,408 bytes) |
| **Firmware** | ESP32-S3 Arduino sketch | **PASSED** | Built with `arduino-cli` & uploaded to board |
