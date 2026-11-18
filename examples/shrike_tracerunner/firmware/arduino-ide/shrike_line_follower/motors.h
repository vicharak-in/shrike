#ifndef MOTORS_H
#define MOTORS_H

#include <Arduino.h>
#include "config.h"

class MotorDriver {
private:
    int16_t _cur_left_pwm;
    int16_t _cur_right_pwm;
    bool    _is_armed;

    void applyPwm(uint8_t pin_en, uint8_t pin_in1, uint8_t pin_in2, int16_t duty);

public:
    MotorDriver();
    void begin();
    void setOutputs(uint8_t left_duty, uint8_t right_duty);
    void emergencyStop();
    void arm();
    void disarm();
    bool isArmed() const { return _is_armed; }
    int16_t getLeftPwm() const { return _cur_left_pwm; }
    int16_t getRightPwm() const { return _cur_right_pwm; }
};

#endif // MOTORS_H
