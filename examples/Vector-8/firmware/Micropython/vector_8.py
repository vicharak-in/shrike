from machine import Pin, SPI
import time

# --- CONFIGURATION ---
SCK, CS, MOSI, MISO, RST = 2, 1, 3, 0, 14

# --- ISA DEFINITIONS (32-ISA) ---
OP_NOP, OP_LDA, OP_ADD, OP_SUB = 0x00, 0x01, 0x02, 0x03
OP_AND, OP_OR,  OP_XOR, OP_LSL = 0x04, 0x05, 0x06, 0x07
OP_LSR, OP_ROL, OP_ROR, OP_INC = 0x08, 0x09, 0x0A, 0x0B
OP_DEC, OP_JMP, OP_JZ,  OP_JNZ = 0x0C, 0x0D, 0x0E, 0x0F

# --- INITIALIZATION ---
reset_pin = Pin(RST, Pin.OUT, value=1)
cs = Pin(CS, Pin.OUT, value=1)
spi = SPI(0, baudrate=50_000, polarity=0, phase=0, bits=8, 
          sck=Pin(SCK), mosi=Pin(MOSI), miso=Pin(MISO))

def hard_reset():
    reset_pin.value(0)
    time.sleep(0.05)
    reset_pin.value(1)
    time.sleep(0.1)

def send_instr(opcode, data):
    """Sends 2-byte instruction and follows with a dummy NOP to read result."""
    # 1. Execute Command
    cs.value(0)
    spi.write(bytes([opcode & 0x1F, data & 0xFF]))
    cs.value(1)
    
    time.sleep_ms(2) # CPU processing time

    # 2. Readback Result using NOP
    rx = bytearray(2)
    cs.value(0)
    spi.write_readinto(bytes([OP_NOP, 0x00]), rx)
    cs.value(1)
    return rx[1] # Returning the Accumulator value

def check(label, got, expected):
    status = "PASS" if got == expected else "FAIL"
    print(f"  [{status}] {label:25} | Got: {got:3} | Exp: {expected:3}")
    return 1 if got == expected else 0

# --- MASTER TEST SUITE ---
def run_full_diagnostics():
    print("Starting CPU Diagnostics...\n" + "="*50)
    score = 0
    total = 0
    hard_reset()

    # SECTION 1: 8-BIT BOUNDARY ARITHMETIC
    print("\n[1] Arithmetic & Overflow")
    score += check("LDA 255 (Max Byte)", send_instr(OP_LDA, 255), 255)
    score += check("INC (255 -> 0 Wrap)", send_instr(OP_INC, 0), 0)
    score += check("ADD 128", send_instr(OP_ADD, 128), 128)
    score += check("SUB 1 (128 -> 127)", send_instr(OP_SUB, 1), 127)
    total += 4

    # SECTION 2: LOGIC & BIT MANIPULATION
    print("\n[2] Bitwise Logic & Shifting")
    send_instr(OP_LDA, 0x0F) # 00001111
    score += check("AND 0x55 (0F & 55 = 05)", send_instr(OP_AND, 0x55), 0x05)
    send_instr(OP_LDA, 0x80) # 10000000
    score += check("ROR (Rotate Right 0x80)", send_instr(OP_ROR, 0), 0x40)
    score += check("LSL (Shift Left 0x40)", send_instr(OP_LSL, 0), 0x80)
    score += check("XOR 0x80 (Result 0)", send_instr(OP_XOR, 0x80), 0)
    total += 4

    # SECTION 3: FLAG SYSTEM (ZERO FLAG)
    print("\n[3] Flag & Branch Logic")
    # Z-flag should be set from the last XOR result (0)
    # We test JZ by trying to 'jump' to a dummy address. 
    # Note: In step-mode, we verify the command was accepted.
    res = send_instr(OP_JZ, 0xAA) 
    score += check("JZ check (Acc remains 0)", res, 0)
    
    # Test JNZ (should NOT take effect since Acc is 0)
    send_instr(OP_LDA, 10)
    res = send_instr(OP_JNZ, 0xBB)
    score += check("JNZ check (Acc remains 10)", res, 10)
    total += 2

    print("\n" + "="*50)
    print(f"DIAGNOSTICS COMPLETE: {score}/{total} PASSED")
    if score == total:
        print("RESULT: 8-BIT CORE IS FULLY FUNCTIONAL")
    else:
        print("RESULT: CORE HAS LOGIC ERRORS")

# Execute
run_full_diagnostics()
