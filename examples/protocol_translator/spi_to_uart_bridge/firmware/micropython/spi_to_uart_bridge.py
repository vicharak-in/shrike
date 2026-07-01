"""
------------------------------------------------------------
File Name : spi_uart_protocol_bridge_test.py

Description:
MicroPython test program for the SPI ↔ UART Protocol Bridge.

This script verifies both communication paths:

1. SPI -> FPGA -> UART
2. UART -> FPGA -> SPI

For each test byte:

- RP2040 sends a byte to the FPGA through SPI.
- FPGA forwards the byte through UART.
- RP2040 verifies the received UART data.

Then:

- RP2040 sends a response byte through UART.
- FPGA stores the byte in its UART FIFO.
- RP2040 reads the byte back through SPI.
- Response is verified.

A dummy SPI transaction is performed before the
actual SPI read because the FPGA loads SPI transmit
data at the beginning of an SPI frame.

Test Size:
100 Bytes

SPI Configuration:
Mode 0
CPOL = 0
CPHA = 0
Clock = 1 MHz

UART Configuration:
115200 Baud
8 Data Bits
No Parity
1 Stop Bit

RP2040 Pin Mapping
------------------------------------------------------------

SPI

GP2  -> FPGA SPI_SCK
GP3  -> FPGA SPI_MOSI
GP0  <- FPGA SPI_MISO
GP1  -> FPGA SPI_CS

UART

GP16 -> FPGA UART_RX
GP17 <- FPGA UART_TX

------------------------------------------------------------
"""

from machine import Pin, SPI, UART
import time
import random


uart = UART(
    0,
    baudrate=115200,
    tx=Pin(16),
    rx=Pin(17)
)

spi = SPI(
    0,
    baudrate=1000000,
    polarity=0,
    phase=0,
    sck=Pin(2),
    mosi=Pin(3),
    miso=Pin(0)
)


cs = Pin(1, Pin.OUT)
cs.value(1)


random.seed(1234)

test_data = [
    random.randint(0, 255)
    for _ in range(100)
]

passed = 0
failed = 0

print()
print("100 BYTE FULL BRIDGE TEST")
print("--------------------------------")

time.sleep_ms(100)

for i, request in enumerate(test_data):


    while uart.any():
        uart.read()

    cs.value(0)
    spi.write(bytes([request]))
    cs.value(1)

    timeout = time.ticks_ms()

    while not uart.any():

        if time.ticks_diff(
            time.ticks_ms(),
            timeout
        ) > 1000:

            print("UART TIMEOUT")
            failed += 1
            break

    if not uart.any():
        continue

    uart_byte = uart.read(1)[0]

    if uart_byte != request:

        failed += 1

        print(
            "SPI->UART FAIL",
            i,
            hex(request),
            hex(uart_byte)
        )

        continue

    response = request ^ 0xFF

    uart.write(bytes([response]))

    time.sleep_ms(30)

    cs.value(0)
    spi.read(1, 0x00)
    cs.value(1)

    time.sleep_ms(10)

    cs.value(0)
    spi_byte = spi.read(1, 0x00)[0]
    cs.value(1)

    if spi_byte == response:

        passed += 1

        print(
            "PASS",
            i,
            "REQ=",
            hex(request),
            "RESP=",
            hex(response)
        )

    else:

        failed += 1

        print(
            "UART->SPI FAIL",
            i,
            "EXP=",
            hex(response),
            "RX=",
            hex(spi_byte)
        )

print("--------------------------------")
print("SUMMARY")
print("Passed :", passed)
print("Failed :", failed)

if failed == 0:
    print("SUCCESS")
else:
    print("FAILURE")

