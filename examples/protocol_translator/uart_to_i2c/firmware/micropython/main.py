from machine import Pin, UART, mem32
import machine
import time
import random
I2C1_BASE = 0x40048000 
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
i2c_init = machine.I2C(1, sda=Pin(14), scl=Pin(15), freq=100000)
print("[SYSTEM] Configuring RP2040 into Multi-Transaction Slave...")
mem32[I2C1_BASE + 0x6C] = 0    
mem32[I2C1_BASE + 0x00] = 0x22 
mem32[I2C1_BASE + 0x08] = 0x50 
mem32[I2C1_BASE + 0x6C] = 1    
def flush_hardware_buffers():
    _ = mem32[I2C1_BASE + 0x40] 
    _ = mem32[I2C1_BASE + 0x50] 
    _ = mem32[I2C1_BASE + 0x54] 
    _ = mem32[I2C1_BASE + 0x60] 
flush_hardware_buffers()
while mem32[I2C1_BASE + 0x78] > 0: 
    _ = mem32[I2C1_BASE + 0x10]
if uart.any():
    uart.read()
test_vectors = []
test_vectors += [0x00, 0xFF, 0x00, 0xFF, 0x55, 0xAA, 0x55, 0xAA]
test_vectors += [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]
test_vectors += [(i & 0xFF) for i in range(100)]
test_vectors += [random.randint(0, 255) for _ in range(50)]
total_tests = len(test_vectors)
print(f"\n=== STARTING ROBUST STRESS TESTING ({total_tests} MULTIPLE VECTORS) ===")
success_count = 0
for index, trigger_byte in enumerate(test_vectors):
    mock_sensor_reply = (trigger_byte + 0x10) & 0xFF
    print("--------------------------------------------------")
    print(f"VECTOR {index:03d}/{total_tests-1} | Blasting Payload: 0x{trigger_byte:02X}")
    flush_hardware_buffers()
    uart.write(bytes([trigger_byte]))
    start_time = time.ticks_ms()
    write_success = False
    captured_write_val = 0x00
    while time.ticks_diff(time.ticks_ms(), start_time) < 30:
        if mem32[I2C1_BASE + 0x78] > 0: 
            captured_write_val = mem32[I2C1_BASE + 0x10] & 0xFF
            write_success = True
            break
        time.sleep_us(5)
    if write_success:
        print(f" -> [I2C Slave] FPGA Write Caught: 0x{captured_write_val:02X}")
    else:
        print(" -> [I2C Slave] Write Timeout Error.")
        continue
    start_time = time.ticks_ms()
    read_success = False
    while time.ticks_diff(time.ticks_ms(), start_time) < 30:
        if mem32[I2C1_BASE + 0x34] & (1 << 5):
            mem32[I2C1_BASE + 0x10] = mock_sensor_reply
            _ = mem32[I2C1_BASE + 0x50] 
            print(f" -> [I2C Slave] Read Request Filled: 0x{mock_sensor_reply:02X}")
            read_success = True
            break
        time.sleep_us(5)
    if not read_success:
        print(" -> [I2C Slave] Read Request Timeout Error.")
        continue
    time.sleep_ms(20) 
    if uart.any():
        echo_val = uart.read(1)[0]
        print(f" -> [UART RX] Object A Logged Echo: 0x{echo_val:02X}")
        if echo_val == mock_sensor_reply:
            print(" >> CYCLE VERIFICATION STATUS: PASS ✅")
            success_count += 1
        else:
            print(f" >> CYCLE VERIFICATION STATUS: FAIL ❌ (Expected: 0x{mock_sensor_reply:02X}, Got: 0x{echo_val:02X})")
    else:
        print(" >> CYCLE VERIFICATION STATUS: FAIL ❌ (UART Line Silent)")
print("\n==================================================")
print(f" FINAL BENCH BENCHMARK: {success_count}/{total_tests} CYCLES PASSED PERFECTLY")
print("==================================================")