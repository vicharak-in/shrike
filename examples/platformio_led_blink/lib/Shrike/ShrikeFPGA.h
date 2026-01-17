#pragma once
#include <Arduino.h>
#include <SPI.h>
#include <cstdarg>
#include <cstdio>

// Default Pins 
#ifndef FPGA_PWR_PIN
#define FPGA_PWR_PIN   12
#endif

#ifndef FPGA_EN_PIN
#define FPGA_EN_PIN    13
#endif

#ifndef FPGA_RESET_PIN
#define FPGA_RESET_PIN 14
#endif

#ifndef SPI_SCK_PIN
#define SPI_SCK_PIN    2
#endif

#ifndef SPI_TX_PIN
#define SPI_TX_PIN     3
#endif

#ifndef SPI_RX_PIN
#define SPI_RX_PIN     0
#endif

#ifndef SPI_CS_PIN
#define SPI_CS_PIN     1
#endif

class ShrikeFPGA {
public:
  // Constructor (optional pin override)
  ShrikeFPGA(uint8_t fpgaPwr = FPGA_PWR_PIN,
             uint8_t fpgaEn = FPGA_EN_PIN,
             uint8_t fpgaReset = FPGA_RESET_PIN,
             uint8_t sck = SPI_SCK_PIN,
             uint8_t tx = SPI_TX_PIN,
             uint8_t rx = SPI_RX_PIN,
             uint8_t cs = SPI_CS_PIN);

  bool initShrike();

private:
  uint8_t _fpgaPwr, _fpgaEn, _fpgaReset;
  uint8_t _sck, _tx, _rx, _cs;
  SPISettings _spiSettings;
};

void parseAndPrint(const char *format, ...);