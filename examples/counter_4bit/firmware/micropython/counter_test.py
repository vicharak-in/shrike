import shrike
from machine import Pin
from time import sleep

shrike.flash("4bit_counter.bin")

cntr_pins = [2,1,3,0]

counter = [Pin(pin, Pin.IN) for pin in cntr_pins]

previous = 0

while True:
    value = 0
    # Read each button and shift its value into the correct bit position
    for i in range(4):
        if counter[i].value():
            value += (1 << i)
    if(value != previous):
        # Format strings
        binary_str = "{:04b}".format(value) # 4-digit binary
        hex_str = "{:X}".format(value)      # Uppercase Hex
    
        print(f"Binary: {binary_str} | Hex: 0x{hex_str}")
    previous = value
    sleep(0.1) # Small delay for stability

