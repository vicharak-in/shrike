import time
import sys
import uselect
from machine import Pin
import shrike

# Flash the bitstream
shrike.flash("FPGA_bitstream_MCU.bin")

# Hardware Pins
sck = Pin(2, Pin.OUT, value=0)
qio_pins = [Pin(3), Pin(0), Pin(15), Pin(14)]

# ---------------------------------------------------------
# Interrupt Setup
# ---------------------------------------------------------
fpga_needs_attention = False

def cs_irq_handler(pin):
    global fpga_needs_attention
    fpga_needs_attention = True 

cs = Pin(1, Pin.IN, Pin.PULL_UP)
cs.irq(trigger=Pin.IRQ_FALLING, handler=cs_irq_handler)

# ---------------------------------------------------------
# Bit-Banging QSPI Functions
# ---------------------------------------------------------
def set_qio_dir(direction):
    for p in qio_pins: p.init(mode=direction)

def write_nibble(nibble):
    for i in range(4): qio_pins[i].value((nibble >> i) & 0x01)

def read_nibble():
    val = 0
    for i in range(4): val |= (qio_pins[i].value() << i)
    return val

def qspi_exchange(char):
    cs.init(mode=Pin.OUT)
    cs.value(0) 

    ascii_val = ord(char)
    set_qio_dir(Pin.OUT)
    
    write_nibble((ascii_val >> 4) & 0x0F)
    sck.value(1)
    sck.value(0)
    write_nibble(ascii_val & 0x0F)
    sck.value(1)
    sck.value(0)

    set_qio_dir(Pin.IN)
    sck.value(1)
    sck.value(0)

    sck.value(1)
    high = read_nibble()
    sck.value(0)
    sck.value(1)
    low = read_nibble()
    sck.value(0)

    cs.value(1) 
    cs.init(mode=Pin.IN, pull=Pin.PULL_UP)
    
    return (high << 4) | low

# ---------------------------------------------------------
# Setup Non-Blocking Keyboard Input
# ---------------------------------------------------------
poller = uselect.poll()
poller.register(sys.stdin, uselect.POLLIN)

print("\n--- FULLY BIDIRECTIONAL QSPI RUNNING ---")
print("1. Type any characters to convert them to Braille.")
print("2. The FPGA will also interrupt the MCU every 2 seconds.\n")

# ---------------------------------------------------------
# Setup Non-Blocking Keyboard Input
# ---------------------------------------------------------
poller = uselect.poll()
poller.register(sys.stdin, uselect.POLLIN)

print("\n--- FULLY BIDIRECTIONAL QSPI RUNNING ---")
print("1. Click this console window, type a word, and press Enter.")
print("2. The FPGA will also interrupt the MCU every 2 seconds.\n")

# ---------------------------------------------------------
# Unified Event Loop (Line Buffered)
# ---------------------------------------------------------
while True:
    # Event A: FPGA generated a hardware interrupt
    if fpga_needs_attention:
        cs.irq(handler=None) # Disable IRQ
        
        response = qspi_exchange('?') 
        print(f"\n[ASYNC FPGA ALERT] Received Code: 0x{response:02X}")
        
        fpga_needs_attention = Fal