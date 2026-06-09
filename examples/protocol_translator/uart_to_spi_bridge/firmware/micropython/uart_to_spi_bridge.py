"""
------------------------------------------------------------
File Name : uart_to_spi_bridge.py

Description:
MicroPython test program for the UART to SPI Bridge.

This script sends 100 bytes to the FPGA through UART
and waits for a response.

Current Test Configuration:
- UART communication verified
- SPI slave not yet implemented
- Expected response: 0x00

Pin Mapping:
GP8  -> FPGA UART RX
GP9  <- FPGA UART TX

Baud Rate:
115200

------------------------------------------------------------
"""

from machine import UART, Pin
import time

# ----------------------------------------------------------
# UART Configuration
#
# GP8  -> FPGA RX
# GP9  <- FPGA TX
# ----------------------------------------------------------

uart = UART(
    1,
    baudrate=115200,
    tx=Pin(8),
    rx=Pin(9)
)

print("100 BYTE UART-SPI BRIDGE TEST")
print("--------------------------------")

# Count communication errors
errors = 0

# ----------------------------------------------------------
# Send 100 bytes to the FPGA
# ----------------------------------------------------------

for i in range(100):

    # Convert integer to single byte
    tx_byte = bytes([i & 0xFF])

    print("Sending:", hex(i))

    # Send UART data
    uart.write(tx_byte)

    # Wait for FPGA response
    time.sleep_ms(100)

    if uart.any():

        # Read received byte
        rx = uart.read()

        print("Received:", rx)

        # Current expected result:
        # SPI slave is not implemented yet,
        # therefore the expected response is 0x00.

        if rx != b'\x00':
            errors += 1
            print("Unexpected Response")

    else:

        errors += 1
        print("NO RESPONSE")

print("--------------------------------")
print("Test Complete")
print("Errors =", errors)
