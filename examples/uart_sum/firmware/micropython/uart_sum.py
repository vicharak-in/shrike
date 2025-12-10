from machine import UART, Pin
import time

# Reset
reset_pin = Pin(2, Pin.OUT, value=1)
reset_pin.value(1)
time.sleep(1)
reset_pin.value(0)
time.sleep(1)

# Initialize UART0 (TX=GPIO0, RX=GPIO1)
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))

def send_value(value):
    uart.write(bytes([value]))

value = 1
while True:
    uart.write(bytes([value]))
    time.sleep(0.5)
    
    uart.write(bytes([value+1]))
    time.sleep(0.5)

    if uart.any():
        reply = uart.read(1)[0]
        print(value, " + ", value+1, " = ", reply)
    
    value = value + 1
    time.sleep(2)