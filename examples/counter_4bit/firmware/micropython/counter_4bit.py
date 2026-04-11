import shrike
from machine import Pin
from time import sleep

# Command to flash the bitstream uncomment if want to flash the bitstream from the script
#shrike.flash("counter_4bit.bin")

cntr_pins = [2,1,3,0]
counter = [Pin(pin, Pin.IN) for pin in cntr_pins]
nreset = Pin(14, Pin.OUT)
updown = Pin(15, Pin.OUT)

previous = 0

# Test UP counting
print("=== Testing UP Counter ===")
nreset.value(0)
sleep(0.2)
nreset.value(1)
updown.value(1)

while True:
    value = 0
    # Read each button and shift its value into the correct bit position
    for i in range(4):
        if counter[i].value():
            value += (1 << i)

    if(value != previous):
        # Format strings
        binary_str = "{:04b}".format(value)  # 4-digit binary
        deci_str = "{:d}".format(value)        # Decimal

        print(f"Binary: {binary_str} | Decimal: {deci_str}")
        previous = value

        if value == 15:
            break

    sleep(0.1)  # Small delay for stability

# Test DOWN counting
print("=== Testing DOWN Counter ===")
nreset.value(0)
sleep(0.2)
nreset.value(1)
updown.value(0)
previous = 0

while True:
    value = 0
    # Read each button and shift its value into the correct bit position
    for i in range(4):
        if counter[i].value():
            value += (1 << i)

    if(value != previous):
        # Format strings
        binary_str = "{:04b}".format(value)  # 4-digit binary
        deci_str = "{:d}".format(value)        # Decimal
        
        print(f"Binary: {binary_str} | Decimal: {deci_str}")
        previous = value

        if value == 0:
            break

    sleep(0.1)  # Small delay for stability

print("=== Test Complete ===")
