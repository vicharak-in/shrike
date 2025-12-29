from machine import Pin, SPI
import time

# --- PIN DEFINITIONS ---
SCK  = 2
CS   = 1
MOSI = 3
MISO = 0
RST  = 14

# --- INSTRUCTION SET ---
OP_LOAD     = 0
OP_STORE    = 1
OP_ADD      = 2
OP_MUL      = 3
OP_SUB      = 4
OP_SHIFTL   = 5
OP_SHIFTR   = 6
OP_JUMPTOIF = 7
OP_LOGICAND = 8
OP_LOGICOR  = 9
OP_EQUALS   = 10
OP_NEQ      = 11
OP_BITAND   = 12
OP_BITOR    = 13
OP_LOGICNOT = 14
OP_BITNOT   = 15

# --- MODES ---
MODE_LOADPROG = 0
MODE_LOADDATA = 1
MODE_SETRUNPT = 2
MODE_RUNPROG  = 3

# --- SETUP ---
print("\n=== 4-BIT CPU FINAL VERIFICATION ===")

reset_pin = Pin(RST, Pin.OUT, value=1)

def hard_reset():
    reset_pin.value(0)
    time.sleep(0.05)
    reset_pin.value(1)
    time.sleep(0.1)

# Lowered baudrate to 50kHz for maximum stability
cs = Pin(CS, Pin.OUT, value=1)
spi = SPI(0, baudrate=50_000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
          sck=Pin(SCK), mosi=Pin(MOSI), miso=Pin(MISO))

# --- HELPERS ---

def send_packet(data, instr, reset, step):
    packet = 0
    packet |= (data & 0x0F) << 4
    packet |= (instr & 0x03) << 2
    packet |= (reset & 0x01) << 1
    packet |= (step & 0x01) << 0
    
    tx = bytes([packet])
    rx = bytearray(1)
    
    cs.value(0)
    time.sleep(0.005) # Increased delay for stability
    spi.write_readinto(tx, rx)
    time.sleep(0.005)
    cs.value(1)
    time.sleep(0.02)
    return rx[0]

def read_state():
    resp = send_packet(0, 0, 0, 0)
    reg = resp >> 4
    pc = resp & 0x0F
    return pc, reg

def write_prog(addr, opcode):
    send_packet(addr, MODE_SETRUNPT, 0, 1)
    send_packet(opcode, MODE_LOADPROG, 0, 1)

def write_data(addr, val):
    send_packet(addr, MODE_SETRUNPT, 0, 1)
    send_packet(val, MODE_LOADDATA, 0, 1)

def check(test_name, expected_reg, expected_pc=None):
    pc, reg = read_state()
    pc_match = True if expected_pc is None else (pc == expected_pc)
    reg_match = (reg == expected_reg)
    
    if pc_match and reg_match:
        print(f"  [PASS] {test_name}")
    else:
        print(f"  [FAIL] {test_name}")
        print(f"         Got PC:{pc} REG:{reg}")
        print(f"         Exp PC:{expected_pc if expected_pc is not None else 'Any'} REG:{expected_reg}")

def peek_data(addr):
    """Safely reads data at addr by temporarily swapping Opcode to LOAD"""
    # 1. Save current opcode (we assume we know what it is or overwrite it later)
    # Since we are in a test, we will just restore what we expect.
    
    # 2. Write LOAD opcode to this address
    write_prog(addr, OP_LOAD)
    
    # 3. Execute it
    send_packet(addr, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1)
    
    # 4. Read Result
    pc, reg = read_state()
    return reg

# --- TESTS ---

def test_arithmetic():
    print("\n--- Test 1: Arithmetic ---")
    
    # 1. SETUP DATA
    write_data(0, 3) 
    write_data(1, 2) 
    write_data(2, 3) 
    write_data(3, 2) # CHANGED: Using 2 for MUL test (2*2=4)
    
    # 2. SETUP PROGRAM
    write_prog(0, OP_LOAD)
    write_prog(1, OP_ADD)
    write_prog(2, OP_SUB)
    write_prog(3, OP_MUL)
    
    # 3. RUN
    send_packet(0, MODE_SETRUNPT, 0, 1) 
    
    send_packet(0, MODE_RUNPROG, 0, 1) 
    check("LOAD 3", 3)
    
    send_packet(0, MODE_RUNPROG, 0, 1) 
    check("ADD 2 (3+2=5)", 5)
    
    send_packet(0, MODE_RUNPROG, 0, 1) 
    check("SUB 3 (5-3=2)", 2)
    
    # DEBUG: Verify Data[3] using the "Peek" method
    # This checks the memory without running MUL
    val_at_3 = peek_data(3)
    print(f"  [DEBUG] Data[3] read as: {val_at_3} (Expected 2)")
    
    # RESTORE Program[3] to MUL (because peek_data changed it to LOAD)
    write_prog(3, OP_MUL)
    
    # Restore REG to 2 (Peek corrupted it)
    write_data(15, 2) # scratchpad
    write_prog(15, OP_LOAD)
    send_packet(15, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1) # Reg is now 2
    
    # Now set PC to 3 and Run MUL
    send_packet(3, MODE_SETRUNPT, 0, 1) 
    send_packet(0, MODE_RUNPROG, 0, 1) 
    check("MUL 2 (2*2=4)", 4)

def test_logic():
    print("\n--- Test 2: Logic & Bitwise ---")
    write_data(0, 5)
    write_data(1, 3)
    
    write_prog(0, OP_LOAD)
    write_prog(1, OP_BITAND)
    
    send_packet(0, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1) 
    send_packet(0, MODE_RUNPROG, 0, 1) 
    check("BITAND (5 & 3 = 1)", 1)
    
    # BITOR
    write_prog(0, OP_LOAD)
    write_prog(1, OP_BITOR)
    send_packet(0, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1) 
    send_packet(0, MODE_RUNPROG, 0, 1) 
    check("BITOR (5 | 3 = 7)", 7)

def test_shifts():
    print("\n--- Test 3: Bit Shifts ---")
    write_data(0, 1)
    write_data(1, 2)
    write_prog(0, OP_LOAD)
    write_prog(1, OP_SHIFTL)
    
    send_packet(0, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1)
    check("SHIFTL (1 << 2 = 4)", 4)

def test_memory():
    print("\n--- Test 4: Memory (STORE) ---")
    write_data(0, 9)
    write_data(1, 5)
    write_data(2, 0)
    
    write_prog(0, OP_LOAD)   
    write_prog(1, OP_STORE) 
    write_prog(2, OP_LOAD)   
    write_prog(5, OP_LOAD)   
    
    send_packet(0, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1) 
    send_packet(0, MODE_RUNPROG, 0, 1) 
    send_packet(0, MODE_RUNPROG, 0, 1) 
    
    send_packet(5, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1) 
    
    check("STORE/LOAD Roundtrip", 9)

def test_jump():
    print("\n--- Test 5: Branching (JUMPTOIF) ---")
    
    # 1. CLEANUP
    write_data(15, 0)       
    write_prog(15, OP_LOAD) 
    send_packet(15, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1) 

    # 2. SETUP JUMP TEST
    write_data(0, 5) 
    write_prog(0, OP_JUMPTOIF)
    
    # CASE A: Jump NOT taken
    send_packet(0, MODE_SETRUNPT, 0, 1)
    send_packet(0, MODE_RUNPROG, 0, 1) 
    check("Jump Not Taken (PC->1)", 0, expected_pc=1)
    
    # CASE B: Jump TAKEN
    send_packet(0, MODE_SETRUNPT, 0, 1)
    send_packet(8, MODE_RUNPROG, 0, 1) 
    check("Jump Taken (PC->5)", 0, expected_pc=5)

# --- RUN ---
hard_reset()
test_arithmetic()
test_logic()
test_shifts()
test_memory()
test_jump()
print("\n=== All Tests Completed ===")
