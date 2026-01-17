#include <Arduino.h>
#include <ShrikeFPGA.h>
#include <stdlib.h>
#include <stdio.h>

ShrikeFPGA shrike;

void setup()
{
  delay(20000); // wait for 20 seconds to allow Serial Monitor connection for complete logs reading.
  Serial.begin(115200);
  Serial.println("Starting up...");
  pinMode(FPGA_PWR_PIN, OUTPUT);
}

// the loop routine runs over and over again forever:
void loop()
{
  static uint8_t i = 0;
  parseAndPrint("Blinking FPGA Power LED - %d", i++);
  digitalWrite(FPGA_PWR_PIN, HIGH); // turn the LED on (HIGH is the voltage level)
  delay(100);                       // wait for a second
  digitalWrite(FPGA_PWR_PIN, LOW);  // turn the LED off by making the voltage LOW
  delay(100);                       // wait for a second
}
