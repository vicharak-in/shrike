/**
 * Example: Uart_Sum with Shrike FPGA + RP2040
 *
 * This sketch demonstrates how to:
 *  - Load a uart_sum bitstream into the Shrike FPGA
 *  - Read transmitted data by fpga on an RP2040 pin
 *  - Print the results of sum of numbers over Serial Monitor
 *
 * Hardware mapping (from Shrike pinouts):
 *  - reset → FPGA PIN3 → RP2040 GPIO 2 (design reset not the fpga reset)
 *  - Tx (fpga Tx) → FPGA PIN4 → RP2040(Rx) GPIO 1
 *  - Rx (fpga Rx) → FPGA PIN6 → RP2040(Tx) GPIO 0
 *
 */
 
#include <Shrike.h>

// -----------------------------------------------------------------------------
// Bitstream configuration
// -----------------------------------------------------------------------------

/**
 * Path to the FPGA bitstream.
 *
 * Make sure:
 *  - The file is present in your project / filesystem
 *  - The path matches your environment
 */
 
ShrikeFlash shrike;

#define BITSTREAM "/uart_sum.bin"

/* -  Reset Pin for uart_sum design. (Not to reset overall fpga)
   - reset → FPGA PIN3 → RP2040 GPIO 2 (design reset not the fpga reset) */
   
#define FPGA_RST 2

constexpr uint32_t UART_BAUD = 115200; // Baudrate for uart transactions

int readReplyByte(unsigned long timeoutMs);

void setup() {
  Serial.begin(115200);
  while (!Serial) {}

  /*  Initialize and Hold FPGA pin in reset
   *  Flash the uart_sum bitstream into the Fpga
   */
   
  pinMode(FPGA_RST, OUTPUT);
  shrike.begin();
  shrike.flash(BITSTREAM);
  delay(100);

  // 🔥 Release FPGA from reset (CRITICAL FIX)
  digitalWrite(FPGA_RST, HIGH);
  digitalWrite(FPGA_RST, LOW);
  delay(200);

  // Setup UART
  Serial1.setTX(0);
  Serial1.setRX(1);
  Serial1.begin(UART_BAUD);

  delay(50);

  // Clear UART buffer
  while (Serial1.available() > 0) {
    Serial1.read();
  }

  Serial.println("FPGA UART sum auto test ready.");
}

void loop() {
  static uint8_t value = 1;

  uint8_t a = value;
  uint8_t b = value + 1;

  // Clear any old data
  while (Serial1.available() > 0) {
    Serial1.read();
  }

  // Send bytes with small delay
  Serial1.write(a);
  delay(5);
  Serial1.write(b);


  int reply = readReplyByte(1000);

  if (reply < 0) {
    Serial.println("Timeout waiting for FPGA response.");
  } else {
    Serial.print(a);
    Serial.print(" + ");
    Serial.print(b);
    Serial.print(" = ");
    Serial.println((uint8_t)reply);
  }

  value++;
  delay(2000);
}

int readReplyByte(unsigned long timeoutMs) {
  unsigned long startTime = millis();

  while (millis() - startTime <= timeoutMs) {
    if (Serial1.available() > 0) {
      return Serial1.read();
    }
    delay(1);
  }

  return -1;
}
