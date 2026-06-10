from machine import Pin, UART
import machine
import time
import random

# 1. Initialize Peripherals (RP2040 is the Master of both links here)
# UART0 configured as the background slave responder (Object B)
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))

# I2C1 initialized as a true Hardware Master (Object A) running at 100kHz standard mode
i2c_master = machine.I2C(1, sda=Pin(14), scl=Pin(15), freq=100000)

print("==================================================")
print("LAUNCHING INDUSTRIAL STRESS TEST: PROJECT 2 MASTER")
print("==================================================")

# Flush any residual telemetry bytes from serial/bus buffers
if uart.any():
    uart.read()

# =====================================================
# 2. GENERATING THE EXHAUSTIVE TEST PAYLOAD ARRAY
# =====================================================
test_vectors = []

# Block A: Extreme Boundary Stress (8 Bytes)
test_vectors += [0x00, 0xFF, 0x00, 0xFF, 0x55, 0xAA, 0x55, 0xAA]

# Block B: Walking Ones Crosstalk Verification (8 Bytes)
test_vectors += [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]

# Block C: Continuous Sequence Sweeps (50 Bytes)
test_vectors += [(i & 0xFF) for i in range(50)]

# Block D: Pure Randomized Stress Noise (40 Bytes)
test_vectors += [random.randint(0, 255) for _ in range(40)]

total_tests = len(test_vectors)
success_count = 0

print(f"[SYSTEM] Loaded {total_tests} dynamic vectors. Commencing real silicon sweeps...\n")

for index, write_payload in enumerate(test_vectors):
    # Mathematical golden reference rule matching our hardware testbench calculation
    expected_mcu_reply = (write_payload + 0x05) & 0xFF 
    
    print("--------------------------------------------------")
    print(f"VECTOR {index:03d}/{total_tests-1} | Master Initiating Write: 0x{write_payload:02X}")
    
    # --- PHASE 1: Object A Executes I2C Master Write to FPGA Slave (0x50) ---
    try:
        i2c_master.writeto(0x50, bytes([write_payload]))
    except Exception as e:
        print(" ❌ [I2C Master] Bus Hardware Error during Write transmission frame.")
        continue
        
    # --- PHASE 2: Object B Intercepts on UART RX and Dispatches Turnaround Reply ---
    start_time = time.ticks_ms()
    uart_captured = False
    captured_uart_val = 0x00
    
    while time.ticks_diff(time.ti