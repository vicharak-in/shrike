/**
 * Example: Quadrature Decoder on Shrike-Lite (FPGA + RP2040)
 *
 * This sketch demonstrates how to:
 *  - Load a quadrature_decoder bitstream into the Shrike FPGA
 *  - Read the UART packets come from FPGA (Tx) on an RP2040 Rx pin
 *  - Print the status of Position, Speed, Angle and Direction over Serial
 *
 * Hardware mapping (from Shrike pinouts):
 *  - FPGA PIN4 (Tx) → RP2040 GPIO 1 (Rx)
 *
 */

#include "Arduino.h"
#include "Shrike.h"

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
#define BITSTREAM "/quadrature_decoder.bin"

// -----------------------------------------------------------------------------
// Pin definition of UART Rx and Baudrate configuration
// -----------------------------------------------------------------------------

/**
 * UART_RX
 * ----------
 * This is the RP2040 pin that receives the UART packet from the FPGA Tx.
 * Baudrate can configure here. Baudrate should be same on both sides. 
 * (FPGA side and RP2040 side).
 * ----------
 */
#define RX_PIN 1
#define BAUDRATE 115200

// -----------------------------------------------------------------------------
// FPGA flashing
// -----------------------------------------------------------------------------

/**
 * ShrikeFlash
 * -----------
 * This object handles communication with the Shrike board's flash and FPGA.
 * We will:
 *  - Initialize it in setup()
 *  - Use it to flash (load) the quadrature_decoder bitstream into the FPGA
 */
ShrikeFlash shrike;

// -----------------------------------------------------------------------------
// FEATURE TOGGLE for Dummy Encoder signals
// -----------------------------------------------------------------------------
/**
 * Internal Encoder Test Mode
 * -----------
 * If you don't have encoder sensors, you can generate dummy signals
 * using RP2040 GPIO pins for testing the FPGA decoder.
 * Sets GPIO pins as outputs for dummy encoder signals :
 *     - 1 = internal encoder signal generator (for testing FPGA)
 *     - 0 = real encoder / external signals used
 * 
 */
#define USE_INTERNAL_ENCODER_TEST 1

// -----------------------------------------------------------------------------
// Pins definition of dummy encoder signals on shrike
// -----------------------------------------------------------------------------

/**
 * ENC_A_PIN and ENC_B_PIN
 * ----------
 * These are the RP2040 pins outputs the generated dummy signals.
 * ----------
 */
#define ENC_A_PIN 17
#define ENC_B_PIN 18

// -----------------------------------------------------------------------------
// Uart Packet Handling
// -----------------------------------------------------------------------------

/**
 * Fpga will send the packet of 8 bytes which is in the below format.
 * - [AA][pos MSB][pos LSB][spd MSB][spd LSB][ang MSB][ang LSB][dir]
 * 
 * AA  - Header, pos - Position (16bits), spd - Speed (16-bits)
 * ang - Angle (16-bits), dir - Direction (8-bits)
 *
 * The packet is decoded after receiving data from FPGA.
*/
uint8_t packet[8];
uint8_t idx = 0;
bool receiving = false;

// -----------------------------------------------------------------------------
// Timing counter used in Dummy encoder signals generation
// -----------------------------------------------------------------------------
unsigned long last_encoder_tick = 0;

// -----------------------------------------------------------------------------
//  ENCODER TEST MODE
// -----------------------------------------------------------------------------
/**
 * Creates quadrature waveform. They are 90° phase shifted.
 * The order of transitions determines direction :
 *     - 00 → 01 → 11 → 10 → repeat (Forward Rotation Pattern)
 *     - 00 → 10 → 11 → 01 → repeat (Reverse Rotation Pattern)
 * Simulates rotation and Feeds FPGA inputs
 * Generates the forward and reverse direction sequences
 * and that diresction will toggles for every 5 sec.
 * This is ONLY for testing FPGA without real encoder
 *
*/
#if USE_INTERNAL_ENCODER_TEST

uint8_t enc_state = 0;
bool direction = true;

void init_encoder_test() {
    pinMode(ENC_A_PIN, OUTPUT);
    pinMode(ENC_B_PIN, OUTPUT);
}

void generate_encoder() {

    // speed control (~500 Hz step rate)
    if (millis() - last_encoder_tick < 2) return;
    last_encoder_tick = millis();

    // optional direction toggle every ~5 sec
    if ((millis() / 5000) % 2 == 0)
        direction = true;
    else
        direction = false;

    if (direction) {
        switch (enc_state) {
            case 0: digitalWrite(ENC_A_PIN, LOW);  digitalWrite(ENC_B_PIN, LOW);  break;
            case 1: digitalWrite(ENC_A_PIN, HIGH); digitalWrite(ENC_B_PIN, LOW);  break;
            case 2: digitalWrite(ENC_A_PIN, HIGH); digitalWrite(ENC_B_PIN, HIGH); break;
            case 3: digitalWrite(ENC_A_PIN, LOW);  digitalWrite(ENC_B_PIN, HIGH); break;
        }
    } else {
        switch (enc_state) {
            case 0: digitalWrite(ENC_A_PIN, LOW);  digitalWrite(ENC_B_PIN, LOW);  break;
            case 1: digitalWrite(ENC_A_PIN, LOW);  digitalWrite(ENC_B_PIN, HIGH); break;
            case 2: digitalWrite(ENC_A_PIN, HIGH); digitalWrite(ENC_B_PIN, HIGH); break;
            case 3: digitalWrite(ENC_A_PIN, HIGH); digitalWrite(ENC_B_PIN, LOW);  break;
        }
    }

    enc_state = (enc_state + 1) & 0x03;
}

#endif

// -----------------------------------------------------------------------------
// SET UP Block
// -----------------------------------------------------------------------------

void setup() {

    Serial.begin(115200);
    while (!Serial);

    Serial.println("Starting...");

    /**
     * Shrike / FPGA initialization
     * ----------------------------
     * 1. Initialize the Shrike interface
     * 2. Load the quadrature_decoder bitstream into the FPGA
     *
     * After shrike.flash(), the FPGA should be running the decoder logic,
     * and its output is routed to Uart Rx pin of RP2040.
     */
    shrike.begin();
    shrike.flash(BITSTREAM);

    Serial.println("FPGA Flash Done");

    delay(2000);

    // UART from FPGA
    Serial1.setRX(RX_PIN);
    Serial1.begin(BAUDRATE);

    Serial.println("UART Ready");

#if USE_INTERNAL_ENCODER_TEST
    init_encoder_test();
#endif
}

// -----------------------------------------------------------------------------
// LOOP block
// -----------------------------------------------------------------------------
/*
 * UART Packets receving and Decoding happens here and prints over serial monitor.
 * Reads incoming FPGA bytes continuously.
 * Multi-byte fields are transmitted MSB first (big-endian format).
 * Ensures correct alignment using header and followed by 7 bytes of data
 *     - [AA][pos MSB][pos LSB][spd MSB][spd LSB][ang MSB][ang LSB][dir]
 *
 * For Position and Speed decoding :
 *     - Combines 2 bytes → signed 16-bit and decides the +ve or -ve based on sign
 *     - Position and speed are signed values.
 *     - Positive  -> forward rotation
 *     - Negative  -> reverse rotation
 * For Angle : FPGA gives encoder counts, so convert to degrees 
 * 4000 CPR means one full mechanical rotation produces 4000 quadrature counts.
 * For Direction byte : Only LSB will decide
 *     - 1 = forward
 *     - 0 = reverse
 *
*/
void loop() {

#if USE_INTERNAL_ENCODER_TEST
    generate_encoder();
#endif

    while (Serial1.available()) {

        uint8_t b = Serial1.read();

        // sync on header
        if (!receiving) {
            if (b == 0xAA) {
                receiving = true;
                idx = 0;
                packet[idx++] = b;
            }
            continue;
        }

        packet[idx++] = b;

        if (idx == 8) {
            receiving = false;

            // decode signed values
            int16_t position = (int16_t)((int16_t(packet[1]) << 8) | packet[2]);
            int16_t speed    = (int16_t)((int16_t(packet[3]) << 8) | packet[4]);
            uint16_t angle   = (uint16_t)((packet[5] << 8) | packet[6]);
            uint8_t direction = packet[7] & 0x01;

            float angle_deg = ((float)angle * 360.0f) / 4000.0f;

            Serial.print("Pos: ");
            Serial.print(position);

            Serial.print(" | Spd: ");
            Serial.print(speed);

            Serial.print(" | Ang: ");
            Serial.print(angle_deg);

            Serial.print(" deg | Dir: ");
            Serial.println(direction ? "FWD" : "REV");
        }
    }
}