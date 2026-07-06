// arduino_spi_master.ino -- Sends counter bytes continuously to FPGA.

#include <SPI.h>

const int SS_PIN = 10;
const uint8_t data[] = {0xA3, 0x7F, 0x1B, 0xE4, 0x55,
                        0x90, 0x3D, 0xC8, 0x06, 0xFA};
const int DATA_COUNT = 10;

void setup() {
  Serial.begin(115200);
  while (!Serial)
    ;

  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV16);
  SPI.setDataMode(SPI_MODE0);
  SPI.setBitOrder(MSBFIRST);

  pinMode(SS_PIN, OUTPUT);
  digitalWrite(SS_PIN, HIGH);

  Serial.println("Sending 10 bytes to FPGA...");

  for (int i = 0; i < DATA_COUNT; i++) {
    digitalWrite(SS_PIN, LOW);
    SPI.transfer(data[i]);
    digitalWrite(SS_PIN, HIGH);

    Serial.print("Sent: 0x");
    if (data[i] < 0x10)
      Serial.print("0");
    Serial.println(data[i], HEX);

    delay(500);
  }

  Serial.println("Done!");
}

void loop() {}