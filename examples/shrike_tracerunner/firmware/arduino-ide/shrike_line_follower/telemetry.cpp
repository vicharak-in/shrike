#include "telemetry.h"

Telemetry::Telemetry() {
    _last_telemetry_time = 0;
    _csv_mode = false;
}

void Telemetry::begin() {
    Serial.begin(TELEMETRY_BAUD_RATE);
    delay(200);
    Serial.println("\n========================================================");
    Serial.println(" Vicharak Shrike-Fi FPGA-Primary Line Follower Ready");
    Serial.println(" Type 'help' for runtime commands.");
    Serial.println("========================================================\n");
}

void Telemetry::update(uint32_t now_ms, uint8_t sensor_byte, const FpgaResponse& fpga_resp, const MotorDriver& motors) {
    if (now_ms - _last_telemetry_time < (1000 / TELEMETRY_RATE_HZ)) {
        return;
    }
    _last_telemetry_time = now_ms;

    if (_csv_mode) {
        // Format: Time,Sensors,Error,PWML,PWMR,Status
        Serial.printf("%lu,%u,%d,%u,%u,0x%02X\n",
                      now_ms, sensor_byte, fpga_resp.line_error,
                      fpga_resp.pwm_left, fpga_resp.pwm_right, fpga_resp.status);
    } else {
        // Interactive Human Display
        char sensor_str[9];
        for (int i = 7; i >= 0; i--) {
            sensor_str[7 - i] = (sensor_byte & (1 << i)) ? '#' : '.';
        }
        sensor_str[8] = '\0';

        Serial.printf("[%6lu ms] Sensors: [%s] | Err: %+2d | Motors: L=%3d R=%3d | Armed: %c | %s\n",
                      now_ms, sensor_str, fpga_resp.line_error,
                      motors.getLeftPwm(), motors.getRightPwm(),
                      motors.isArmed() ? 'Y' : 'N',
                      fpga_resp.line_lost ? "LOST" : "TRACK");
    }
}

void Telemetry::handleSerialCommands(FpgaInterface& fpga, MotorDriver& motors, SensorArray& sensors, uint8_t& base_speed) {
    if (!Serial.available()) return;

    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.length() == 0) return;

    if (cmd.equalsIgnoreCase("arm")) {
        motors.arm();
        Serial.println("[CMD] Robot ARMED. Motors ACTIVE.");
    } else if (cmd.equalsIgnoreCase("disarm") || cmd.equalsIgnoreCase("stop")) {
        motors.disarm();
        Serial.println("[CMD] Robot DISARMED. Motors STOPPED.");
    } else if (cmd.startsWith("speed ")) {
        int val = cmd.substring(6).toInt();
        base_speed = (uint8_t)constrain(val, 0, MAX_ALLOWED_SPEED);
        Serial.printf("[CMD] Base Speed set to %u\n", base_speed);
    } else if (cmd.startsWith("kp ")) {
        int val = cmd.substring(3).toInt();
        fpga.setKp((uint8_t)constrain(val, 0, 255));
        Serial.printf("[CMD] FPGA Kp set to %u\n", val);
    } else if (cmd.startsWith("ki ")) {
        int val = cmd.substring(3).toInt();
        fpga.setKi((uint8_t)constrain(val, 0, 255));
        Serial.printf("[CMD] FPGA Ki set to %u\n", val);
    } else if (cmd.startsWith("kd ")) {
        int val = cmd.substring(3).toInt();
        fpga.setKd((uint8_t)constrain(val, 0, 255));
        Serial.printf("[CMD] FPGA Kd set to %u\n", val);
    } else if (cmd.equalsIgnoreCase("reset")) {
        fpga.resetPID();
        Serial.println("[CMD] FPGA PID state reset to defaults.");
    } else if (cmd.equalsIgnoreCase("csv")) {
        _csv_mode = !_csv_mode;
        Serial.printf("[CMD] CSV Stream Mode: %s\n", _csv_mode ? "ON" : "OFF");
    } else if (cmd.equalsIgnoreCase("polarity")) {
        bool cur = SENSOR_ACTIVE_POLARITY_HIGH;
        sensors.setPolarity(!cur);
        Serial.println("[CMD] Sensor polarity toggled.");
    } else {
        printHelp();
    }
}

void Telemetry::printHelp() {
    Serial.println("\n--- Available Serial Commands ---");
    Serial.println("  arm          : Arm motors and start tracking");
    Serial.println("  stop/disarm  : Immediately stop motors");
    Serial.println("  speed <0-200>: Set base driving speed");
    Serial.println("  kp <0-255>   : Set FPGA Proportional Gain");
    Serial.println("  ki <0-255>   : Set FPGA Integral Gain");
    Serial.println("  kd <0-255>   : Set FPGA Derivative Gain");
    Serial.println("  reset        : Reset FPGA PID accumulator");
    Serial.println("  csv          : Toggle CSV streaming format");
    Serial.println("  polarity     : Toggle sensor active-high / active-low");
    Serial.println("---------------------------------\n");
}
