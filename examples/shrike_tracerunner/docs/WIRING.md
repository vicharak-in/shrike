# Shrike-TraceRunner - Electrical & Wiring Guide

Wiring specifications, power distribution, pin mappings, and electrical safety rules for the Vicharak Shrike-Fi line-following robot.

---

## 1. Electrical Architecture & Safety Rules

> [!CAUTION]
> **CRITICAL ELECTRICAL SAFETY RULES:**
> 1. **Do not power servos from the 3.3V rail or FPGA pins.** Continuous rotation servos draw peak stall currents of $300 - 500\,\text{mA}$ each. Sourcing power from the 3.3V rail or FPGA PMOD pins will brown out the microcontroller and risk permanently damaging the ForgeFPGA output buffers. **Always power servo VCC from a regulated 5.0V DC-DC buck converter.**
> 2. **Battery Protection is Mandatory.** If using raw 18650 Li-ion cells, always run them through a **2S BMS (Battery Management System)** board that provides:
>    - Over-discharge cutoff ($\le 3.0\,\text{V}$ per cell / $6.0\,\text{V}$ total pack).
>    - Over-charge cutoff ($\ge 4.25\,\text{V}$ per cell / $8.5\,\text{V}$ pack).
>    - Short-circuit protection.
> 3. **Physical Protection:** Install a **3A fast-acting fuse** and a physical power toggle switch directly on the positive battery lead.
> 4. **Common Star Ground:** All grounds (Battery negative, 5V buck ground, Shrike-Fi ground, servo grounds, and sensor ground) **must tie together at a single common star ground point** to prevent inductive ground bounce and SPI communication dropouts.

---

## 2. Power Distribution Topology

```text
                  +------------------------------------------------+
                  |  2S Li-ion Battery (7.4V Nom, 6.0V - 8.4V)     |
                  |  with Integrated 2S BMS (Over-discharge Cutoff)|
                  +-----------------------+------------------------+
                                          | (+) Pack Positive
                                   [Master Switch]
                                          |
                                   [ 3A Fast Fuse ]
                                          |
                                          +------------------------+
                                          | (+) Raw Bat (6.0V-8.4V)
                                          v
                         +----------------------------------+
                         | 5.0V High-Efficiency Buck Reg   |
                         | Vin: 6.0V - 8.4V                 |
                         | Vout: Regulated 5.0V DC          |
                         | Rating: >= 2.5A Continuous       |
                         +----------------+-----------------+
                                          |
                        +-----------------+-----------------+
                        | (+) Regulated 5.0V                | (+) Regulated 5.0V
                        v                                   v
         +-----------------------------+     +-----------------------------+
         | Dual 360° Continuous Servos |     | Vicharak Shrike-Fi Board    |
         | (FS90R / SG90-360)          |     | - Header 5V: +5.0V Logic In |
         | - Left VCC (Red): +5.0V     |     | - Header GND: Star Ground   |
         | - Right VCC (Red): +5.0V    |     | - Header 3V3: +3.3V Out     |
         | - GNDs (Brown): Star Ground |     +--------------+--------------+
         +-----------------------------+                    |
                                                            | (+) 3.3V
                                                            v
                                             +-----------------------------+
                                             | 8-Channel Digital IR Sensor |
                                             | - VCC: +3.3V (from Shrike)  |
                                             | - GND: Common Star Ground   |
                                             +-----------------------------+
```

---

## 3. Pin Interconnect & Interface Tables

### 3.1 Dual 360° Continuous Rotation Servos $\rightarrow$ ForgeFPGA (PMOD J5)

The servos connect directly to the ForgeFPGA outputs on PMOD connector J5:

| Servo Lead | Pin / Net | SLG47910 Pin | Signal / Description |
| :--- | :---: | :---: | :--- |
| **Left Signal** (White / Orange) | **PMOD J5 Pin 5** | `Pin 24` (`F_GPIO9`) | `pwm_left_out` (50 Hz RC pulse, $1000 - 2000\,\mu\text{s}$) |
| **Left Power** (Red) | Regulated 5.0V Rail | &mdash; | Dedicated 5.0V Buck output |
| **Left Ground** (Black / Brown) | Common Star Ground | &mdash; | 0V Power Ground |
| **Right Signal** (White / Orange) | **PMOD J5 Pin 6** | `Pin 23` (`F_GPIO8`) | `pwm_right_out` (50 Hz RC pulse, mirrored) |
| **Right Power** (Red) | Regulated 5.0V Rail | &mdash; | Dedicated 5.0V Buck output |
| **Right Ground** (Black / Brown) | Common Star Ground | &mdash; | 0V Power Ground |

*Note on Servo Mounting:* Because the continuous servos face opposite directions on the robot chassis, the FPGA RTL automatically mirrors the right servo pulse ($Pulse_R = 1500 - (PWM_R - 100) \times 3$) so that positive throttle drives both wheels forward symmetrically.

---

### 3.2 8-Channel Digital IR Sensor Array $\rightarrow$ ESP32-S3

The 8 sensor channels are sampled digitally by the ESP32-S3 GPIO headers. Power is sourced strictly from the Shrike-Fi **3.3V** rail:

| Sensor Module Pin | ESP32-S3 Pin | Function / Position | Logic Standard |
| :---: | :---: | :--- | :---: |
| **VCC** | **3.3V Rail** | Sensor Array Power ($\le 150\,\text{mA}$) | 3.3V DC |
| **GND** | **GND Rail** | Common Signal Ground | 0V |
| **D0** | **GPIO 1** | Far Right Sensor (Bit 0) | 3.3V LVCMOS |
| **D1** | **GPIO 2** | Right Outer Sensor (Bit 1) | 3.3V LVCMOS |
| **D2** | **GPIO 4** | Right Mid Sensor (Bit 2) | 3.3V LVCMOS |
| **D3** | **GPIO 5** | Right Center Sensor (Bit 3) | 3.3V LVCMOS |
| **D4** | **GPIO 6** | Left Center Sensor (Bit 4) | 3.3V LVCMOS |
| **D5** | **GPIO 7** | Left Mid Sensor (Bit 5) | 3.3V LVCMOS |
| **D6** | **GPIO 15** | Left Outer Sensor (Bit 6) | 3.3V LVCMOS |
| **D7** | **GPIO 16** | Far Left Sensor (Bit 7) | 3.3V LVCMOS |

*Why Sensors Connect to ESP32 instead of FPGA:* The ForgeFPGA PMOD connector (J5) only exposes 4 usable user GPIOs (pins 9..12 are tied to internal SPI). The 8 sensor lines physically require the ESP32 GPIO header. The ESP32 aggregates the sensor byte and streams it to the FPGA over SPI at 1 kHz.

---

### 3.3 ForgeFPGA PMOD Connector J5 Reference

Verified against the Shrike-Fi schematic (`FPGA.kicad_sch`):

| PMOD J5 Pin | Schematic Net | SLG47910 Pin | Function / Signal | Notes |
| :---: | :---: | :---: | :--- | :--- |
| **Pin 1, 2** | `+3.3V` | VDDIO Rail | 3.3V Logic Rail | Power rail |
| **Pin 3, 4** | `GND` | Ground Rail | Common Signal Ground | Power ground |
| **Pin 5** | `F_GPIO9` | **Pin 24** | **`pwm_left_out`** | 50 Hz RC servo pulse (Left) |
| **Pin 6** | `F_GPIO8` | **Pin 23** | **`pwm_right_out`** | 50 Hz RC servo pulse (Right) |
| **Pin 7** | `F_GPIO11` | **Pin 2** | `motor_en_out` | Hardware enable / failsafe |
| **Pin 8** | `F_GPIO10` | **Pin 1** | Spare / Status Indicator | 3.3V LVCMOS |
| **Pin 9** | `F_GPIO13` | **Pin 4** | *ESP32 SPI_SS (GPIO 10)* | **DO NOT WIRE** (Internal PCB SPI Bus) |
| **Pin 10** | `F_GPIO12` | **Pin 3** | *ESP32 SPI_SCLK (GPIO 12)* | **DO NOT WIRE** (Internal PCB SPI Bus) |
| **Pin 11** | `F_GPIO15` | **Pin 6** | *ESP32 SPI_MISO (GPIO 13)* | **DO NOT WIRE** (Internal PCB SPI Bus) |
| **Pin 12** | `F_GPIO14` | **Pin 5** | *ESP32 SPI_MOSI (GPIO 11)* | **DO NOT WIRE** (Internal PCB SPI Bus) |

> [!WARNING]
> PMOD pins 9 through 12 are hardwired on the PCB to the ESP32-to-FPGA SPI communication bus. Do not connect external wires to PMOD pins 9..12.

---

## 4. Pre-Power Connection Checklist

Before flipping the master power switch:
- [ ] **Battery Polarity**: Red to fuse/switch input, black to star ground.
- [ ] **Buck Voltage Verification**: Measure 5.0V output with a multimeter before connecting to Shrike-Fi 5V pin or servo leads ($5.0\,\text{V} \pm 0.1\,\text{V}$).
- [ ] **Common Ground**: Measure continuity ($0\,\Omega$) between battery negative, buck ground, Shrike-Fi GND, and servo grounds.
- [ ] **PMOD Pins 9..12**: Confirm no wires or jumpers are plugged into PMOD pins 9 through 12.
- [ ] **Sensors Sourced from 3.3V**: Confirm sensor VCC connects to the Shrike-Fi 3.3V rail (NOT 5V).
- [ ] **Wheels Elevated**: Ensure robot wheels are raised off the desk for initial boot tests.
