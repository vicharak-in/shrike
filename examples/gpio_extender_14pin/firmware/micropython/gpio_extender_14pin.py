from machine import Pin, SPI
import time

class ShrikeFPGA14GPIO:
    """
    Driver for 14-bit FPGA GPIO control via SPI
    
    Pin Mapping (Register Bit -> FPGA Internal GPIO -> Physical Pin):
    Bit 0  -> GPIO0  -> Pin 13
    Bit 1  -> GPIO1  -> Pin 14
    Bit 2  -> GPIO2  -> Pin 15
    Bit 3  -> GPIO7  -> Pin 20
    Bit 4  -> GPIO8  -> Pin 23
    Bit 5  -> GPIO9  -> Pin 24
    Bit 6  -> GPIO10 -> Pin 1
    Bit 7  -> GPIO11 -> Pin 2
    Bit 8  -> GPIO12 -> Pin 3
    Bit 9  -> GPIO13 -> Pin 4
    Bit 10 -> GPIO14 -> Pin 5
    Bit 11 -> GPIO15 -> Pin 6
    Bit 12 -> GPIO17 -> Pin 8
    Bit 13 -> GPIO18 -> Pin 9
    
    Reserved/Used Pins:
    - GPIO3  (Pin 16) -> SPI_SCK
    - GPIO4  (Pin 17) -> SPI_SS
    - GPIO5  (Pin 18) -> SPI_MOSI
    - GPIO6  (Pin 19) -> SPI_MISO
    - GPIO16 (Pin 7)  -> RST_N
    
    Command Protocol (2-byte):
    CMD 0x10, DATA -> Set gpio_dir_reg[7:0]
    CMD 0x11, DATA -> Set gpio_dir_reg[13:8] (uses bits [5:0])
    CMD 0x20, DATA -> Set gpio_out_reg[7:0]
    CMD 0x21, DATA -> Set gpio_out_reg[13:8] (uses bits [5:0])
    
    Direction: 1 = Input, 0 = Output
    """
    
    # Complete pin mapping
    PIN_MAP = {
        0:  ("GPIO0",  13),
        1:  ("GPIO1",  14),
        2:  ("GPIO2",  15),
        3:  ("GPIO7",  20),
        4:  ("GPIO8",  23),
        5:  ("GPIO9",  24),
        6:  ("GPIO10", 1),
        7:  ("GPIO11", 2),
        8:  ("GPIO12", 3),
        9:  ("GPIO13", 4),
        10: ("GPIO14", 5),
        11: ("GPIO15", 6),
        12: ("GPIO17", 8),
        13: ("GPIO18", 9),
    }
    
    def __init__(self, spi_id=0, baudrate=500000, cs_pin=1):
        """Initialize SPI interface to FPGA"""
        self.spi = SPI(spi_id, 
                       baudrate=baudrate,
                       polarity=0, phase=0, bits=8,
                       firstbit=SPI.MSB,
                       sck=Pin(2), mosi=Pin(3), miso=Pin(0))
        
        self.cs = Pin(cs_pin, Pin.OUT)
        self.cs.value(1)
        
        self.dir_reg = 0x3FFF  # All inputs (14 bits)
        self.out_reg = 0x0000
        
    def _send_cmd(self, cmd, data):
        """Send 2-byte command sequence"""
        self.cs.value(0)
        time.sleep_us(2)
        self.spi.write(bytes([cmd, data]))
        time.sleep_us(2)
        self.cs.value(1)
        time.sleep_us(20)
    
    def _read_gpio(self):
        """Read all 14 GPIO pins (returns 14-bit value)"""
        self.cs.value(0)
        time.sleep_us(20)
        # Read one byte at a time with delay
        rx0 = self.spi.read(1, 0x00)[0]  # High byte
        time.sleep_us(20)
        rx1 = self.spi.read(1, 0x00)[0]  # Low byte
        time.sleep_us(20)
        self.cs.value(1)
        time.sleep_us(50)
        # CORRECTED: rx0 is HIGH byte, rx1 is LOW byte
        result = rx1 | ((rx0 & 0x3F) << 8)
        return result
    
    def set_pin_direction(self, pin, is_input):
        """Set individual pin direction (0-13)"""
        if pin < 0 or pin > 13:
            raise ValueError("Pin must be 0-13")
        
        if is_input:
            self.dir_reg |= (1 << pin)
        else:
            self.dir_reg &= ~(1 << pin)
        
        # Update FPGA
        if pin < 8:
            self._send_cmd(0x10, self.dir_reg & 0xFF)
        else:
            self._send_cmd(0x11, (self.dir_reg >> 8) & 0x3F)
    
    def set_all_directions(self, dir_14bit):
        """Set all 14 pins direction (14-bit value)"""
        self.dir_reg = dir_14bit & 0x3FFF
        self._send_cmd(0x10, self.dir_reg & 0xFF)
        self._send_cmd(0x11, (self.dir_reg >> 8) & 0x3F)
    
    def write_pin(self, pin, value):
        """Write to individual output pin (0-13)"""
        if pin < 0 or pin > 13:
            raise ValueError("Pin must be 0-13")
        
        if value:
            self.out_reg |= (1 << pin)
        else:
            self.out_reg &= ~(1 << pin)
        
        if pin < 8:
            self._send_cmd(0x20, self.out_reg & 0xFF)
        else:
            self._send_cmd(0x21, (self.out_reg >> 8) & 0x3F)
    
    def write_all(self, value):
        """Write to all 14 output pins"""
        self.out_reg = value & 0x3FFF
        self._send_cmd(0x20, self.out_reg & 0xFF)
        self._send_cmd(0x21, (self.out_reg >> 8) & 0x3F)
    
    def read_all(self):
        """Read all 14 GPIO pins"""
        return self._read_gpio()
    
    def read_pin(self, pin):
        """Read individual pin state (0-13)"""
        if pin < 0 or pin > 13:
            raise ValueError("Pin must be 0-13")
        
        gpio_state = self.read_all()
        return (gpio_state >> pin) & 1
    
    def get_pin_info(self, pin):
        """Get pin information"""
        if pin in self.PIN_MAP:
            gpio_name, phys_pin = self.PIN_MAP[pin]
            return f"Bit{pin:2d} -> {gpio_name:6s} (Pin {phys_pin:2d})"
        return f"Bit{pin:2d} -> Unknown"
    
    def print_pin_map(self):
        """Print current pin states"""
        print("\n" + "="*70)
        print("FPGA 14-GPIO Pin Mapping & Status")
        print("="*70)
        current = self.read_all()
        
        for bit in range(14):
            gpio_name, phys_pin = self.PIN_MAP[bit]
            state = "HIGH" if (current >> bit) & 1 else "LOW"
            direction = "IN " if (self.dir_reg >> bit) & 1 else "OUT"
            print(f"Bit {bit:2d} | {gpio_name:6s} | Pin {phys_pin:2d} | {state:4s} ({direction})")
        print("="*70)


# ===== TEST FUNCTIONS =====

def test_0_spi_diagnostic():
    """
    Test 0: SPI Communication Diagnostic
    No external connections needed - verifies SPI is working
    """
    print("\n" + "="*70)
    print("TEST 0: SPI COMMUNICATION DIAGNOSTIC")
    print("="*70)
    print("This test verifies basic SPI communication with FPGA\n")
    
    fpga = ShrikeFPGA14GPIO()
    
    # Test 1: Set all pins as inputs and read
    print("Step 1: Setting all pins as inputs...")
    fpga.set_all_directions(0x3FFF)
    time.sleep_ms(50)
    val = fpga.read_all()
    print(f"  Read value: 0x{val:04X} (0b{val:014b})")
    print(f"  Bits that are HIGH: {[i for i in range(14) if (val >> i) & 1]}")
    
    # Test 2: Set all pins as outputs, write all LOW
    print("\nStep 2: Setting all pins as outputs, writing LOW...")
    fpga.set_all_directions(0x0000)
    time.sleep_ms(20)
    fpga.write_all(0x0000)
    time.sleep_ms(50)
    val = fpga.read_all()
    print(f"  Read value: 0x{val:04X} (0b{val:014b})")
    print(f"  Expected: 0x0000 (all LOW)")
    if val == 0x0000:
        print("  ✓ PASS")
    
    # Test 3: Write all HIGH
    print("\nStep 3: Writing all HIGH...")
    fpga.write_all(0x3FFF)
    time.sleep_ms(50)
    val = fpga.read_all()
    print(f"  Read value: 0x{val:04X} (0b{val:014b})")
    print(f"  Expected: 0x3FFF (all HIGH)")
    if val == 0x3FFF:
        print("  ✓ PASS")
    
    # Test 4: Test each bit individually with debug
    print("\nStep 4: Testing individual bits (outputs)...")
    fpga.set_all_directions(0x0000)  # All outputs
    time.sleep_ms(20)
    
    print("\nDetailed byte-level debug:")
    for bit in [0, 1, 7, 8, 13]:
        fpga.write_all(1 << bit)
        time.sleep_ms(20)
        
        # Manual read with debug
        fpga.cs.value(0)
        time.sleep_us(10)
        tx_dummy = bytes([0x00, 0x00])
        rx = bytearray(2)
        fpga.spi.write_readinto(tx_dummy, rx)
        time.sleep_us(10)
        fpga.cs.value(1)
        time.sleep_us(50)
        
        val = rx[1] | ((rx[0] & 0x3F) << 8)  # CORRECTED byte order
        expected = 1 << bit
        match = "✓" if val == expected else "✗"
        print(f"  Bit {bit:2d}: Wrote 0x{expected:04X}, Read 0x{val:04X} [Byte0=0x{rx[0]:02X}, Byte1=0x{rx[1]:02X}] {match}")
    
    fpga.write_all(0x0000)
    print("\n✓ Diagnostic complete")
    
    # Additional raw byte test
    print("\nStep 5: Raw byte sequence test...")
    print("Testing what FPGA sends for known output patterns:")
    test_vals = [0x0000, 0x00FF, 0x3F00, 0x3FFF, 0x1234]
    for test_val in test_vals:
        fpga.write_all(test_val)
        time.sleep_ms(20)
        
        fpga.cs.value(0)
        time.sleep_us(10)
        rx = bytearray(2)
        fpga.spi.write_readinto(bytes([0x00, 0x00]), rx)
        time.sleep_us(10)
        fpga.cs.value(1)
        time.sleep_us(50)
        
        print(f"  Wrote: 0x{test_val:04X} -> Read bytes: [0x{rx[0]:02X}, 0x{rx[1]:02X}] = 0x{rx[1] | (rx[0] << 8):04X}")



def test_1_loopback_pairs():
    """
    Test 1: Simple Loopback (7 pairs)
    Connect these pairs with jumper wires:
    Pin 13<->14, 15<->20, 23<->24, 1<->2, 3<->4, 5<->6, 8<->9
    """
    print("\n" + "="*70)
    print("TEST 1: LOOPBACK PAIRS (7 pairs)")
    print("="*70)
    print("Connect jumper wires between FPGA physical pins:")
    print("  Pin 13 <-> Pin 14  (Bit 0 <-> Bit 1)")
    print("  Pin 15 <-> Pin 20  (Bit 2 <-> Bit 3)")
    print("  Pin 23 <-> Pin 24  (Bit 4 <-> Bit 5)")
    print("  Pin 1  <-> Pin 2   (Bit 6 <-> Bit 7)")
    print("  Pin 3  <-> Pin 4   (Bit 8 <-> Bit 9)")
    print("  Pin 5  <-> Pin 6   (Bit 10 <-> Bit 11)")
    print("  Pin 8  <-> Pin 9   (Bit 12 <-> Bit 13)")
    input("Press Enter when ready...")
    
    fpga = ShrikeFPGA14GPIO()
    
    # Set even bits as outputs, odd bits as inputs
    # Pattern: 0b10101010101010 = 0x2AAA
    fpga.set_all_directions(0x2AAA)
    time.sleep_ms(20)
    
    print("\nTesting loopback patterns...")
    test_patterns = [0x0000, 0x1555, 0x2AAA, 0x3FFF]
    pass_count = 0
    
    for pattern in test_patterns:
        fpga.write_all(pattern)
        time.sleep_ms(20)
        
        readback = fpga.read_all()
        
        # Calculate expected: odd bits should mirror even bits
        expected = 0
        for i in range(7):  # 7 pairs
            out_bit = (pattern >> (i*2)) & 1
            expected |= (out_bit << (i*2))      # Even bit
            expected |= (out_bit << (i*2 + 1))  # Odd bit
        
        passed = (readback == expected)
        print(f"Write: 0x{pattern:04X}, Read: 0x{readback:04X}, Expect: 0x{expected:04X}", end="")
        print(" ✓ PASS" if passed else " ✗ FAIL")
        if passed:
            pass_count += 1
    
    print(f"\nResult: {pass_count}/{len(test_patterns)} patterns passed")
    fpga.print_pin_map()


def test_2_individual_control():
    """Test 2: Individual Pin Control - No external connections needed"""
    print("\n" + "="*70)
    print("TEST 2: INDIVIDUAL PIN CONTROL (14 pins)")
    print("="*70)
    print("No jumpers needed - tests register control\n")
    
    fpga = ShrikeFPGA14GPIO()
    
    for pin in range(14):
        print(f"Testing {fpga.get_pin_info(pin)}")
        
        # Set as output
        fpga.set_pin_direction(pin, is_input=False)
        time.sleep_ms(5)
        
        # Toggle HIGH/LOW
        fpga.write_pin(pin, 1)
        time.sleep_ms(5)
        print(f"  Set HIGH (out_reg = 0x{fpga.out_reg:04X})")
        
        fpga.write_pin(pin, 0)
        time.sleep_ms(5)
        print(f"  Set LOW  (out_reg = 0x{fpga.out_reg:04X})")
        
        # Set as input
        fpga.set_pin_direction(pin, is_input=True)
        time.sleep_ms(5)
    
    print("\n✓ All 14 pins tested successfully")
    fpga.print_pin_map()


def test_3_bidirectional():
    """
    Test 3: Bidirectional Test
    Connect Pin 13 <-> Pin 9 (Bit 0 <-> Bit 13)
    """
    print("\n" + "="*70)
    print("TEST 3: BIDIRECTIONAL SWITCHING")
    print("="*70)
    print("Connect jumper: Pin 13 <-> Pin 9 (Bit 0 <-> Bit 13)")
    input("Press Enter when ready...")
    
    fpga = ShrikeFPGA14GPIO()
    
    print("\nTest A: Bit 0 (OUT) -> Bit 13 (IN)")
    fpga.set_pin_direction(0, is_input=False)
    fpga.set_pin_direction(13, is_input=True)
    time.sleep_ms(10)
    
    pass_a = 0
    for val in [0, 1, 0, 1]:
        fpga.write_pin(0, val)
        time.sleep_ms(10)
        read_val = fpga.read_pin(13)
        passed = (val == read_val)
        print(f"  Bit 0 = {val}, Bit 13 = {read_val}", " ✓" if passed else " ✗")
        if passed:
            pass_a += 1
    
    print(f"Test A: {pass_a}/4 passed\n")
    
    print("Test B: Bit 13 (OUT) -> Bit 0 (IN)")
    fpga.set_pin_direction(0, is_input=True)
    fpga.set_pin_direction(13, is_input=False)
    time.sleep_ms(10)
    
    pass_b = 0
    for val in [1, 0, 1, 0]:
        fpga.write_pin(13, val)
        time.sleep_ms(10)
        read_val = fpga.read_pin(0)
        passed = (val == read_val)
        print(f"  Bit 13 = {val}, Bit 0 = {read_val}", " ✓" if passed else " ✗")
        if passed:
            pass_b += 1
    
    print(f"Test B: {pass_b}/4 passed")
    print(f"\nTotal: {pass_a + pass_b}/8 passed")


def test_4_running_lights():
    """
    Test 4: Running Lights Pattern
    Optional: Connect LEDs to verify visually
    """
    print("\n" + "="*70)
    print("TEST 4: RUNNING LIGHTS (14-bit)")
    print("="*70)
    print("Optional: Connect LEDs with 330Ω resistors to any pins")
    print("Or use multimeter/scope to verify")
    input("Press Enter to start pattern...")
    
    fpga = ShrikeFPGA14GPIO()
    
    # Set all as outputs
    fpga.set_all_directions(0x0000)
    time.sleep_ms(10)
    
    print("\nRunning light pattern for 15 seconds...")
    
    start = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), start) < 15000:
        # Forward sweep
        for i in range(14):
            fpga.write_all(1 << i)
            time.sleep_ms(80)
        
        # Backward sweep
        for i in range(12, 0, -1):
            fpga.write_all(1 << i)
            time.sleep_ms(80)
    
    fpga.write_all(0x0000)
    print("✓ Pattern complete")
    fpga.print_pin_map()


def test_5_all_bits_toggle():
    """
    Test 5: All Bits Toggle Test
    No external connections - tests full register writes
    """
    print("\n" + "="*70)
    print("TEST 5: ALL BITS SIMULTANEOUS TOGGLE")
    print("="*70)
    print("No jumpers needed - tests 14-bit register control\n")
    
    fpga = ShrikeFPGA14GPIO()
    
    # Set all as outputs
    fpga.set_all_directions(0x0000)
    time.sleep_ms(10)
    
    patterns = [0x0000, 0x3FFF, 0x1555, 0x2AAA, 0x0F0F, 0x3030]
    
    print("Testing 14-bit patterns:")
    for pattern in patterns:
        fpga.write_all(pattern)
        time.sleep_ms(100)
        print(f"  Written: 0x{pattern:04X} (0b{pattern:014b})")
    
    fpga.write_all(0x0000)
    print("\n✓ All 14-bit patterns written successfully")


def test_6_chain_propagation():
    """
    Test 6: Signal Chain Propagation (Minimal - 4 wires)
    Connect: Pin 13 -> 14 -> 15 -> 20
    """
    print("\n" + "="*70)
    print("TEST 6: CHAIN PROPAGATION (4 pins)")
    print("="*70)
    print("Connect jumper chain:")
    print("  Pin 13 -> 14 -> 15 -> 20")
    print("  (Bit 0 -> Bit 1 -> Bit 2 -> Bit 3)")
    input("Press Enter when ready...")
    
    fpga = ShrikeFPGA14GPIO()
    
    # Bit 0 output, rest inputs
    fpga.set_all_directions(0x3FFE)  # All input except bit 0
    time.sleep_ms(10)
    
    print("\nPropagating signal through chain...\n")
    
    for cycle in range(5):
        # Drive HIGH
        fpga.write_pin(0, 1)
        time.sleep_ms(100)
        state = fpga.read_all()
        print(f"Cycle {cycle+1} HIGH: Bits[3:0] = 0b{(state & 0xF):04b}")
        
        # Drive LOW
        fpga.write_pin(0, 0)
        time.sleep_ms(100)
        state = fpga.read_all()
        print(f"Cycle {cycle+1} LOW:  Bits[3:0] = 0b{(state & 0xF):04b}")
    
    print("\n✓ Chain test complete")


def run_all_tests():
    """Run all tests sequentially"""
    print("\n" + "="*70)
    print("SHRIKE FPGA 14-GPIO TEST SUITE")
    print("="*70)
    
    tests = [
        test_0_spi_diagnostic,
        test_1_loopback_pairs,
        test_2_individual_control,
        test_3_bidirectional,
        test_4_running_lights,
        test_5_all_bits_toggle,
        test_6_chain_propagation
    ]
    
    for i, test in enumerate(tests, 1):
        try:
            test()
        except KeyboardInterrupt:
            print("\n\nTest interrupted")
            break
        except Exception as e:
            print(f"\n✗ Test {i} error: {e}")
            import sys
            sys.print_exception(e)
        
        if i < len(tests):
            print("\n" + "-"*70)
            input("Press Enter for next test...")
    
    print("\n" + "="*70)
    print("ALL TESTS COMPLETE")
    print("="*70)


# ===== INTERACTIVE MODE =====

def interactive_mode():
    """Interactive REPL"""
    print("\n" + "="*70)
    print("INTERACTIVE MODE - 14 GPIO CONTROL")
    print("="*70)
    
    fpga = ShrikeFPGA14GPIO()
    fpga.print_pin_map()
    
    print("\nCommands:")
    print("  map                 - Show pin mapping")
    print("  dir <bit> <0|1>     - Set direction (0=out, 1=in)")
    print("  write <bit> <0|1>   - Write bit value")
    print("  read <bit>          - Read bit value")
    print("  read_all            - Read all 14 bits")
    print("  write_all <0xXXXX>  - Write all bits (14-bit hex)")
    print("  exit                - Exit\n")
    
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
                bit, val = int(cmd[1]), int(cmd[2])
                fpga.set_pin_direction(bit, bool(val))
                print(f"Set {fpga.get_pin_info(bit)} -> {'INPUT' if val else 'OUTPUT'}")
            elif cmd[0] == "write" and len(cmd) == 3:
                bit, val = int(cmd[1]), int(cmd[2])
                fpga.write_pin(bit, val)
                print(f"Wrote {fpga.get_pin_info(bit)} = {val}")
            elif cmd[0] == "read" and len(cmd) == 2:
                bit = int(cmd[1])
                val = fpga.read_pin(bit)
                print(f"{fpga.get_pin_info(bit)} = {val}")
            elif cmd[0] == "read_all":
                val = fpga.read_all()
                print(f"All 14 bits = 0x{val:04X} (0b{val:014b})")
                fpga.print_pin_map()
            elif cmd[0] == "write_all" and len(cmd) == 2:
                val = int(cmd[1], 0) & 0x3FFF
                fpga.write_all(val)
                print(f"Wrote all = 0x{val:04X}")
            else:
                print("Invalid command")
        except Exception as e:
            print(f"Error: {e}")


# ===== MAIN MENU =====

def main():
    print("\n" + "="*70)
    print("SHRIKE FPGA 14-GPIO TESTER")
    print("="*70)
    print("\n14 Available GPIO Pins:")
    print("  Bits 0-2:   Pins 13, 14, 15")
    print("  Bit 3:      Pin 20")
    print("  Bits 4-5:   Pins 23, 24")
    print("  Bits 6-11:  Pins 1, 2, 3, 4, 5, 6")
    print("  Bits 12-13: Pins 8, 9")
    
    print("\n1. Run All Tests")
    print("2. Test 0: SPI Diagnostic (no wires)")
    print("3. Test 1: Loopback Pairs (7 wires)")
    print("4. Test 2: Individual Control (no wires)")
    print("5. Test 3: Bidirectional (1 wire)")
    print("6. Test 4: Running Lights (optional LEDs)")
    print("7. Test 5: All Bits Toggle (no wires)")
    print("8. Test 6: Chain Propagation (4 wires)")
    print("9. Interactive Mode")
    print("10. Exit")
    
    while True:
        try:
            choice = input("\nSelect (1-10): ").strip()
            
            if choice == "1":
                run_all_tests()
            elif choice == "2":
                test_0_spi_diagnostic()
            elif choice == "3":
                test_1_loopback_pairs()
            elif choice == "4":
                test_2_individual_control()
            elif choice == "5":
                test_3_bidirectional()
            elif choice == "6":
                test_4_running_lights()
            elif choice == "7":
                test_5_all_bits_toggle()
            elif choice == "8":
                test_6_chain_propagation()
            elif choice == "9":
                interactive_mode()
            elif choice == "10":
                print("Goodbye!")
                break
            else:
                print("Invalid choice")
        except KeyboardInterrupt:
            print("\n\nExiting...")
            break

if __name__ == "__main__":
    main()
