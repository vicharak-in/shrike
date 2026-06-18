// usb_to_spi.ino -- Arduino Uno SPI slave for the USB-to-SPI bridge example.
//
// The FPGA is the SPI master and the Arduino Uno (ATmega328P) is the slave on
// this link. Each byte the FPGA clocks in is captured in the SPI interrupt,
// echoed back on MISO, and printed to the serial monitor so you can confirm the
// FPGA is mastering the bus and the data path is correct. SPI mode 0, MSB-first.
//
// Wiring (FPGA GPIO -> Uno pin):
//   m_sck=GPIO0 -> D13(SCK)   m_mosi=GPIO1 -> D11(MOSI)
//   m_miso=GPIO8 <- D12(MISO, via 5V->3.3V divider)   m_ss_n=GPIO7 -> D10(SS)
//   plus common GND. The Uno is 5V, so level-shift D12 down to 3.3V for the FPGA.

#define SERIAL_BAUD 115200

volatile uint8_t rxByte = 0x00;
volatile bool newData = false;

void setup() {
  Serial.begin(SERIAL_BAUD);
  Serial.println("Arduino SPI Slave starting...");

  // Configure SPI data direction for slave operation (platform-specific: AVR).
  pinMode(MISO, OUTPUT);
  pinMode(MOSI, INPUT);
  pinMode(SCK, INPUT);
  pinMode(SS, INPUT);

  // Enable SPI as slave with interrupt on transfer complete (AVR SPCR bits).
  SPCR = 0;
  SPCR |= (1 << SPE);   // SPI enable
  SPCR |= (1 << SPIE);  // SPI interrupt enable
  SPDR = 0x00;          // first byte presented on MISO

  Serial.println("Ready. Waiting for FPGA...");
}

// SPI transfer complete: latch the received byte and echo it back on MISO.
ISR(SPI_STC_vect) {
  rxByte = SPDR;
  SPDR = rxByte;
  newData = true;
}

void loop() {
  if (newData) {
    newData = false;
    Serial.print("Received: 0x");
    if (rxByte < 0x10) {
      Serial.print("0");
    }
    Serial.println(rxByte, HEX);
  }
}
