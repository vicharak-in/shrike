import serial
import time
import os
import sys

#Configuration Setup
if len(sys.argv) > 1:
    PORT = sys.argv[1]
else:
    PORT = input("Enter serial port (e.g., /dev/ttyACM0 or COM3): ").strip()

BAUDRATE = 115200  # Match Shrike Baud Rate
CHUNK_SIZE = 46408 # Size of Bitstream

if len(sys.argv) > 2:
    file_paths = sys.argv[2:]
else:
    FILE_PATH = input("Enter firmware file path : ").strip()
    file_paths = [FILE_PATH]

for FILE_PATH in file_paths:
    if not os.path.exists(FILE_PATH):
        print(f" Error: File not found: {FILE_PATH}")
        continue
    if os.path.isdir(FILE_PATH):
        print(f" Error: '{FILE_PATH}' is a DIRECTORY!")
        continue
    if not os.path.isfile(FILE_PATH):
        print(f" Error: '{FILE_PATH}' is not a file")
        continue
    
file_size = os.path.getsize(FILE_PATH)
print(f" Uploading: {os.path.basename(FILE_PATH)} ({file_size} bytes)")

ser = serial.Serial(PORT, BAUDRATE, timeout=1, rtscts=False, dsrdtr=False)
file_size = os.path.getsize(FILE_PATH)
print(f"File size: {file_size} bytes")
sent = 0
with open(FILE_PATH, "rb") as file:
    while sent < file_size:
        data = file.read(CHUNK_SIZE)
        if not data:
              break
        ser.write(data)
        sent += len(data)
        print(f"Sent {sent}/{file_size} bytes", end='\r')
        time.sleep(0.01)  # 10ms delay

print(f"\nFile transfer complete. Total: {sent} bytes")
ser.close()
