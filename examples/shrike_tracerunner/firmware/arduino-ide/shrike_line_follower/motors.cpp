#include "motors.h"

MotorDriver::MotorDriver() {
    _cur_left_pwm  = 0;
    _cur_right_pwm = 0;
    _is_armed      = false;
}

void MotorDriver::begin() {
    // Direction pins
    pinMode(PIN_MOTOR_L_IN1, OUTPUT);
    pinMode(PIN_MOTOR_L_IN2, OUTPUT);
    pinMode(PIN_MOTOR_R_IN3, OUTPUT);
    pinMode(PIN_MOTOR_R_IN4, OUTPUT);

    // Initial safe state: all pins LOW
    digitalWrite(PIN_MOTOR_L_IN1, LOW);
    digitalWrite(PIN_MOTOR_L_IN2, LOW);
    digitalWrite(PIN_MOTOR_R_IN3, LOW);
    digitalWrite(PIN_MOTOR_R_IN4, LOW);

    // Attach hardware PWM on enable pins using ESP32 Arduino Core 3.x API
    ledcAttach(PIN_MOTOR_L_ENA, MOTOR_PWM_FREQ_HZ, MOTOR_PWM_RESOLUTION);
    ledcAttach(PIN_MOTOR_R_ENB, MOTOR_PWM_FREQ_HZ, MOTOR_PWM_RESOLUTION);

    emergencyStop();
}

void MotorDriver::applyPwm(uint8_t pin_en, uint8_t pin_in1, uint8_t pin_in2, int16_t duty) {
    if (!_is_armed || duty == 0) {
        digitalWrite(pin_in1, LOW);
        digitalWrite(pin_in2, LOW);
        ledcWrite(pin_en, 0);
        return;
    }

    if (duty > 0) {
        // Forward drive
        digitalWrite(pin_in1, HIGH);
        digitalWrite(pin_in2, LOW);
        ledcWrite(pin_en, (uint32_t)constrain(duty, 0, MAX_ALLOWED_SPEED));
    } else {
        // Reverse drive (for extreme pivot maneuvers)
        digitalWrite(pin_in1, LOW);
        digitalWrite(pin_in2, HIGH);
        ledcWrite(pin_en, (uint32_t)constrain(-duty, 0, MAX_ALLOWED_SPEED));
    }
}

void MotorDriver::setOutputs(uint8_t left_duty, uint8_t right_duty) {
    if (!_is_armed) {
        emergencyStop();
        return;
    }

    // Apply slew rate limiting to prevent high inrush current
    int16_t target_l = constrain(left_duty, 0, MAX_ALLOWED_SPEED);
    int16_t target_r = constrain(right_duty, 0, MAX_ALLOWED_SPEED);

    int16_t diff_l = target_l - _cur_left_pwm;
    if (abs(diff_l) > MOTOR_SLEW_LIMIT) {
        _cur_left_pwm += (diff_l > 0) ? MOTOR_SLEW_LIMIT : -MOTOR_SLEW_LIMIT;
    } else {
        _cur_left_pwm = target_l;
    }

    int16_t diff_r = target_r - _cur_right_pwm;
    if (abs(diff_r) > MOTOR_SLEW_LIMIT) {
        _cur_right_pwm += (diff_r > 0) ? MOTOR_SLEW_LIMIT : -MOTOR_SLEW_LIMIT;
    } else {
        _cur_right_pwm = target_r;
    }

    applyPwm(PIN_MOTOR_L_ENA, PIN_MOTOR_L_IN1, PIN_MOTOR_L_IN2, _cur_left_pwm);
    applyPwm(PIN_MOTOR_R_ENB, PIN_MOTOR_R_IN3, PIN_MOTOR_R_IN4, _cur_right_pwm);
}

void MotorDriver::emergencyStop() {
    _cur_left_pwm  = 0;
    _cur_right_pwm = 0;
    digitalWrite(PIN_MOTOR_L_IN1, LOW);
    digitalWrite(PIN_MOTOR_L_IN2, LOW);
    digitalWrite(PIN_MOTOR_R_IN3, LOW);
    digitalWrite(PIN_MOTOR_R_IN4, LOW);
    ledcWrite(PIN_MOTOR_L_ENA, 0);
    ledcWrite(PIN_MOTOR_R_ENB, 0);
}

void MotorDriver::arm() {
    _is_armed = true;
}

void MotorDriver::disarm() {
    _is_armed = false;
    emergencyStop();
}
