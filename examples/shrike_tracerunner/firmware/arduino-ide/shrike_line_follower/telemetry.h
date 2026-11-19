#ifndef TELEMETRY_H
#define TELEMETRY_H

#include <Arduino.h>
#include "config.h"
#include "fpga_interface.h"
#include "motors.h"
#include "sensors.h"

class Telemetry {
private:
    uint32_t _last_telemetry_time;
    bool     _csv_mode;

public:
    Telemetry();
    void begin();
    void update(uint32_t now_ms, uint8_t sensor_byte, const FpgaResponse& fpga_resp, const MotorDriver& motors);
    void handleSerialCommands(FpgaInterface& fpga, MotorDriver& motors, SensorArray& sensors, uint8_t& base_speed);
    void printHelp();
};

#endif // TELEMETRY_H
