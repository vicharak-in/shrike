#ifndef FPGA_INTERFACE_H
#define FPGA_INTERFACE_H

#include <Arduino.h>
#include <SPI.h>
#include "config.h"

struct FpgaResponse {
    uint8_t status;
    uint8_t pwm_left;
    uint8_t pwm_right;
    int8_t  line_error;
    bool    heartbeat;
    bool    line_lost;
    bool    inter_sat;
    bool    steer_sat;
    bool    parity_error;
    bool    last_dir;
};

class FpgaInterface {
private:
    SPIClass*   _spi;
    SPISettings _spi_flash_settings;
    SPISettings _spi_comm_settings;
    uint32_t    _last_valid_time_ms;
    bool        _is_configured;
    bool        _last_heartbeat;
    uint8_t     _kp;
    uint8_t     _ki;
    uint8_t     _kd;

public:
    FpgaInterface();
    bool begin();
    bool configureFromProgmem(const uint8_t* bitstream_data, size_t bitstream_len);
    bool exchangeControl(uint8_t cmd, uint8_t sensor_byte, uint8_t base_speed, FpgaResponse& resp);

    // Dynamic Parameter Configuration
    bool setKp(uint8_t kp);
    bool setKi(uint8_t ki);
    bool setKd(uint8_t kd);
    bool resetPID();

    uint8_t getKp() const { return _kp; }
    uint8_t getKi() const { return _ki; }
    uint8_t getKd() const { return _kd; }

    bool isConfigured() const { return _is_configured; }
    bool isResponsive(uint32_t timeout_ms = WATCHDOG_TIMEOUT_MS) const;
};

#endif // FPGA_INTERFACE_H
