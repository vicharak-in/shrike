# Build & Flash Guide

Instructions for running HDL simulation, generating ForgeFPGA bitstreams in Renesas Go Configure Hub, compiling the ESP32-S3 firmware, flashing over USB, and tuning over the serial console.

---

## 1. Quick Start: One-Click Build & Regression

From the repository root:

```powershell
# 1. Run all unit tests, Verilator static lint, Yosys elaboration, and Python models
powershell -ExecutionPolicy Bypass -File .\scripts\test-all.ps1

# 2. Run standalone Icarus Verilog hardware simulation (89.1 ms testbench)
iverilog -o sim.vvp ffpga/sim/tb_pid_top.v ffpga/src/pid_top.v
vvp sim.vvp
```

---

## 2. Renesas Go Configure Software Hub Workflow (FPGA Synthesis & PnR)

The repository includes the complete project configuration for the Renesas ForgeFPGA SLG47910.

1. Launch **Go Configure Software Hub**:
   `C:\Program Files\Renesas Electronics\Go Configure Software Hub\GP6.exe`
2. Open the project:
   `File` &rarr; `Open Project` &rarr; browse to `Go/Shriketracerunner/Shriketracerunner.ffpga`.
3. The project includes all I/O pin mappings:
   - `clk` $\to$ `OSC_CLK`
   - `clk_en` $\to$ `OSC_EN`
   - `spi_sck` $\to$ `Pin 3` (SPI_SCLK)
   - `spi_ss_n` $\to$ `Pin 4` (SPI_SS)
   - `spi_mosi` $\to$ `Pin 5` (SPI_SI)
   - `spi_miso` $\to$ `Pin 6` (SPI_SO)
   - `spi_miso_en` $\to$ `Pin 6_OE`
   - `pwm_left_out` $\to$ `Pin 24` (PMOD J5 Pin 5)
   - `pwm_left_oe` $\to$ `Pin 24_OE`
   - `pwm_right_out` $\to$ `Pin 23` (PMOD J5 Pin 6)
   - `pwm_right_oe` $\to$ `Pin 23_OE`
   - `motor_en_out` $\to$ `Pin 2` (PMOD J5 Pin 7)
   - `motor_en_oe` $\to$ `Pin 2_OE`
   - `led` $\to$ `Pin 16`
   - `led_en` $\to$ `Pin 16_OE`
4. Click **Synthesize** &rarr; **Generate Bitstream** (or Place-and-Route tool).
5. The output bitstream is produced at `Go/Shriketracerunner/ffpga/build/bitstream/FPGA_bitstream_MCU.bin` (46,408 bytes).
6. Convert the `.bin` into the C header array for the ESP32:
   ```powershell
   python -c "b = open('Go/Shriketracerunner/ffpga/build/bitstream/FPGA_bitstream_MCU.bin','rb').read(); open('firmware/shrike_line_follower/pid_bitstream.h','w').write(f'#pragma once\n#define PID_BITSTREAM_SIZE {len(b)}\nconst uint8_t pid_bitstream[PID_BITSTREAM_SIZE] PROGMEM = {{' + ','.join(hex(x) for x in b) + '};\n'); print(f'Successfully packed {len(b)} bytes into pid_bitstream.h!')"
   ```

---

## 3. Compiling & Flashing ESP32-S3 Firmware

Connect the Shrike-Fi board to your PC via USB-C.

```powershell
# 1. Identify active COM port
python -m serial.tools.list_ports

# 2. Compile sketch
arduino-cli compile --fqbn esp32:esp32:esp32s3 firmware/shrike_line_follower/shrike_line_follower.ino

# 3. Upload to board (replace COM14 with your active COM port)
arduino-cli upload -p COM14 --fqbn esp32:esp32:esp32s3 firmware/shrike_line_follower/shrike_line_follower.ino
```

---

## 4. Interactive Serial Console & Calibration

Open the Serial Monitor at **115200 baud** (`python -m serial.tools.miniterm <COM_PORT> 115200`):

### Bench Commissioning (Wheels Off Ground):
1. **Boot Banner**:
   ```text
   [BOOT] Streaming 46408 bytes to ForgeFPGA...
   [BOOT] ForgeFPGA successfully configured and running!
   ```
2. **Sensor Check**:
   - Slide a strip of black electrical tape under the sensor bar.
   - Observe live ASCII readout: `Sensors: [..##....] | Err:  0`.
   - Deviate tape left: `Err: -4` to `-7`.
   - Deviate tape right: `Err: +4` to `+7`.
3. **Differential Wheel Response**:
   - Type `arm`.
   - Center line: Both continuous rotation servos spin forward at equal speed.
   - Line to the left: Left servo speeds up, right servo slows down (steers right).
   - Line to the right: Right servo speeds up, left servo slows down (steers left).
   - Type `disarm`: Both servos immediately stop with zero creep/jitter.
4. **Continuous Servo Neutral Calibration**:
   - If a servo slowly creeps when disarmed or when stopped (`base_speed = 0`), adjust the mechanical zero-point trimpot on the back/bottom of the 9g servo casing using a small screwdriver until rotation completely halts at the 1500 $\mu$s neutral pulse.

---

## 5. Live Track Tuning Commands

| Command | Description | Example |
| :--- | :--- | :--- |
| `arm` | Enable motors and start tracking | `arm` |
| `disarm` | Silence servo pulses and stop robot | `disarm` |
| `speed <val>` | Set base cruise speed (range: `50`–`200`) | `speed 80` |
| `kp <val>` | Set proportional gain | `kp 4` |
| `ki <val>` | Set integral gain | `ki 1` |
| `kd <val>` | Set derivative gain | `kd 2` |
| `telemetry` | Toggle live 10 Hz telemetry streaming | `telemetry` |
| `status` | Print current system gains, speed, and status | `status` |
