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
    16	    file_paths = sys.argv[2:]
17	else:
18	    FILE_PATH = input("Enter firmware file path : ").strip()
19	    file_paths = [FILE_PATH]
20	
21	ser = serial.Serial(PORT, BAUDRATE, timeout=1, rtscts=False, dsrdtr=False)
22	
23	for FILE_PATH in file_paths:
24	    if not os.path.exists(FILE_PATH):
25	        print(f" Error: File not found: {FILE_PATH}")
26	        continue
27	    if os.path.isdir(FILE_PATH):
28	        print(f" Error: '{FILE_PATH}' is a DIRECTORY!")
29	        continue
30	    if not os.path.isfile(FILE_PATH):
31	        print(f" Error: '{FILE_PATH}' is not a file")
32	        continue
33	
34	    file_size = os.path.getsize(FILE_PATH)
35	    print(f" Uploading: {os.path.basename(FILE_PATH)} ({file_size} bytes)")
36	
37	    sent = 0
38	    with open(FILE_PATH, "rb") as file:
39	        while sent < file_size:
40	            data = file.read(CHUNK_SIZE)
41	            if not data:
42	                break
43	            ser.write(data)
44	            sent += len(data)
45	            print(f"Sent {sent}/{file_size} bytes", end='\r')
46	            time.sleep(0.01)  # 10ms delay
47	
48	    print(f"\nFile transfer complete. Total: {sent} bytes")
49	
50	ser.close()
