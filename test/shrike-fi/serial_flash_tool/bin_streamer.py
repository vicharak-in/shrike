import serial
import time
import os
import sys
from serial.tools import list_ports

# Configuration
BAUDRATE = 115200
CHUNK_SIZE = 8000   #Ajustable

# -------- Get file(s) --------
if len(sys.argv) > 1:
    file_paths = sys.argv[1:]
else:
    FILE_PATH = input("Enter firmware file path: ").strip()
    file_paths = [FILE_PATH]

# -------- Detect serial ports --------
ports = [
    p.device for p in list_ports.comports()
    if p.device.startswith("/dev/ttyACM")
]

if not ports:
    print("No valid serial ports found")
    sys.exit(1)

print(f"Found {len(ports)} serial port(s): {ports}")

# -------- Open all ports --------
serial_connections = []
for port in ports:
    try:
        ser = serial.Serial(port, BAUDRATE, timeout=1, rtscts=False, dsrdtr=False)
        serial_connections.append(ser)
        print(f"Opened {port}")
    except Exception as e:
        print(f"Failed to open {port}: {e}")

if not serial_connections:
    print("Could not open any ports")
    sys.exit(1)

# IMPORTANT: wait for all devices to reset and be ready
time.sleep(1)

# -------- Send file(s) --------
for FILE_PATH in file_paths:

    if not os.path.isfile(FILE_PATH):
        print(f"Invalid file: {FILE_PATH}")
        continue

    file_size = os.path.getsize(FILE_PATH)
    print(f"\nUploading: {os.path.basename(FILE_PATH)} ({file_size} bytes)")

    sent = 0

    with open(FILE_PATH, "rb") as file:
        while sent < file_size:
            data = file.read(CHUNK_SIZE)
            if not data:
                break

            # Send to ALL ports
            for ser in serial_connections:
                try:
                    ser.write(data)
                    ser.flush()  # ensure data is pushed out
                except Exception as e:
                    print(f" Write failed on {ser.port}: {e}")

            sent += len(data)
            print(f"Sent {sent}/{file_size} bytes", end='\r')

            time.sleep(0.02)  # small delay improves reliability

    print(f"\n Done: {FILE_PATH}")

# -------- Close all ports --------
for ser in serial_connections:
    ser.close()

print("All transfers complete")
