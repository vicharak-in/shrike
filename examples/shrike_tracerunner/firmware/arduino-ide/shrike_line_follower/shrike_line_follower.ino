/*
 * Shrike-Fi FPGA-Primary PID Line Follower
 * Hardware: Vicharak Shrike-Fi (ESP32-S3 + Renesas ForgeFPGA SLG47910)
 *
 * FPGA handles the real-time control math:
 *  - 8-sensor line centroid & position error calculation
 *  - Fixed-point PID arithmetic (Kp, Ki w/ anti-windup, Kd)
 *  - Motor speed mixing and recovery pivot when off-line
 *
 * ESP32-S3 handles:
 *  - Uploading FPGA bitstream on boot
 *  - Reading the 8 IR sensor pins
 *  - Driving L298N motor PWM via LEDC
 *  - Serial CLI for live PID tuning and telemetry
 */

#include <Arduino.h>
#include "config.h"
#include "pid_bitstream.h"
#include "sensors.h"
#include "motors.h"
#include "fpga_interface.h"
#include "telemetry.h"
#include "web_server_handler.h"

// System state machine
enum SystemState {
    STATE_BOOT,
    STATE_INIT_FPGA,
    STATE_CALIBRATE,
    STATE_ARMED,
    STATE_RUNNING,
    STATE_FAULT
};

// Global subsystems
SensorArray      sensors(SENSOR_ACTIVE_POLARITY_HIGH);
MotorDriver      motors;
FpgaInterface    fpga;
Telemetry        telemetry;
WebServerHandler webServer;

// Global control variables
SystemState   sys_state       = STATE_BOOT;
uint8_t       base_speed      = DEFAULT_BASE_SPEED;
uint32_t      last_loop_us    = 0;
uint32_t      line_lost_time  = 0;
bool          line_was_lost   = false;
FpgaResponse  last_fpga_resp;

void setup() {
    pinMode(PIN_MCU_LED, OUTPUT);
    digitalWrite(PIN_MCU_LED, LOW);

    // Initialize subsystems
    telemetry.begin();
    sensors.begin();
    motors.begin();
    fpga.begin();
    webServer.begin(&fpga, &motors, &sensors, &base_speed, &last_fpga_resp);

    Serial.println("[BOOT] Starting Vicharak Shrike-Fi System Initialization...");
    sys_state = STATE_INIT_FPGA;

    // Bootstrap FPGA with the 46,408-byte synthesized PID bitstream
    if (fpga.configureFromProgmem(pid_bitstream, PID_BITSTREAM_SIZE)) {
        Serial.println("[BOOT] ForgeFPGA successfully configured and running!");
        sys_state = STATE_CALIBRATE;
    } else {
        Serial.println("[BOOT] FATAL: FPGA bitstream upload failed! Entering FAULT state.");
        sys_state = STATE_FAULT;
    }

    // Calibration check (1 second debounce)
    delay(500);
    uint8_t initial_sensors = sensors.read();
    Serial.printf("[BOOT] Initial sensor reading: 0x%02X\n", initial_sensors);

    if (sys_state != STATE_FAULT) {
        sys_state = STATE_ARMED;
        Serial.println("[BOOT] System ARMED. Ready for line following!");
        digitalWrite(PIN_MCU_LED, HIGH);
    }
}

void loop() {
    uint32_t now_us = micros();
    uint32_t now_ms = millis();

    // -------------------------------------------------------------------------
    // 1. Process Serial Commands & Diagnostics (Non-Blocking)
    // -------------------------------------------------------------------------
    telemetry.handleSerialCommands(fpga, motors, sensors, base_speed);
    webServer.handleClient();

    // -------------------------------------------------------------------------
    // 2. Deterministic 1.0 kHz Control Loop (Every 1000 microseconds)
    // -------------------------------------------------------------------------
    if (now_us - last_loop_us >= CONTROL_LOOP_PERIOD_US) {
        last_loop_us = now_us;

        // Step A: Sample the 8 independent digital IR sensor inputs
        uint8_t sensor_byte = sensors.read();

        // Step B: Query the ForgeFPGA PID Control Engine via full-duplex SPI
        FpgaResponse resp;
        bool comm_ok = fpga.exchangeControl(0x10, sensor_byte, base_speed, resp);

        // Step C: Safety Watchdog & Communication Verification
        if (!comm_ok || !fpga.isResponsive(WATCHDOG_TIMEOUT_MS)) {
            motors.emergencyStop();
            digitalWrite(PIN_MCU_LED, LOW);
            if (sys_state != STATE_FAULT) {
                Serial.println("[SAFETY] WATCHDOG TRIP: FPGA communication loss! Emergency Stop activated.");
                sys_state = STATE_FAULT;
            }
            return;
        }

        last_fpga_resp = resp;

        // Step D: Line Loss Watchdog Check
        if (resp.line_lost) {
            if (!line_was_lost) {
                line_lost_time = now_ms;
                line_was_lost = true;
            } else if (now_ms - line_lost_time > LINE_LOSS_TIMEOUT_MS) {
                // Robot has been completely off the track for too long: STOP
                motors.disarm();
                Serial.println("[SAFETY] LINE LOSS TIMEOUT: Robot halted to prevent runaway.");
                line_was_lost = false;
            }
        } else {
            line_was_lost = false;
        }

        // Step E: Actuation (Apply FPGA-computed Left & Right PWM to Motors)
        if (motors.isArmed()) {
            motors.setOutputs(resp.pwm_left, resp.pwm_right);
        } else {
            motors.emergencyStop();
        }

        // Toggle MCU LED with FPGA Heartbeat to indicate lockstep operation
        digitalWrite(PIN_MCU_LED, resp.heartbeat ? HIGH : LOW);
    }

    // -------------------------------------------------------------------------
    // 3. Telemetry Broadcast (20 Hz)
    // -------------------------------------------------------------------------
    telemetry.update(now_ms, sensors.getLastByte(), last_fpga_resp, motors);
}
