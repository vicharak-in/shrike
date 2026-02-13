#include "ShrikeFPGA.h"

ShrikeFPGA::ShrikeFPGA(uint8_t fpgaPwr, uint8_t fpgaEn, uint8_t fpgaReset,
                       uint8_t sck, uint8_t tx, uint8_t rx, uint8_t cs)
    : _fpgaPwr(fpgaPwr), _fpgaEn(fpgaEn), _fpgaReset(fpgaReset),
      _sck(sck), _tx(tx), _rx(rx), _cs(cs),
      _spiSettings(2000000, MSBFIRST, SPI_MODE0) {}

bool ShrikeFPGA::initShrike()
{
  Serial.println("\n[ ShrikeFPGA Init ]");

  pinMode(_fpgaPwr, OUTPUT);
  pinMode(_fpgaEn, OUTPUT);
  pinMode(_fpgaReset, OUTPUT);

  digitalWrite(_fpgaPwr, HIGH);
  delay(10);
  digitalWrite(_fpgaEn, HIGH);
  delay(10);

  digitalWrite(_fpgaReset, LOW);
  delay(20);
  digitalWrite(_fpgaReset, HIGH);
  delay(50);

  return true;
}

void parseAndPrint(const char *format, ...)
{
  static char parsed[1000];
  va_list args;
  va_start(args, format);
  vsnprintf(parsed, sizeof(parsed), format, args);
  va_end(args);
  Serial.println(parsed);
}
