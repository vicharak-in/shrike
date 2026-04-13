# Shrike Examples — Difficulty Reference

🟢 Beginner &nbsp;&nbsp; 🟡 Intermediate &nbsp;&nbsp; 🔴 Advanced

| # | Example | Folder Name | Category | Difficulty | Why |
|---|---------|-------------|----------|------------|-----|
| 1 | LED Blink | `led_blink` | Getting Started | 🟢 Beginner | Single output signal, no state |
| 2 | Breathing LED | `breathing_led` | Getting Started | 🟢 Beginner | Simple PWM counter, single module |
| 3 | Button Debouncer | `button_debouncer` | Getting Started | 🟢 Beginner | Basic FSM, introduces synchronous logic |
| 4 | LED PMOD | `pmod_led_blink` | GPIO & I/O | 🟢 Beginner | Direct pin drive, PMOD pinout awareness |
| 5 | Logic Gates | `logic_gates` | Digital Logic | 🟢 Beginner | Pure combinational, no clock needed |
| 6 | 4-Bit Counter | `counter_4bit` | Signal & Timing | 🟢 Beginner | Sequential logic, introduces registers |
| 7 | PMOD Patterns | `pmod_patterns` | GPIO & I/O | 🟡 Intermediate | Sequenced output, simple state machine |
| 8 | GPIO Extender 8-Pin | `gpio_extender_8pin` | GPIO & I/O | 🟡 Intermediate | FPGA-to-RP2040 IO bridge, bus awareness |
| 9 | GPIO Extender 14-Pin | `gpio_extender_14pin` | GPIO & I/O | 🟡 Intermediate | FPGA-to-RP2040 IO bridge, wider bus |
| 10 | I2C LED | `i2c_led` | Communication Protocols | 🟡 Intermediate | I2C state machine, clock stretching awareness |
| 11 | SPI Loopback LED | `spi_loopback_led` | Communication Protocols | 🟡 Intermediate | SPI shift register, MISO/MOSI routing |
| 12 | UART LED | `uart_led` | Communication Protocols | 🟡 Intermediate | UART RX framing, baud clock generation |
| 13 | UART ALU | `uart_alu` | Communication Protocols | 🟡 Intermediate | UART + datapath, multi-module design |
| 14 | PLL Oscillator | `pll_oscillator` | Signal & Timing | 🟡 Intermediate | PLL primitive instantiation, clock domain |
| 15 | PWM 4-Channel | `pwm_4ch` | Signal & Timing | 🟡 Intermediate | Multi-channel counter, duty cycle control |
| 16 | 7-Segment Display Clock | `seven_seg_clock` | Signal & Timing | 🟡 Intermediate | BCD conversion, multiplexed display drive |
| 17 | Ultrasonic Sensor | `ultrasonic_sensor` | Sensors & Peripherals | 🟡 Intermediate | Pulse timing, echo measurement FSM |
| 18 | WS2812 LED | `ws2812_led` | Sensors & Peripherals | 🟡 Intermediate | Precise bit-bang timing, serial protocol |
| 19 | ASK Modulator | `ask_modulator` | Signal & Timing | 🔴 Advanced | RF modulation concepts, carrier + data mixing |
| 20 | Stack Processor | `stack_processor` | Processors & CPUs | 🔴 Advanced | Custom ISA, stack-based execution, SPI host |
| 21 | Vector-4 CPU | `vector4_cpu` | Processors & CPUs | 🔴 Advanced | Full 4-bit SAP CPU: ALU, PC, registers, decode |
| 22 | Vector-8 CPU | `vector8_cpu` | Processors & CPUs | 🔴 Advanced | Full 8-bit SAP CPU: wider datapath, more opcodes |

---

## Summary by Difficulty

| Difficulty | Count | Examples |
|------------|-------|---------|
| 🟢 Beginner | 6 | `led_blink`, `breathing_led`, `button_debouncer`, `pmod_led_blink`, `logic_gates`, `counter_4bit` |
| 🟡 Intermediate | 13 | `pmod_patterns`, `gpio_extender_8pin`, `gpio_extender_14pin`, `i2c_led`, `spi_loopback_led`, `uart_led`, `uart_alu`, `pll_oscillator`, `pwm_4ch`, `seven_seg_clock`, `ultrasonic_sensor`, `ws2812_led` |
| 🔴 Advanced | 3 | `ask_modulator`, `stack_processor`, `vector4_cpu`, `vector8_cpu` |

---
