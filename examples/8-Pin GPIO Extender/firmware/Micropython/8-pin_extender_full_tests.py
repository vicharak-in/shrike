from machine import Pin, SPI
import time

class ShrikeFPGAGPIO:
    """
    Driver for FPGA GPIO control via SPI
    
    Pin Mapping (FPGA Internal GPIO -> Physical Pin):
    - GPIO03 (Pin 2)  -> SPI_SCLK
    - GPIO04 (Pin 17) -> SPI_SS
    - GPIO05 (Pin 18) -> SPI_SI (MOSI)
    - GPIO06 (Pin 19) -> SPI_SO (MISO)
    - GPIO18 (Pin 9)  -> RST_N
    
    Independent GPIO Pins (8-bit):
    - Bit 0 -> GPIO07 (Pin 20)
    - Bit 1 -> GPIO08 (Pin 23)
    - Bit 2 -> GPIO09 (Pin 24)
    - Bit 3 -> GPIO10 (Pin 1)
    - Bit 4 -> GPIO11 (Pin 2)
    - Bit 5 -> GPIO12 (Pin 3)
    - Bit 6 -> GPIO13 (Pin 4)
    - Bit 7 -> GPIO14 (Pin 5)
    
    Command Protocol: {Addr[3:0], Data[3:0]}
    0x1X - Set GPIO[3:0] direction (lower nibble)
    0x2X - Set GPIO[7:4] direction (upper nibble)
    0x3X - Set GPIO[3:0] output data (lower nibble)
    0x4X - Set GPIO[7:4] output data (upper nibble)
    
    Direction: 0 = Output, 1 = Input
    """
    
    # Pin mapping reference
    FPGA_PIN_MAP = {
        0: "GPIO07 (FPGA Pin 20)",
        1: "GPIO08 (FPGA Pin 23)",
        2: "GPIO09 (FPGA Pin 24)",
        3: "GPIO10 (FPGA Pin 1)",
        4: "GPIO11 (FPGA Pin 2)",
        5: "GPIO12 (FPGA Pin 3)",
        6: "GPIO13 (FPGA Pin 4)",
        7: "GPIO14 (FPGA Pin 5)"
    }
    
    def __init__(self, spi_id=0, baudrate=1000000, cs_pin=1):
        """
        Initialize SPI interface to FPGA
        
        RP2040/RP2350 SPI Pins (based on your table):
        - SCLK: GPIO 2  -> FPGA GPIO03 (Pin 2)
        - MOSI: GPIO 3  -> FPGA GPIO05 (Pin 18)
        - MISO: GPIO 0  -> FPGA GPIO06 (Pin 19)
        - CS:   GPIO 1  -> FPGA GPIO04 (Pin 17)
        """
        self.spi = SPI(spi_id, 
                       baudrate=baudrate,
                       polarity=0,  # CPOL=0
                       phase=0,     # CPHA=0
                       bits=8,
                       firstbit=SPI.MSB,
                       sck=Pin(2),
                       mosi=Pin(3),
                       miso=Pin(0))
        
        self.cs = Pin(cs_pin, Pin.OUT)
        self.cs.value(1)  # CS idle high
        
        # Internal state tracking
        self.dir_reg = 0xFF  # All inputs initially
        self.out_reg = 0x00  # All outputs low initially
        
    def _spi_transfer(self, data):
        """Send command and read back GPIO state"""
        self.cs.value(0)
        time.sleep_us(1)
        rx = self.spi.read(1, data)
        time.sleep_us(1)
        self.cs.value(1)
        time.sleep_us(10)
        return rx[0]
    
    def get_pin_name(self, pin):
        """Get FPGA pin mapping for reference"""
        return self.FPGA_PIN_MAP.get(pin, "Unknown")
    
    def set_pin_direction(self, pin, is_input):
        """
        Set individual pin direction
        pin: 0-7 (maps to GPIO07-GPIO14)
        is_input: True for input, False for output
        """
        if pin < 0 or pin > 7:
            raise ValueError("Pin must be 0-7")
        
        if is_input:
            self.dir_reg |= (1 << pin)
        else:
            self.dir_reg &= ~(1 << pin)
        
        # Update FPGA
        if pin < 4:
            cmd = 0x10 | (self.dir_reg & 0x0F)
        else:
            cmd = 0x20 | ((self.dir_reg >> 4) & 0x0F)
        
        self._spi_transfer(cmd)
    
    def set_all_directions(self, dir_byte):
        """
        Set all 8 pins direction at once
        dir_byte: 8-bit value (1=Input, 0=Output)
        """
        self.dir_reg = dir_byte & 0xFF
        self._spi_transfer(0x10 | (self.dir_reg & 0x0F))
        self._spi_transfer(0x20 | ((self.dir_reg >> 4) & 0x0F))
    
    def write_pin(self, pin, value):
        """
        Write to individual output pin
        pin: 0-7 (maps to GPIO07-GPIO14)
        value: 0 or 1
        """
        if pin < 0 or pin > 7:
            raise ValueError("Pin must be 0-7")
        
        if value:
            self.out_reg |= (1 << pin)
        else:
            self.out_reg &= ~(1 << pin)
        
        # Update FPGA
        if pin < 4:
            cmd = 0x30 | (self.out_reg & 0x0F)
        else:
            cmd = 0x40 | ((self.out_reg >> 4) & 0x0F)
        
        self._spi_transfer(cmd)
    
    def write_all(self, value):
        """Write to all 8 output pins at once"""
        self.out_reg = value & 0xFF
        self._spi_transfer(0x30 | (self.out_reg & 0x0F))
        self._spi_transfer(0x40 | ((self.out_reg >> 4) & 0x0F))
    
    def read_all(self):
        """Read all 8 GPIO pins state"""
        # Send dummy command to get readback
        gpio_state = self._spi_transfer(0x00)
        return gpio_state
    
    def read_pin(self, pin):
        """Read individual pin state"""
        if pin < 0 or pin > 7:
            raise ValueError("Pin must be 0-7")
        
        gpio_state = self.read_all()
        return (gpio_state >> pin) & 1
    
    def print_pin_map(self):
        """Print the pin mapping for reference"""
        print("\nFPGA GPIO Pin Mapping:")
        print("="*60)
        print("Bit | Internal GPIO | Physical Pin | Current State")
        print("-"*60)
        current_state = self.read_all()
        for bit in range(8):
            state = "HIGH" if (current_state >> bit) & 1 else "LOW"
            direction = "IN" if (self.dir_reg >> bit) & 1 else "OUT"
            if bit == 0:
                print(f" {bit}  | GPIO07        | Pin 20       | {state} ({direction})")
            elif bit == 1:
                print(f" {bit}  | GPIO08        | Pin 23       | {state} ({direction})")
            elif bit == 2:
                print(f" {bit}  | GPIO09        | Pin 24       | {state} ({direction})")
            elif bit == 3:
                print(f" {bit}  | GPIO10        | Pin 1        | {state} ({direction})")
            elif bit == 4:
                print(f" {bit}  | GPIO11        | Pin 2        | {state} ({direction})")
            elif bit == 5:
                print(f" {bit}  | GPIO12        | Pin 3        | {state} ({direction})")
            elif bit == 6:
                print(f" {bit}  | GPIO13        | Pin 4        | {state} ({direction})")
            elif bit == 7:
                print(f" {bit}  | GPIO14        | Pin 5        | {state} ({direction})")
        print("="*60)


# ===== TEST FUNCTIONS =====

def test_1_loopback():
    """
    Test 1: Loopback Test
    Connect FPGA pins in pairs with jumper wires:
    - Bit 0 (GPIO07/Pin 20) to Bit 1 (GPIO08/Pin 23)
    - Bit 2 (GPIO09/Pin 24) to Bit 3 (GPIO10/Pin 1)
    - Bit 4 (GPIO11/Pin 2)  to Bit 5 (GPIO12/Pin 3)
    - Bit 6 (GPIO13/Pin 4)  to Bit 7 (GPIO14/Pin 5)
    """
    print("\n" + "="*60)
    print("TEST 1: LOOPBACK TEST")
    print("="*60)
    print("Connect jumper wires between FPGA physical pins:")
    print("  Pin 20 (GPIO07/Bit 0) <-> Pin 23 (GPIO08/Bit 1)")
    print("  Pin 24 (GPIO09/Bit 2) <-> Pin 1  (GPIO10/Bit 3)")
    print("  Pin 2  (GPIO11/Bit 4) <-> Pin 3  (GPIO12/Bit 5)")
    print("  Pin 4  (GPIO13/Bit 6) <-> Pin 5  (GPIO14/Bit 7)")
    input("Press Enter when ready...")
    
    fpga = ShrikeFPGAGPIO()
    
    # Set even bits as outputs, odd bits as inputs
    # Dir: 0=Output, 1=Input -> 0b10101010 = 0xAA
    fpga.set_all_directions(0xAA)
    time.sleep_ms(10)
    
    print("\nTesting loopback patterns...")
    test_patterns = [0x00, 0x55, 0xAA, 0xFF]
    pass_count = 0
    
    for pattern in test_patterns:
        # Write pattern to output pins (even bits)
        fpga.write_all(pattern)
        time.sleep_ms(10)
        
        # Read back
        readback = fpga.read_all()
        
        # Expected: odd bits should match even bits
        expected = 0
        for i in range(4):
            out_bit = (pattern >> (i*2)) & 1
            expected |= (out_bit << (i*2))      # Even bit
            expected |= (out_bit << (i*2 + 1))  # Odd bit (looped back)
        
        passed = (readback == expected)
        print(f"Written: 0x{pattern:02X}, Read: 0x{readback:02X}, Expected: 0x{expected:02X}", end="")
        print(" ✓ PASS" if passed else " ✗ FAIL")
        if passed:
            pass_count += 1
    
    print(f"\nResult: {pass_count}/{len(test_patterns)} patterns passed")
    fpga.print_pin_map()


def test_2_individual_pins():
    """
    Test 2: Individual Pin Control
    No jumpers needed - tests direction and output control
    """
    print("\n" + "="*60)
    print("TEST 2: INDIVIDUAL PIN CONTROL")
    print("="*60)
    print("This test verifies individual pin direction/output control")
    print("No jumpers needed - uses internal state verification\n")
    
    fpga = ShrikeFPGAGPIO()
    
    # Test each pin individually
    for pin in range(8):
        pin_name = fpga.get_pin_name(pin)
        print(f"\nTesting Bit {pin} -> {pin_name}")
        
        # Set as output
        fpga.set_pin_direction(pin, is_input=False)
        time.sleep_ms(5)
        
        # Write HIGH
        fpga.write_pin(pin, 1)
        time.sleep_ms(5)
        print(f"  Set HIGH (out_reg = 0x{fpga.out_reg:02X})")
        
        # Write LOW
        fpga.write_pin(pin, 0)
        time.sleep_ms(5)
        print(f"  Set LOW  (out_reg = 0x{fpga.out_reg:02X})")
        
        # Set as input
        fpga.set_pin_direction(pin, is_input=True)
        time.sleep_ms(5)
        print(f"  Set INPUT (dir_reg = 0x{fpga.dir_reg:02X})")
    
    print("\n✓ Individual pin control test complete")
    fpga.print_pin_map()


def test_3_walking_ones():
    """
    Test 3: Walking 1's Pattern
    Connect GPIO pins in a chain:
    Pin 20 -> 23 -> 24 -> 1 -> 2 -> 3 -> 4 -> 5
    """
    print("\n" + "="*60)
    print("TEST 3: WALKING 1's PATTERN")
    print("="*60)
    print("Connect jumper wires in chain (FPGA physical pins):")
    print("  Pin 20 -> 23 -> 24 -> 1 -> 2 -> 3 -> 4 -> 5")
    print("  (GPIO07 -> GPIO08 -> GPIO09 -> GPIO10 -> GPIO11 -> GPIO12 -> GPIO13 -> GPIO14)")
    input("Press Enter when ready...")
    
    fpga = ShrikeFPGAGPIO()
    
    # Bit 0 (GPIO07/Pin 20) as output, rest as inputs
    fpga.set_all_directions(0xFE)  # 11111110
    time.sleep_ms(10)
    
    print("\nWalking HIGH through the chain...")
    print("(Bit 0/GPIO07/Pin 20 is driven, others should follow)\n")
    
    for i in range(5):  # Run 5 cycles
        # Drive bit 0 HIGH
        fpga.write_pin(0, 1)
        time.sleep_ms(100)
        
        # Read and display
        state = fpga.read_all()
        print(f"Cycle {i+1}: Read = 0b{state:08b} (0x{state:02X})")
        
        # Drive bit 0 LOW
        fpga.write_pin(0, 0)
        time.sleep_ms(100)
    
    print("\n✓ If you see 1's propagating, the chain is connected correctly")


def test_4_bidirectional():
    """
    Test 4: Bidirectional Communication
    Connect Bit 0 (GPIO07/Pin 20) <-> Bit 4 (GPIO11/Pin 2)
    """
    print("\n" + "="*60)
    print("TEST 4: BIDIRECTIONAL TEST")
    print("="*60)
    print("Connect jumper wire between FPGA physical pins:")
    print("  Pin 20 (GPIO07/Bit 0) <-> Pin 2 (GPIO11/Bit 4)")
    input("Press Enter when ready...")
    
    fpga = ShrikeFPGAGPIO()
    
    print("\nTest A: Bit 0 (OUT) -> Bit 4 (IN)")
    fpga.set_pin_direction(0, is_input=False)
    fpga.set_pin_direction(4, is_input=True)
    time.sleep_ms(10)
    
    pass_count = 0
    for val in [0, 1, 0, 1]:
        fpga.write_pin(0, val)
        time.sleep_ms(10)
        read_val = fpga.read_pin(4)
        passed = (val == read_val)
        print(f"  Bit 0 (GPIO07) = {val}, Bit 4 (GPIO11) = {read_val}", end="")
        print(" ✓" if passed else " ✗")
        if passed:
            pass_count += 1
    
    print(f"Test A: {pass_count}/4 passed\n")
    
    print("Test B: Bit 4 (OUT) -> Bit 0 (IN)")
    fpga.set_pin_direction(0, is_input=True)
    fpga.set_pin_direction(4, is_input=False)
    time.sleep_ms(10)
    
    pass_count = 0
    for val in [1, 0, 1, 0]:
        fpga.write_pin(4, val)
        time.sleep_ms(10)
        read_val = fpga.read_pin(0)
        passed = (val == read_val)
        print(f"  Bit 4 (GPIO11) = {val}, Bit 0 (GPIO07) = {read_val}", end="")
        print(" ✓" if passed else " ✗")
        if passed:
            pass_count += 1
    
    print(f"Test B: {pass_count}/4 passed")


def test_5_blink_pattern():
    """
    Test 5: LED Blink Pattern (if you have LEDs with resistors)
    If no LEDs, you can measure with multimeter or scope
    """
    print("\n" + "="*60)
    print("TEST 5: BLINK PATTERN")
    print("="*60)
    print("Optional: Connect LEDs with 330Ω resistors to FPGA pins:")
    print("  Pin 20, 23, 24, 1, 2, 3, 4, 5")
    print("  (GPIO07-GPIO14)")
    print("Or use multimeter/oscilloscope to verify outputs")
    input("Press Enter to start blinking...")
    
    fpga = ShrikeFPGAGPIO()
    
    # Set all as outputs
    fpga.set_all_directions(0x00)
    time.sleep_ms(10)
    
    print("\nRunning blink patterns for 10 seconds...")
    print("Pattern: Running lights (Bit 0->7->0)\n")
    
    start_time = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), start_time) < 10000:
        # Forward
        for i in range(8):
            fpga.write_all(1 << i)
            time.sleep_ms(100)
        
        # Backward
        for i in range(6, 0, -1):
            fpga.write_all(1 << i)
            time.sleep_ms(100)
    
    fpga.write_all(0x00)
    print("✓ Pattern complete")
    fpga.print_pin_map()


def run_all_tests():
    """Run all tests in sequence"""
    print("\n" + "="*60)
    print("SHRIKE FPGA GPIO TEST SUITE")
    print("="*60)
    
    tests = [
        test_1_loopback,
        test_2_individual_pins,
        test_3_walking_ones,
        test_4_bidirectional,
        test_5_blink_pattern
    ]
    
    for i, test in enumerate(tests, 1):
        try:
            test()
        except KeyboardInterrupt:
            print("\n\nTest interrupted by user")
            break
        except Exception as e:
            print(f"\n✗ Test {i} failed with error: {e}")
            import sys
            sys.print_exception(e)
        
        if i < len(tests):
            print("\n" + "-"*60)
            input("Press Enter for next test...")
    
    print("\n" + "="*60)
    print("ALL TESTS COMPLETE")
    print("="*60)


# ===== INTERACTIVE MODE =====

def interactive_mode():
    """Interactive REPL for manual testing"""
    print("\n" + "="*60)
    print("INTERACTIVE MODE")
    print("="*60)
    
    fpga = ShrikeFPGAGPIO()
    fpga.print_pin_map()
    
    print("\nAvailable commands:")
    print("  map                 - Show pin mapping")
    print("  dir <bit> <0|1>     - Set bit direction (0=out, 1=in)")
    print("  write <bit> <0|1>   - Write bit value")
    print("  read <bit>          - Read bit value")
    print("  read_all            - Read all bits")
    print("  write_all <0xXX>    - Write all bits")
    print("  exit                - Exit interactive mode")
    print()
    
    while True:
        try:
            cmd = input("fpga> ").strip().split()
            if not cmd:
                continue
            
            if cmd[0] == "exit":
                break
            elif cmd[0] == "map":
                fpga.print_pin_map()
            elif cmd[0] == "dir" and len(cmd) == 3:
                pin, val = int(cmd[1]), int(cmd[2])
                fpga.set_pin_direction(pin, bool(val))
                print(f"Set Bit {pin} ({fpga.get_pin_name(pin)}) direction = {'INPUT' if val else 'OUTPUT'}")
            elif cmd[0] == "write" and len(cmd) == 3:
                pin, val = int(cmd[1]), int(cmd[2])
                fpga.write_pin(pin, val)
                print(f"Wrote Bit {pin} ({fpga.get_pin_name(pin)}) = {val}")
            elif cmd[0] == "read" and len(cmd) == 2:
                pin = int(cmd[1])
                val = fpga.read_pin(pin)
                print(f"Bit {pin} ({fpga.get_pin_name(pin)}) = {val}")
            elif cmd[0] == "read_all":
                val = fpga.read_all()
                print(f"All bits = 0b{val:08b} (0x{val:02X})")
                fpga.print_pin_map()
            elif cmd[0] == "write_all" and len(cmd) == 2:
                val = int(cmd[1], 0)
                fpga.write_all(val)
                print(f"Wrote all bits = 0x{val:02X}")
            else:
                print("Invalid command")
        except Exception as e:
            print(f"Error: {e}")


# ===== MAIN MENU =====

def main():
    print("\n" + "="*60)
    print("SHRIKE FPGA GPIO TESTER")
    print("="*60)
    print("\nFPGA Pin Mapping Reference:")
    print("  Bit 0 -> GPIO07 (FPGA Pin 20)")
    print("  Bit 1 -> GPIO08 (FPGA Pin 23)")
    print("  Bit 2 -> GPIO09 (FPGA Pin 24)")
    print("  Bit 3 -> GPIO10 (FPGA Pin 1)")
    print("  Bit 4 -> GPIO11 (FPGA Pin 2)")
    print("  Bit 5 -> GPIO12 (FPGA Pin 3)")
    print("  Bit 6 -> GPIO13 (FPGA Pin 4)")
    print("  Bit 7 -> GPIO14 (FPGA Pin 5)")
    print("\n1. Run All Tests")
    print("2. Test 1: Loopback")
    print("3. Test 2: Individual Pins")
    print("4. Test 3: Walking 1's")
    print("5. Test 4: Bidirectional")
    print("6. Test 5: Blink Pattern")
    print("7. Interactive Mode")
    print("8. Exit")
    
    while True:
        try:
            choice = input("\nSelect option (1-8): ").strip()
            
            if choice == "1":
                run_all_tests()
            elif choice == "2":
                test_1_loopback()
            elif choice == "3":
                test_2_individual_pins()
            elif choice == "4":
                test_3_walking_ones()
            elif choice == "5":
                test_4_bidirectional()
            elif choice == "6":
                test_5_blink_pattern()
            elif choice == "7":
                interactive_mode()
            elif choice == "8":
                print("Goodbye!")
                break
            else:
                print("Invalid choice")
        except KeyboardInterrupt:
            print("\n\nExiting...")
            break

if __name__ == "__main__":
    main()
