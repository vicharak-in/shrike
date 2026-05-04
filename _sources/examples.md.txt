(examples)=

# Shrike Examples

🟢 Beginner &nbsp;&nbsp; 🟡 Intermediate &nbsp;&nbsp; 🔴 Advanced

| # | Example | Folder Name | Category | Difficulty | Why |
|---|---------|-------------|----------|------------|-----|
| 1 | [LED Blink](https://github.com/vicharak-in/shrike/tree/main/examples/led_blink) | `led_blink` | Getting Started | 🟢 Beginner | Single output signal, no state |
| 2 | [Breathing LED](https://github.com/vicharak-in/shrike/tree/main/examples/breathing_led) | `breathing_led` | Getting Started | 🟢 Beginner | Simple PWM counter, single module |
| 3 | [Button Debouncer](https://github.com/vicharak-in/shrike/tree/main/examples/button_debouncer) | `button_debouncer` | Getting Started | 🟢 Beginner | Basic FSM, introduces synchronous logic |
| 4 | [LED PMOD](https://github.com/vicharak-in/shrike/tree/main/examples/pmod_led_blink) | `pmod_led_blink` | GPIO & I/O | 🟢 Beginner | Direct pin drive, PMOD pinout awareness |
| 5 | [Logic Gates](https://github.com/vicharak-in/shrike/tree/main/examples/logic_gates) | `logic_gates` | Digital Logic | 🟢 Beginner | Pure combinational, no clock needed |
| 6 | [4-Bit Counter](https://github.com/vicharak-in/shrike/tree/main/examples/counter_4bit) | `counter_4bit` | Signal & Timing | 🟢 Beginner | Sequential logic, introduces registers |
| 7 | [PMOD Patterns](https://github.com/vicharak-in/shrike/tree/main/examples/pmod_patterns) | `pmod_patterns` | GPIO & I/O | 🟡 Intermediate | Sequenced output, simple state machine |
| 8 | [GPIO Extender 8-Pin](https://github.com/vicharak-in/shrike/tree/main/examples/gpio_extender_8pin) | `gpio_extender_8pin` | GPIO & I/O | 🟡 Intermediate | FPGA-to-RP2040 IO bridge, bus awareness |
| 9 | [GPIO Extender 14-Pin](https://github.com/vicharak-in/shrike/tree/main/examples/gpio_extender_14pin) | `gpio_extender_14pin` | GPIO & I/O | 🟡 Intermediate | FPGA-to-RP2040 IO bridge, wider bus |
| 10 | [I2C LED](https://github.com/vicharak-in/shrike/tree/main/examples/i2c_led) | `i2c_led` | Communication Protocols | 🟡 Intermediate | I2C state machine, clock stretching awareness |
| 11 | [SPI Loopback LED](https://github.com/vicharak-in/shrike/tree/main/examples/spi_loopback_led) | `spi_loopback_led` | Communication Protocols | 🟡 Intermediate | SPI shift register, MISO/MOSI routing |
| 12 | [UART LED](https://github.com/vicharak-in/shrike/tree/main/examples/uart_led) | `uart_led` | Communication Protocols | 🟡 Intermediate | UART RX framing, baud clock generation |
| 13 | [Morse Blink](https://github.com/vicharak-in/shrike/tree/main/examples/morse_blink) | `morse_blink` | Communication Protocols | 🟡 Intermediate | UART input, timing/state machine, serial-to-LED translation |
| 14 | [UART ALU](https://github.com/vicharak-in/shrike/tree/main/examples/uart_alu) | `uart_alu` | Communication Protocols | 🟡 Intermediate | UART + datapath, multi-module design |
| 15 | [PLL Oscillator](https://github.com/vicharak-in/shrike/tree/main/examples/pll_oscillator) | `pll_oscillator` | Signal & Timing | 🟡 Intermediate | PLL primitive instantiation, clock domain |
| 16 | [PWM 4-Channel](https://github.com/vicharak-in/shrike/tree/main/examples/pwm_4ch) | `pwm_4ch` | Signal & Timing | 🟡 Intermediate | Multi-channel counter, duty cycle control |
| 17 | [7-Segment Display Clock](https://github.com/vicharak-in/shrike/tree/main/examples/seven_seg_clock) | `seven_seg_clock` | Signal & Timing | 🟡 Intermediate | BCD conversion, multiplexed display drive |
| 18 | [Ultrasonic Sensor](https://github.com/vicharak-in/shrike/tree/main/examples/ultrasonic_sensor) | `ultrasonic_sensor` | Sensors & Peripherals | 🟡 Intermediate | Pulse timing, echo measurement FSM |
| 19 | [WS2812 LED](https://github.com/vicharak-in/shrike/tree/main/examples/ws2812_led) | `ws2812_led` | Sensors & Peripherals | 🟡 Intermediate | Precise bit-bang timing, serial protocol |
| 20 | [ASK Modulator](https://github.com/vicharak-in/shrike/tree/main/examples/ask_modulator) | `ask_modulator` | Signal & Timing | 🔴 Advanced | RF modulation concepts, carrier + data mixing |
| 21 | [Stack Processor](https://github.com/vicharak-in/shrike/tree/main/examples/stack_processor) | `stack_processor` | Processors & CPUs | 🔴 Advanced | Custom ISA, stack-based execution, SPI host |
| 22 | [Vector-4 CPU](https://github.com/vicharak-in/shrike/tree/main/examples/vector4_cpu) | `vector4_cpu` | Processors & CPUs | 🔴 Advanced | Full 4-bit SAP CPU: ALU, PC, registers, decode |
| 23 | [Vector-8 CPU](https://github.com/vicharak-in/shrike/tree/main/examples/vector8_cpu) | `vector8_cpu` | Processors & CPUs | 🔴 Advanced | Full 8-bit SAP CPU: wider datapath, more opcodes |

---

## Summary by Difficulty

| Difficulty | Count | Examples |
|------------|-------|---------|
| 🟢 Beginner | 6 | [`led_blink`](https://github.com/vicharak-in/shrike/tree/main/examples/led_blink), [`breathing_led`](https://github.com/vicharak-in/shrike/tree/main/examples/breathing_led), [`button_debouncer`](https://github.com/vicharak-in/shrike/tree/main/examples/button_debouncer), [`pmod_led_blink`](https://github.com/vicharak-in/shrike/tree/main/examples/pmod_led_blink), [`logic_gates`](https://github.com/vicharak-in/shrike/tree/main/examples/logic_gates), [`counter_4bit`](https://github.com/vicharak-in/shrike/tree/main/examples/counter_4bit) |
| 🟡 Intermediate | 13 | [`pmod_patterns`](https://github.com/vicharak-in/shrike/tree/main/examples/pmod_patterns), [`gpio_extender_8pin`](https://github.com/vicharak-in/shrike/tree/main/examples/gpio_extender_8pin), [`gpio_extender_14pin`](https://github.com/vicharak-in/shrike/tree/main/examples/gpio_extender_14pin), [`i2c_led`](https://github.com/vicharak-in/shrike/tree/main/examples/i2c_led), [`spi_loopback_led`](https://github.com/vicharak-in/shrike/tree/main/examples/spi_loopback_led), [`uart_led`](https://github.com/vicharak-in/shrike/tree/main/examples/uart_led), [`morse_blink`](https://github.com/vicharak-in/shrike/tree/main/examples/morse_blink), [`uart_alu`](https://github.com/vicharak-in/shrike/tree/main/examples/uart_alu), [`pll_oscillator`](https://github.com/vicharak-in/shrike/tree/main/examples/pll_oscillator), [`pwm_4ch`](https://github.com/vicharak-in/shrike/tree/main/examples/pwm_4ch), [`seven_seg_clock`](https://github.com/vicharak-in/shrike/tree/main/examples/seven_seg_clock), [`ultrasonic_sensor`](https://github.com/vicharak-in/shrike/tree/main/examples/ultrasonic_sensor), [`ws2812_led`](https://github.com/vicharak-in/shrike/tree/main/examples/ws2812_led) |
| 🔴 Advanced | 4 | [`ask_modulator`](https://github.com/vicharak-in/shrike/tree/main/examples/ask_modulator), [`stack_processor`](https://github.com/vicharak-in/shrike/tree/main/examples/stack_processor), [`vector4_cpu`](https://github.com/vicharak-in/shrike/tree/main/examples/vector4_cpu), [`vector8_cpu`](https://github.com/vicharak-in/shrike/tree/main/examples/vector8_cpu) |

---