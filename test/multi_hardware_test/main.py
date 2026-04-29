from machine import Pin
import time
import shrike

led_pins = [4, 5, 6, 7, 8, 9, 10, 
            11, 14, 15, 16, 17, 
            18, 19, 20, 21, 22, 23, 24, 25, 26, 27,28,29]

# Initialize all pins as outputs
leds = [Pin(pin, Pin.OUT) for pin in led_pins]

shrike.reset()
shrike.flash("blink_all.bin")

while True:
    # Blink all together
    for led in leds:
        led.value(1)
    time.sleep(1)

    for led in leds:
        led.value(0)
    time.sleep(1)
