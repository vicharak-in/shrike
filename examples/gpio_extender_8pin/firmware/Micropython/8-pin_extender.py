from machine import Pin, SPI
import time

# --- Hardware Configuration ---
# Based on your confirmed mapping
sck_pin  = Pin(2)
mosi_pin = Pin(3)
miso_pin = Pin(0)
ss_pin   = Pin(1, Pin.OUT, value=1)
rst_pin  = Pin(14, Pin.OUT, value=1)

# Probe pin to read physical FPGA output
probe = Pin(15, Pin.IN) 

# SPI0 Initialization (CPOL=0, CPHA=0)
spi = SPI(0, baudrate=1_000_000, sck=sck_pin, mosi=mosi_pin, miso=miso_pin)

# --- Register Addresses (From Verilog Case Statement) ---
ADDR_DIR_LOW  = 0x1 # gpio_dir_reg[3:0]
ADDR_DIR_HIGH = 0x2 # gpio_dir_reg[7:4]
ADDR_OUT_LOW  = 0x3 # gpio_out_reg[3:0]
ADDR_OUT_HIGH = 0x4 # gpio_out_reg[7:4]

def send_cmd(addr, data):
    """Sends command and returns the current physical state of the 8 GPIOs"""
    packet = (addr << 4) | (data & 0x0F)
    ss_pin.value(0)
    # The MISO return value reflects i_gpio_pins
    read_byte = spi.read(1, packet)[0]
    ss_pin.value(1)
    return read_byte

def reset_fpga():
    print("Action: Resetting FPGA Core...")
    rst_pin.value(0)
    time.sleep(0.1)
    rst_pin.value(1) # De-assertion synchronized internally
    time.sleep(0.1)

# --- Test Suite ---
def run_tests():
    reset_fpga()
    
    # TEST 1: Default State Verification
    # On reset, all pins should be Inputs (High-Z)
    initial_state = send_cmd(0x0, 0x0)
    print(f"Test 1: Reset State - Read: {bin(initial_state)} (Expected: All Inputs)")

    # TEST 2: Lower Nibble Output Drive
    print("\nTest 2: Lower Nibble (Pins 20, 23, 24, 1) Drive Test")
    send_cmd(ADDR_DIR_LOW, 0x0) # Set lower 4 bits to Output (0)
    print("Action: Connect Jumper from RP2040 GPIO 15 to FPGA Pin 20 (Bit 0)")
    
    for val in [0x1, 0x2, 0x4, 0x8]: # Walking 1s
        send_cmd(ADDR_OUT_LOW, val)
        time.sleep(0.1)
        # Physical check on Bit 0 (only if val is 0x1)
        if val == 0x1:
            print(f" - Bit 0 High Check: {'PASS' if probe.value() == 1 else 'FAIL'}")
        send_cmd(ADDR_OUT_LOW, 0x0) # Clear
        time.sleep(0.1)

    # TEST 3: Upper Nibble Independent Drive
    print("\nTest 3: Upper Nibble (Pins 2, 3, 4, 5) Drive Test")
    send_cmd(ADDR_DIR_HIGH, 0x0) # Set upper 4 bits to Output (0)
    print("Action: Move Jumper to FPGA Pin 2 (Bit 4)")
    
    send_cmd(ADDR_OUT_HIGH, 0x1) # Set Bit 4 High
    time.sleep(0.1)
    print(f" - Bit 4 High Check: {'PASS' if probe.value() == 1 else 'FAIL'}")
    
    # TEST 4: Persistence Check
    # Ensure writing upper nibble didn't overwrite lower nibble output state
    send_cmd(ADDR_OUT_LOW, 0x1) # Bit 0 High
    send_cmd(ADDR_OUT_HIGH, 0x8) # Bit 7 High
    # Both should now be high in the readback
    current_read = send_cmd(0x0, 0x0)
    print(f"Test 4: Persistence Read - {bin(current_read)} (Should see bits 0 and 7 High)")

    # TEST 5: Input Mode (Tristate) Verification
    print("\nTest 5: Tristate/Input Mode Check")
    send_cmd(ADDR_DIR_LOW, 0xF) # Set Lower to Input (1)
    print("Action: Connect FPGA Pin 20 to 3.3V")
    time.sleep(2) # Give user time to connect
    input_read = send_cmd(0x0, 0x0)
    print(f" - Pin 20 (Bit 0) High Input Detection: {'PASS' if (input_read & 0x01) else 'FAIL'}")

run_tests()
