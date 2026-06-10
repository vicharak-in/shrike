from machine import Pin, UART, mem32
import machine
import time
import random

# =====================================================
# 1. HARDWARE BASE PERIPHERAL ADDRESS
# =====================================================
I2C1_BASE  = 0x40048000 

# Initialize UART0 and I2C1 pads exactly like your working setup
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
i2c_init = machine.I2C(1, sda=Pin(14), scl=Pin(15), freq=100000)

print("[SYSTEM] Configuring RP2040 into Multi-Transaction Slave...")
mem32[I2C1_BASE + 0x6C] = 0    
mem32[I2C1_BASE + 0x00] = 0x22   
mem32[I2C1_BASE + 0x08] = 0x50   
mem32[I2C1_BASE + 0x6C] = 1    

# Flush out any leftover garbage
while mem32[I2C1_BASE + 0x78] > 0: 
    _ = mem32[I2C1_BASE + 0x10]
if uart.any():
    uart.read()

# =====================================================
# 2. GENERATING AN AGGRESSIVE MULTI-BYTE PAYLOAD ARRAY
# =====================================================
# Yeh array har tarah ke dynamic data handling ko check karega
test_vectors = []

# Block A: Boundary Values (8 Bytes)
test_vectors += [0x00, 0xFF, 0x00, 0xFF, 0x55, 0xAA, 0x55, 0xAA]

# Block B: Walking Ones Pattern (8 Bytes)
test_vectors += [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]

# Block C: Continuous Incremental Sequence (100 Bytes)
test_vectors += [(i & 0xFF) for i in range(100)]

# Block D: Pure Random Stress Data (50 Bytes)
test_vectors += [random.randint(0, 255) for _ in range(50)]

total_tests = len(test_vectors)
print(f"\n=== STARTING ROBUST STRESS TESTING ({total_tests} MULTIPLE VECTORS) ===")
success_count = 0

for index, trigger_byte in enumerate(test_vectors):
    # Maintaining your exact verified equation layout
    mock_sensor_reply = (trigger_byte + 0x10) & 0xFF 
    
    print("--------------------------------------------------")
    print(f"VECTOR {index:03d}/{total_tests-1} | Blasting Payload: 0x{trigger_byte:02X}")
    uart.write(bytes([trigger_byte]))
    
    # --- PHASE 1: Handle Inbound FPGA Write ---
    start_time = time.ticks_ms()
    write_success = False
    captured_write_val = 0x00
    
    while time.ticks_diff(time.ticks_ms(), start_time) < 30:
        if mem32[I2C1_BASE + 0x78] > 0:
            captured_write_val = mem32[I2C1_BASE + 0x10] & 0xFF
            write_success = True
            break
            
    if w