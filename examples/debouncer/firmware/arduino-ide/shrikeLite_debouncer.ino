/**
 * Example: Button Debouncing with Shrike FPGA + RP2040
 *
 * This sketch demonstrates how to:
 *  - Load a debouncer bitstream into the Shrike FPGA
 *  - Read a debounced button signal on an RP2040 pin
 *  - Print button press/release events over Serial
 *
 * Hardware mapping (from Shrike pinouts):
 *  - Physical Button → FPGA PIN3 → RP2040 GPIO 2
 *
 * Optional:
 *  - You can also test directly using an RP2040 GPIO (RP_BUTTON_PIN)
 *    instead of the FPGA signal, by changing the pinMode/digitalRead lines
 *    as indicated in the code. This would generate unexpected results.
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
 *  - The bitstream is generated as a pre-requsite.
 *  - The file is present in your project / filesystem (copied in the data folder)
 *  - The path matches your environment
 *
 * NOTE: Please build and upload the filesystem (littleFS) with correct bitstream.
 */
#define BITSTREAM "/debouncer_generic.bin" // Change the name as per your bitsream

// -----------------------------------------------------------------------------
// Pin definitions
// -----------------------------------------------------------------------------

/**
 * BUTTON_PIN
 * ----------
 * This is the RP2040 pin that receives the debounced button signal
 * from the FPGA.
 *
 * Signal chain:
 *   Physical button → FPGA PIN3 → RP2040 GPIO 2
 */
#define BUTTON_PIN 2  // FPGA PIN3 -> RP2040 PIN2 (from Shrike pinouts)

/**
 * RP_BUTTON_PIN
 * -------------
 * This is an alternative pin used ONLY if you want to bypass the FPGA
 * and test the button directly on the RP2040.
 *
 * If you want to test this mode:
 *   - Uncomment the pinMode/digitalRead lines for RP_BUTTON_PIN
 *   - Comment out the ones that use BUTTON_PIN
 */
#define RP_BUTTON_PIN 18  // RP2040 PIN18 (direct button test, no FPGA)

// -----------------------------------------------------------------------------
// Shrike / FPGA object
// -----------------------------------------------------------------------------

/**
 * ShrikeFlash
 * -----------
 * This object handles communication with the Shrike board's flash and FPGA.
 */
ShrikeFlash shrike;

// -----------------------------------------------------------------------------
// Button state tracking
// -----------------------------------------------------------------------------

/**
 * lastState / currentState
 * ------------------------
 * These variables store the previous and current logic level of the button.
 *
 * Logic levels:
 *   LOW  = 0 (voltage low)
 *   HIGH = 1 (voltage high)
 *
 * We'll use them to detect edges:
 *   - HIGH → LOW  : button pressed
 *   - LOW → HIGH  : button released
 */
int lastState = LOW;  // Initial assumption: button not pressed
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
     *
     * Option A: Test using RP2040 GPIO only (no FPGA)
     *   - Uncomment the pinMode line for RP_BUTTON_PIN
     *   - Comment the pinMode line for BUTTON_PIN
     *
     * Option B: Use debounced signal from FPGA (recommended)
     *   - Use BUTTON_PIN as an input
     */

    // Option A: Direct button on RP2040 (with internal pull-up)
    //pinMode(RP_BUTTON_PIN, INPUT_PULLUP);

    // Option B: Button via FPGA debouncer output.
    /**
     * Note: The RTL for the current design is written in a manner
     * such that the pin is held HIGH by default, thus there is no
     * need to counfigure it as a pull-up pin for current logic.  
     */
    pinMode(BUTTON_PIN, INPUT);

    /**
     * Shrike / FPGA initialization
     * ----------------------------
     * 1. Initialize the Shrike interface
     * 2. Load the debouncer bitstream into the FPGA
     *
     * After shrike.flash(), the FPGA should be running the debouncer logic,
     * and its output is routed to BUTTON_PIN.
     */
    shrike.begin();          // Initialize communication with Shrike
    shrike.flash(BITSTREAM); // Load the FPGA bitstream from flash
}

void loop() {
    /**
     * Read the current button state
     * -----------------------------
     *
     * Option A: If testing directly on RP2040 (no FPGA):
     *   currentState = digitalRead(RP_BUTTON_PIN);
     *
     * Option B: Using debounced output from FPGA:
     *   currentState = digitalRead(BUTTON_PIN);
     */

    // Option A: Direct RP2040 GPIO (uncomment if using RP_BUTTON_PIN)
    //currentState = digitalRead(RP_BUTTON_PIN);

    // Option B: FPGA debounced signal
    currentState = digitalRead(BUTTON_PIN);

    /**
     * Edge detection
     * --------------
     * We compare lastState and currentState to detect transitions:
     *
     *  - Press event:
     *      lastState == HIGH  AND currentState == LOW
     *      (active-low button)
     *
     *  - Release event:
     *      lastState == LOW   AND currentState == HIGH
     *
     * Note: The actual logic (active-low vs active-high) depends on your
     * button wiring and FPGA logic.
     */

    // Detect "press" (transition from HIGH to LOW)
    if (lastState == HIGH && currentState == LOW) {
        Serial.println("The button is pressed");
    }
    // Detect "release" (transition from LOW to HIGH)
    else if (lastState == LOW && currentState == HIGH) {
        Serial.println("The button is released");
    }

    // Update lastState so next loop() can detect changes
    lastState = currentState;
}

