#include "fpga_interface.h"

FpgaInterface::FpgaInterface() 
    : _spi_flash_settings(2000000, MSBFIRST, SPI_MODE0),
      _spi_comm_settings(2000000, MSBFIRST, SPI_MODE0)
{
    _spi = &SPI;
    _last_valid_time_ms = 0;
    _is_configured = false;
    _last_heartbeat = false;
    _kp = 4;
    _ki = 0;
    _kd = 2;
}

bool FpgaInterface::begin() {
    pinMode(PIN_FPGA_EN, OUTPUT);
    pinMode(PIN_FPGA_PWR, OUTPUT);
    pinMode(PIN_FPGA_SS, OUTPUT);
    pinMode(PIN_FPGA_SCK, OUTPUT);
    pinMode(PIN_FPGA_MOSI, OUTPUT);
    pinMode(PIN_FPGA_MISO, INPUT);

    digitalWrite(PIN_FPGA_SS, HIGH);
    digitalWrite(PIN_FPGA_EN, LOW);
    digitalWrite(PIN_FPGA_PWR, LOW);

    _spi->begin(PIN_FPGA_SCK, PIN_FPGA_MISO, PIN_FPGA_MOSI, PIN_FPGA_SS);
    return true;
}

bool FpgaInterface::configureFromProgmem(const uint8_t* bitstream_data, size_t bitstream_len) {
    if (!bitstream_data || bitstream_len != 46408) {
        Serial.printf("[FPGA] Invalid bitstream size: %u (expected 46408)\n", (unsigned int)bitstream_len);
        return false;
    }

    Serial.println("[FPGA] Resetting ForgeFPGA core...");
    digitalWrite(PIN_FPGA_SS, LOW);
    digitalWrite(PIN_FPGA_EN, LOW);
    digitalWrite(PIN_FPGA_PWR, LOW);
    delay(100);

    digitalWrite(PIN_FPGA_PWR, HIGH);
    digitalWrite(PIN_FPGA_EN, HIGH);
    delay(100);

    Serial.println("[FPGA] Streaming 46,408 bytes of PID bitstream into SRAM...");
    digitalWrite(PIN_FPGA_SS, HIGH);
    delayMicroseconds(2000);
    digitalWrite(PIN_FPGA_SS, LOW);

    _spi->beginTransaction(_spi_flash_settings);
    uint32_t t0 = millis();

    for (size_t i = 0; i < bitstream_len; i++) {
        uint8_t byte_val = pgm_read_byte(&bitstream_data[i]);
        _spi->transfer(byte_val);
    }

    _spi->endTransaction();
    uint32_t elapsed = millis() - t0;

    // Pull SS HIGH to transition ForgeFPGA into User Logic mode
    digitalWrite(PIN_FPGA_SS, HIGH);
    delay(50);

    Serial.printf("[FPGA] Programming complete in %u ms. Active in USER LOGIC mode!\n", elapsed);
    _is_configured = true;
    _last_valid_time_ms = millis();
    return true;
}

bool FpgaInterface::exchangeControl(uint8_t cmd, uint8_t sensor_byte, uint8_t base_speed, FpgaResponse& resp) {
    if (!_is_configured) return false;

    uint8_t parity_out = cmd ^ sensor_byte ^ base_speed;

    digitalWrite(PIN_FPGA_SS, LOW);
    delayMicroseconds(5);

    _spi->beginTransaction(_spi_comm_settings);
    uint8_t rx_status = _spi->transfer(cmd);
    uint8_t rx_pwml   = _spi->transfer(sensor_byte);
    uint8_t rx_pwmr   = _spi->transfer(base_speed);
    uint8_t rx_err    = _spi->transfer(parity_out);
    _spi->endTransaction();

    delayMicroseconds(5);
    digitalWrite(PIN_FPGA_SS, HIGH);

    resp.status       = rx_status;
    resp.pwm_left     = rx_pwml;
    resp.pwm_right    = rx_pwmr;
    resp.line_error   = (int8_t)rx_err;

    resp.heartbeat    = (rx_status & 0x80) != 0;
    resp.line_lost    = (rx_status & 0x40) != 0;
    resp.inter_sat    = (rx_status & 0x20) != 0;
    resp.steer_sat    = (rx_status & 0x10) != 0;
    resp.parity_error = (rx_status & 0x08) != 0;
    resp.last_dir     = (rx_status & 0x04) != 0;

    if (!resp.parity_error) {
        _last_valid_time_ms = millis();
        _last_heartbeat = resp.heartbeat;
        return true;
    }

    return false;
}

bool FpgaInterface::setKp(uint8_t kp) {
    _kp = kp;
    FpgaResponse dummy;
    return exchangeControl(0x20, kp, 0, dummy);
}

bool FpgaInterface::setKi(uint8_t ki) {
    _ki = ki;
    FpgaResponse dummy;
    return exchangeControl(0x21, ki, 0, dummy);
}

bool FpgaInterface::setKd(uint8_t kd) {
    _kd = kd;
    FpgaResponse dummy;
    return exchangeControl(0x22, kd, 0, dummy);
}

bool FpgaInterface::resetPID() {
    _kp = 4;
    _ki = 0;
    _kd = 2;
    FpgaResponse dummy;
    return exchangeControl(0xFF, 0, 0, dummy);
}

bool FpgaInterface::isResponsive(uint32_t timeout_ms) const {
    if (!_is_configured) return false;
    return (millis() - _last_valid_time_ms) < timeout_ms;
}
