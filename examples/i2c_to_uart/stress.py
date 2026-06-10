from machine import Pin, UART
import machine
import time
import random

# Initialize Peripherals Mappings
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))

print("==================================================")
print("LAUNCHING ADVANCED EXTREME STRESS HARNESS: PROJ 2")
print("==================================================")

def run_stress_suite(i2c_freq, use_repeated_start, execution_delay):
    # Dynamically reconfigure the master controller framework
    i2c_master = machine.I2C(1, sda=Pin(14), scl=Pin(15), freq=i2c_freq)
    
    if uart.any():
        uart.read()
        
    passed_runs = 0
    test_set = [random.randint(0, 255) for _ in range(50)] # 50 Random stress bytes
    
    for idx, write_payload in enumerate(test_set):
        expected_reply = (write_payload + 0x05) & 0xFF
        
        try:
            # Case Implementation: Toggle between Stop injection and Repeated Start
            if use_repeated_start:
                i2c_master.writeto(0x50, bytes([write_payload]), False) # stop=False (Repeated Start)
            else:
                i2c_master.writeto(0x50, bytes([write_payload]), True)
                
            # Background UART Responder Node tracking
            start_time = time.ticks_ms()
            uart_ok = False
            while time.ticks_diff(time.ticks_ms(), start_time) < 20:
                if uart.any():
                    if uart.read(1)[0] == write_payload:
                        uart.write(bytes([expected_reply]))
                        uart_ok = True
                    break
            
            if not uart_ok:
                continue
                
            if execution_delay > 0:
                time.sleep_ms(execution_delay)
                
            # Master reads the turnaround payload buffer register
            harvested = i2c_master.readfrom(0x50, 1)[0]
            if harvested == expected_reply:
                passed_runs += 1
                
        except Exception as e:
            # Catching hard collisions on physical open-drain lines
            pass
            
        if execution_delay > 0:
            time.sleep_ms(execution_delay)
            
    return passed_runs, len(test_set)

# ----------------------------------------------------
# EXECUTION OF THE ADVANCED TEST MATRIX
# ----------------------------------------------------

print("\n🔥 STAGE 1: Testing Repeated Start (Sr Condition) at 100kHz...")
p1, t1 = run_stress_suite(i2c_freq=100000, use_repeated_start=True, execution_delay=10)
print(f" -> Result: {p1}/{t1} Passed. Stability: {(p1/t1)*100:.2f}%")

print("\n🔥 STAGE 2: Overclocking Core to 400kHz Fast-Mode Operations...")
p2, t2 = run_stress_suite(i2c_freq=400000, use_repeated_start=False, execution_delay=5)
print(f" -> Result: {p2}/{t2} Passed. Stability: {(p2/t2)*100:.2f}%")

print("\n🔥 STAGE 3: Zero-Delay Throughput Saturation (Maximum Back-To-Back Stress)...")
p3, t3 = run_stress_suite(i2c_freq=100000, use_repeated_start=False, execution_delay=0)
print(f" -> Result: {p3}/{t3} Passed. Stability: {(p3/t3)*100:.2f}%")

print("\n" + "="*50)
print("FINAL ROBUSTNESS SCORECARD SUMMARY")
print("="*50)
grand_total_passed = p1 + p2 + p3
grand_total_tests  = t1 + t2 + t3
final_yield = (grand_total_passed / grand_total_tests) * 100

print(f" Total Combined Stress Vectors Run : {grand_total_tests}")
print(f" Total Successful Passes Secured   : {grand_total_passed}")
print(f" Final System Yield Rating         : {final_yield:.2f}%")
print("-" * 50)
if final_yield == 100.0:
    print("VERDICT: CHIP LAYOUT APPROVED AT MAXIMUM CRITICAL RELIABILITY! 🏆")
else:
    print("VERDICT: DESIGN SENSITIVE TO TIMING INTERFERENCE. OPTIMIZATION REQUIRED. ❌")
print("==================================================")