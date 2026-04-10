/**
 * Example: Object Detection with Shrike FPGA + RP2040
 *
 * This sketch demonstrates how to:
 *  - Load a ultrasonic_sensor bitstream into the Shrike FPGA
 *  - Read a object_detected signal on an RP2040 pin
 *  - Print object detected/not detected events over Serial
 *
 * Hardware mapping (from Shrike pinouts):
 *  - Ultrasonic sensor(echo) → FPGA PIN3 → RP2040 GPIO 2
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
#define BITSTREAM "/ultrasonic.bin"

// -----------------------------------------------------------------------------
// Pin definitions
// -----------------------------------------------------------------------------

/**
 * DETECT_PIN
 * ----------
 * This is the RP2040 pin that receives the object detection signal
 * from the FPGA.
 *
 * Signal chain:
 *   Ultrasonic sensor (echo) → FPGA PIN3 → RP2040 GPIO 2
 */
#define DETECT_PIN 2  // FPGA PIN3 -> RP2040 PIN2 (from Shrike pinouts)

// -----------------------------------------------------------------------------
// Shrike / FPGA object
// -----------------------------------------------------------------------------

/**
 * ShrikeFlash
 * -----------
 * This object handles communication with the Shrike board's flash and FPGA.
 * We will:
 *  - Initialize it in setup()
 *  - Use it to flash (load) the ultrasonic bitstream into the FPGA
 */
ShrikeFlash shrike;

// -----------------------------------------------------------------------------
// Object detection state tracking
// -----------------------------------------------------------------------------

/**
 * lastState / currentState
 * ------------------------
 * These variables store the previous and current logic level of the object detection.
 *
 * Logic levels:
 *   LOW  = 0 (voltage low)
 *   HIGH = 1 (voltage high)
 *
 * We'll use them to detect edges:
 *   - HIGH → LOW  : Object not detected
 *   - LOW → HIGH  : object detected
 */
int lastState = LOW;  // Initial assumption: object not detected
int currentState;     // Will hold the latest reading in loop()

void setup() {
    /**
     * Serial setup
     * ------------
     * Initialize USB Serial at 115200 baud for debugging output.
     * The while(!Serial) loop waits until the serial connection is ready.
     * This is handy when using a USB serial monitor.
     */
    Serial.begin(115200);
    while (!Serial) {
        ; // Wait for Serial to be ready
    }

    /**
     * Pin configuration
     * -----------------
     * Use object detected signal from FPGA
     *   - Use DETECT_PIN as an input
     */

    // Option B: DETECT_PIN via FPGA object_detected output.
    /**
     * Note: The RTL for the current design is written in a manner
     * such that the pin is held LOW by default, thus there is no
     * need to counfigure it as a pull-up pin for current logic.  
     */
    pinMode(DETECT_PIN, INPUT);

    /**
     * Shrike / FPGA initialization
     * ----------------------------
     * 1. Initialize the Shrike interface
     * 2. Load the ultrasonic bitstream into the FPGA
     *
     * After shrike.flash(), the FPGA should be running the ultrasonic logic,
     * and its output is routed to DETECT_PIN.
     */
    shrike.begin();          // Initialize communication with Shrike
    shrike.flash(BITSTREAM); // Load the FPGA bitstream from flash
}

void loop() {
    /**
     * Read the current button state
     * -----------------------------
     *
     * Using object detect output from FPGA:
     *   currentState = digitalRead(DETECT_PIN);
     */

    // FPGA object detected signal
    currentState = digitalRead(DETECT_PIN);
    //Serial.printf("FPGA IN: %d\n", currentState);

    /**
     * Edge detection
     * --------------
     * We compare lastState and currentState to detect transitions:
     *
     *  - Object Detect event:
     *      lastState == LOW  AND currentState == HIGH
     *      (assuming active-high button)
     *
     *  - Object not detected event:
     *      lastState == HIGH   AND currentState == LOW
     *
     * Note: The actual logic (active-low vs active-high) depends on your
     * object detect wiring and FPGA logic.
     */

    // "Detect Object" (transition from LOW to HIGH)
    if (lastState == LOW && currentState == HIGH) {
        Serial.println("The object is detected");
    }
    // "Object not Detect" (transition from HIGH to LOW)
    else if (lastState == HIGH && currentState == LOW) {
        Serial.println("The object is not detected");
        //Serial.printf("FPGA IN: %d\n", currentState);
    }

    // Update lastState so next loop() can detect changes
    lastState = currentState;
}
