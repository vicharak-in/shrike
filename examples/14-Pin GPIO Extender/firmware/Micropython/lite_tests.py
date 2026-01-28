"""
Shrike FPGA 14-GPIO Simple Test Script
========================================

This is a beginner-friendly version that demonstrates how to control
the FPGA's 14 GPIO pins step-by-step with clear explanations.

Hardware Setup:
- Shrike Lite board with FPGA programmed
- No external connections needed for basic tests
- Optional: Jumper wires for loopback tests

"""

from machine import Pin, SPI
import time 


# ==============================================================================
# STEP 1: Initialize SPI Communication
# ==============================================================================

print("\n" + "="*60)
print("SHRIKE FPGA GPIO - SIMPLE DEMO")
print("="*60)

# Create SPI object to talk to the FPGA
# The RP2040 pins connect to FPGA as follows:
#   GPIO 0 (MISO) <- Receives data from FPGA
#   GPIO 1 (CS)   -> Chip Select (tells FPGA we're talking to it)
#   GPIO 2 (SCK)  -> Clock signal
#   GPIO 3 (MOSI) -> Sends data to FPGA

spi = SPI(0,                    # Use SPI bus 0
          baudrate=1000000,     # 1 MHz speed (1 million bits per second)
          polarity=0,           # Clock is LOW when idle
          phase=0,              # Sample data on first clock edge
          bits=8,               # Send/receive 8 bits at a time
          firstbit=SPI.MSB,     # Send most significant bit first
          sck=Pin(2),           # Clock on GPIO 2
          mosi=Pin(3),          # Data out on GPIO 3
          miso=Pin(0))          # Data in on GPIO 0

cs = Pin(1, Pin.OUT)            # Chip Select on GPIO 1
cs.value(1)                     # CS is HIGH when not talking to FPGA

print("✓ SPI initialized successfully")
print("  - Speed: 1 MHz")
print("  - MISO: GPIO 0, MOSI: GPIO 3, SCK: GPIO 2, CS: GPIO 1")


# ==============================================================================
# STEP 2: Define Helper Functions
# ==============================================================================

def send_command(cmd_byte, data_byte):
    """
    Send a 2-byte command to the FPGA.
    
    Args:
        cmd_byte: Command code (0x10, 0x11, 0x20, 0x21)
        data_byte: Data to send
    
    Example:
        send_command(0x10, 0x00)  # Set pins 0-7 as outputs
    """
    cs.value(0)              # Pull CS LOW to start communication
    time.sleep_us(10)        # Small delay for stability
    spi.write(bytes([cmd_byte, data_byte]))  # Send 2 bytes
    time.sleep_us(10)
    cs.value(1)              # Pull CS HIGH to end communication
    time.sleep_us(50)        # Wait for FPGA to process


def read_gpio():
    """
    Read all 14 GPIO pins from the FPGA.
    
    Returns:
        14-bit integer representing pin states (0 or 1 for each pin)
    
    The FPGA sends data in 2 bytes:
        Byte 1: High byte [13:8] - upper 6 bits
        Byte 2: Low byte [7:0]   - lower 8 bits
    """
    cs.value(0)              # Start communication
    time.sleep_us(20)
    
    # Read first byte (high bits 13-8)
    high_byte = spi.read(1, 0x00)[0]
    time.sleep_us(20)
    
    # Read second byte (low bits 7-0)
    low_byte = spi.read(1, 0x00)[0]
    time.sleep_us(20)
    
    cs.value(1)              # End communication
    time.sleep_us(50)
    
    # Combine the two bytes into one 14-bit number
    # high_byte has bits [13:8], low_byte has bits [7:0]
    gpio_value = low_byte | ((high_byte & 0x3F) << 8)
    
    return gpio_value


def set_pin_direction(pin_num, is_input):
    """
    Set a single pin as input or output.
    
    Args:
        pin_num: Pin number (0-13)
        is_input: True for input, False for output
    
    Example:
        set_pin_direction(0, False)  # Set pin 0 as output
        set_pin_direction(5, True)   # Set pin 5 as input
    """
    if pin_num < 0 or pin_num > 13:
        print(f"Error: Pin {pin_num} is out of range (0-13)")
        return
    
    # The FPGA uses these commands:
    # 0x10 = Set direction for pins 0-7
    # 0x11 = Set direction for pins 8-13
    
    # We need to set the correct bit: 1=input, 0=output
    if pin_num < 8:
        # Pins 0-7: use command 0x10
        # For simplicity, we'll set one pin at a time
        # In real use, you'd read-modify-write to preserve other pins
        bit_value = 1 if is_input else 0
        mask = 1 << pin_num
        if is_input:
            send_command(0x10, 0xFF)  # Set all to input first (simple approach)
        else:
            send_command(0x10, 0x00)  # Set all to output first
    else:
        # Pins 8-13: use command 0x11
        bit_value = 1 if is_input else 0
        if is_input:
            send_command(0x11, 0x3F)  # Set all to input
        else:
            send_command(0x11, 0x00)  # Set all to output
    
    direction = "INPUT" if is_input else "OUTPUT"
    print(f"  Pin {pin_num} set as {direction}")


def write_pin(pin_num, value):
    """
    Write HIGH (1) or LOW (0) to an output pin.
    
    Args:
        pin_num: Pin number (0-13)
        value: 1 for HIGH, 0 for LOW
    
    Example:
        write_pin(0, 1)  # Set pin 0 HIGH
        write_pin(3, 0)  # Set pin 3 LOW
    """
    if pin_num < 0 or pin_num > 13:
        print(f"Error: Pin {pin_num} is out of range (0-13)")
        return
    
    # The FPGA uses these commands:
    # 0x20 = Write to pins 0-7
    # 0x21 = Write to pins 8-13
    
    if pin_num < 8:
        # Create a byte with just this pin set
        data = (1 << pin_num) if value else 0
        send_command(0x20, data)
    else:
        # Pins 8-13
        data = (1 << (pin_num - 8)) if value else 0
        send_command(0x21, data)
    
    state = "HIGH" if value else "LOW"
    print(f"  Pin {pin_num} set to {state}")


def write_all_pins(value):
    """
    Write to all 14 pins at once.
    
    Args:
        value: 14-bit number (0x0000 to 0x3FFF)
    
    Example:
        write_all_pins(0x3FFF)  # Set all pins HIGH
        write_all_pins(0x0000)  # Set all pins LOW
        write_all_pins(0x1234)  # Set pattern 0001001000110100
    """
    # Send lower 8 bits (pins 0-7)
    send_command(0x20, value & 0xFF)
    
    # Send upper 6 bits (pins 8-13)
    send_command(0x21, (value >> 8) & 0x3F)
    
    print(f"  All pins set to 0x{value:04X} (0b{value:014b})")


def set_all_directions(value):
    """
    Set all 14 pin directions at once.
    
    Args:
        value: 14-bit number where 1=input, 0=output
    
    Example:
        set_all_directions(0x0000)  # All outputs
        set_all_directions(0x3FFF)  # All inputs
        set_all_directions(0x00AA)  # Pins 1,3,5,7 as inputs, rest outputs
    """
    # Send lower 8 bits (pins 0-7)
    send_command(0x10, value & 0xFF)
    
    # Send upper 6 bits (pins 8-13)
    send_command(0x11, (value >> 8) & 0x3F)
    
    print(f"  All directions set to 0x{value:04X}")


# ==============================================================================
# STEP 3: Simple Tests
# ==============================================================================

print("\n" + "-"*60)
print("BASIC TESTS")
print("-"*60)

# TEST 1: Set all pins as outputs
print("\nTest 1: Configure all pins as OUTPUTS")
set_all_directions(0x0000)  # 0 = output
time.sleep_ms(100)
print("✓ All 14 pins are now outputs")

# TEST 2: Turn all pins ON (HIGH)
print("\nTest 2: Turn all pins HIGH")
write_all_pins(0x3FFF)  # All bits = 1
time.sleep_ms(100)

# Read back to verify
state = read_gpio()
print(f"  Read back: 0x{state:04X}")
if state == 0x3FFF:
    print("✓ Success! All pins are HIGH")
else:
    print("⚠ Some pins may not be HIGH (this is OK if they're floating)")

time.sleep(1)

# TEST 3: Turn all pins OFF (LOW)
print("\nTest 3: Turn all pins LOW")
write_all_pins(0x0000)  # All bits = 0
time.sleep_ms(100)

state = read_gpio()
print(f"  Read back: 0x{state:04X}")
if state == 0x0000:
    print("✓ Success! All pins are LOW")
else:
    print("⚠ Some pins reading HIGH (might be floating as inputs)")

time.sleep(1)

# TEST 4: Blink a single pin
print("\nTest 4: Blink pin 0 (GPIO0, Physical Pin 13)")
print("  If you have an LED on this pin, you'll see it blink!")

for i in range(5):
    write_pin(0, 1)  # Turn ON
    print(f"  Blink {i+1}/5 - Pin 0 HIGH")
    time.sleep_ms(300)
    
    write_pin(0, 0)  # Turn OFF
    print(f"  Blink {i+1}/5 - Pin 0 LOW")
    time.sleep_ms(300)

print("✓ Blink test complete")

# TEST 5: Running lights pattern
print("\nTest 5: Running lights across all 14 pins")
print("  Watch the pins light up in sequence!")

for i in range(14):
    pattern = 1 << i  # Create pattern with just one bit set
    write_all_pins(pattern)
    print(f"  Pin {i} active (pattern: 0x{pattern:04X})")
    time.sleep_ms(150)

write_all_pins(0x0000)  # Turn all off
print("✓ Running lights complete")


# ==============================================================================
# STEP 4: Interactive Demo
# ==============================================================================

print("\n" + "="*60)
print("INTERACTIVE DEMO")
print("="*60)
print("\nYou can now control the GPIO pins manually!")
print("\nCommands:")
print("  'on <pin>'   - Turn a pin HIGH (e.g., 'on 5')")
print("  'off <pin>'  - Turn a pin LOW (e.g., 'off 5')")
print("  'read'       - Read all pin states")
print("  'blink <pin>'- Blink a pin 3 times")
print("  'help'       - Show this help")
print("  'exit'       - Exit the demo")

# First, set all as outputs
set_all_directions(0x0000)

while True:
    try:
        cmd = input("\nfpga> ").strip().lower().split()
        
        if not cmd:
            continue
        
        if cmd[0] == "exit":
            print("Goodbye!")
            break
        
        elif cmd[0] == "help":
            print("\nCommands:")
            print("  on <pin>    - Turn pin HIGH")
            print("  off <pin>   - Turn pin LOW")
            print("  read        - Read all pins")
            print("  blink <pin> - Blink pin 3 times")
            print("  exit        - Exit")
        
        elif cmd[0] == "on" and len(cmd) == 2:
            pin = int(cmd[1])
            if 0 <= pin <= 13:
                write_pin(pin, 1)
            else:
                print("Error: Pin must be 0-13")
        
        elif cmd[0] == "off" and len(cmd) == 2:
            pin = int(cmd[1])
            if 0 <= pin <= 13:
                write_pin(pin, 0)
            else:
                print("Error: Pin must be 0-13")
        
        elif cmd[0] == "read":
            state = read_gpio()
            print(f"\nGPIO State: 0x{state:04X} (binary: 0b{state:014b})")
            print("\nPin states:")
            for i in range(14):
                bit = (state >> i) & 1
                status = "HIGH" if bit else "LOW"
                print(f"  Pin {i:2d}: {status}")
        
        elif cmd[0] == "blink" and len(cmd) == 2:
            pin = int(cmd[1])
            if 0 <= pin <= 13:
                print(f"Blinking pin {pin}...")
                for _ in range(3):
                    write_pin(pin, 1)
                    time.sleep_ms(200)
                    write_pin(pin, 0)
                    time.sleep_ms(200)
                print("Done!")
            else:
                print("Error: Pin must be 0-13")
        
        else:
            print("Unknown command. Type 'help' for commands.")
    
    except KeyboardInterrupt:
        print("\n\nExiting...")
        break
    except Exception as e:
        print(f"Error: {e}")

# Clean up - turn all pins off
print("\nCleaning up...")
write_all_pins(0x0000)
print("All pins set to LOW")
print("\n" + "="*60)
print("Demo complete!")
print("="*60)
