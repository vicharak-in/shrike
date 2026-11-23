#include "sensors.h"

SensorArray::SensorArray(bool active_high) {
    _polarity_active_high = active_high;
    _last_raw_byte = 0x00;
    _normalized_byte = 0x00;

    _pin_map[0] = PIN_SENSOR_0; // Far Right
    _pin_map[1] = PIN_SENSOR_1;
    _pin_map[2] = PIN_SENSOR_2;
    _pin_map[3] = PIN_SENSOR_3;
    _pin_map[4] = PIN_SENSOR_4;
    _pin_map[5] = PIN_SENSOR_5;
    _pin_map[6] = PIN_SENSOR_6;
    _pin_map[7] = PIN_SENSOR_7; // Far Left
}

void SensorArray::begin() {
    for (int i = 0; i < 8; i++) {
        pinMode(_pin_map[i], INPUT_PULLUP);
    }
}

uint8_t SensorArray::read() {
    uint8_t raw = 0x00;
    for (int i = 0; i < 8; i++) {
        if (digitalRead(_pin_map[i]) == HIGH) {
            raw |= (1 << i);
        }
    }
    _last_raw_byte = raw;

    // Normalize polarity so 1 = Black Line detected
    if (_polarity_active_high) {
        _normalized_byte = raw;
    } else {
        _normalized_byte = ~raw;
    }

    return _normalized_byte;
}

void SensorArray::setPolarity(bool active_high) {
    _polarity_active_high = active_high;
}
