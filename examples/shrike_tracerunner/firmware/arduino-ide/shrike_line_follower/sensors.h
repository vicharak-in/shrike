#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>
#include "config.h"

class SensorArray {
private:
    uint8_t _pin_map[8];
    uint8_t _last_raw_byte;
    uint8_t _normalized_byte;
    bool    _polarity_active_high;

public:
    SensorArray(bool active_high = SENSOR_ACTIVE_POLARITY_HIGH);
    void begin();
    uint8_t read();
    uint8_t getLastByte() const { return _normalized_byte; }
    bool isAllWhite() const { return _normalized_byte == 0x00; }
    bool isAllBlack() const { return _normalized_byte == 0xFF; }
    void setPolarity(bool active_high);
};

#endif // SENSORS_H
