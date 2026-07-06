import serial
import time

# Replace COM5 with your actual RP2040 port (e.g., COM3, COM4)
ser = serial.Serial("COM5", 115200, timeout=2)
ser.dtr = True
ser.rts = True
time.sleep(0.5)

print("1. Interrupting (Ctrl+C), Exiting Raw REPL (Ctrl+B), Soft Rebooting (Ctrl+D)...")
ser.write(b"\x03\x03")
time.sleep(0.2)
ser.write(b"\x02")
time.sleep(0.1)
ser.write(b"\x04")
time.sleep(2.0)
print("Reboot output:")
print(ser.read_all().decode("utf-8", errors="replace"))

print("2. Sending PING\r\n...")
ser.write(b"PING\r\n")
time.sleep(1.0)
print("PING reply:")
print(ser.read_all().decode("utf-8", errors="replace"))

ser.close()