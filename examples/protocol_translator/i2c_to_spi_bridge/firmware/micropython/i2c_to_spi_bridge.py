"""
i2c_spi_protocol_bridge.py

MicroPython test application for the FPGA-based
I2C to SPI Protocol Bridge.

The script sends 100 sequential bytes to the FPGA
over I2C and reads back one byte after each
transaction.

Current Test Configuration:
- FPGA configured as I2C slave
- FPGA configured as SPI master
- No external SPI slave connected
- Expected response: 0x00

Pin Mapping:
GP0 -> FPGA SDA
GP1 -> FPGA SCL

I2C Address:
0x32
"""

from machine import I2C, Pin

i2c = I2C(
    0,
    scl=Pin(21),
    sda=Pin(20),
    freq=100000
)

passed = 0
failed = 0

print()
print("100 BYTE I2C-SPI BRIDGE TEST")
print("--------------------------------")

for value in range(100):

    tx = bytes([value])

    i2c.writeto(0x32, tx)

    while True:

        rx = i2c.readfrom(0x32, 1)

        # 0xFF indicates response not ready
        if rx != b'\xFF':
            break

    received = rx[0]

    if received == value:

        passed += 1

        print(
            "PASS",
            value,
            "TX=",
            hex(value),
            "RX=",
            hex(received)
        )

    else:

        failed += 1

        print(
            "FAIL",
            value,
            "TX=",
            hex(value),
            "RX=",
            hex(received)
        )

print("--------------------------------")
print("SUMMARY")
print("Passed :", passed)
print("Failed :", failed)

if failed == 0:
    print("SUCCESS")
else:
    print("FAILURE")
