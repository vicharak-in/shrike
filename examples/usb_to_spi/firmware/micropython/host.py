# host.py -- PC-side test driver for the USB-to-SPI bridge (runs on your computer).
#
# Opens the RP2040's USB serial port and streams a few bytes to it. The RP2040
# forwards each byte over SPI to the FPGA, which clocks it out to the external
# slave (e.g. an Arduino). Watch the slave's serial monitor to confirm the bytes
# arrive. Requires pyserial:  pip install pyserial
#
# Set PORT to the RP2040's COM port (Windows Device Manager) or /dev/tty* (Linux).

import time
import serial

# Platform configuration (PC host).
CONFIG = {
    "port": "COM3",
    "baudrate": 115200,
    "payload": [0xAB, 0xCD, 0xEF, 0x42],
}

with serial.Serial(CONFIG["port"], CONFIG["baudrate"], timeout=1) as ser:
    time.sleep(0.5)

    print("Sending bytes to the external slave via the FPGA:")
    for value in CONFIG["payload"]:
        ser.write(bytes([value]))
        print("  Sent: 0x%02X" % value)
        time.sleep(0.05)

    print("Done. Check the slave's serial monitor.")
