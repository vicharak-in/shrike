import time
import sys
import uselect
from machine import Pin
import rp2
import shrike

print("Flashing Dual-SPI Core...")
shrike.flash("FPGA_bitstream_MCU.bin")

# ---------------------------------------------------------
# Original Bit-Banging Pins + Dual Data Traces
# ---------------------------------------------------------
cs_pin        = Pin(1, Pin.IN, Pin.PULL_UP)  # FPGA Pin 4 (Original CS)
sck_pin       = Pin(2, Pin.OUT, value=0)     # FPGA Pin 3 (Original Clock)
dual_base_pin = Pin(14)                      # Uses GPIO 14 & 15 (FPGA 18 & 17)

# Drain physical line capacitance on the two data traces
for i in range(14, 16):
    Pin(i, Pin.IN, Pin.PULL_DOWN)

# ---------------------------------------------------------
# The Dual-SPI PIO State Machine 
# ---------------------------------------------------------
@rp2.asm_pio(
    out_shiftdir=rp2.PIO.SHIFT_LEFT, 
    in_shiftdir=rp2.PIO.SHIFT_LEFT,  
    set_init=(rp2.PIO.OUT_LOW, rp2.PIO.OUT_LOW),
    out_init=(rp2.PIO.OUT_LOW, rp2.PIO.OUT_LOW),
    sideset_init=rp2.PIO.OUT_LOW     
)
def dual_spi_core():
    pull(block)           .side(0)  

    # Transmit Phase (4 Clocks x 2 bits)
    set(pindirs, 3)       .side(0) # 3 = Binary 11 (Enable both output drivers)
    
    out(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    out(pins, 2)          .side(0) [1]
    nop()                 .side(1) [1]
    out(pins, 2)          .side(0) [1]
    nop()                 .side(1) [1]
    out(pins, 2)          .side(0) [1]
    nop()                 .side(1) [1]

    # Turnaround Phase
    set(pindirs, 0)       .side(0) [1] 
    nop()                 .side(1) [1] 
    nop()                 .side(0)     

    # Receive Phase (4 Clocks x 2 bits)
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    
    push(block)           .side(0)  

# Initialize PIO
sm = rp2.StateMachine(0, dual_spi_core, freq=10_000_000, sideset_base=sck_pin, out_base=dual_base_pin, in_base=dual_base_pin, set_base=dual_base_pin)
sm.active(1)

# ---------------------------------------------------------
# CS/IRQ Setup
# ---------------------------------------------------------
fpga_needs_attention = False
def cs_irq_handler(pin):
    global fpga_needs_attention
    fpga_needs_attention = True 

cs_pin.irq(trigger=Pin.IRQ_FALLING, handler=cs_irq_handler)

def dual_spi_exchange(char):
    cs_pin.init(mode=Pin.OUT)
    cs_pin.value(0) 
    
    time.sleep_us(5) # Give the FPGA hardware time to wake up

    sm.put(ord(char) << 24)
    result = sm.get()

    time.sleep_us(2)
    cs_pin.value(1) 
    cs_pin.init(mode=Pin.IN, pull=Pin.PULL_UP)
    
    return result & 0xFF

# ---------------------------------------------------------
# Event Loop (Dual-SPI Logic Analyzer)
# ---------------------------------------------------------
poller = uselect.poll()
poller.register(sys.stdin, uselect.POLLIN)

print("\n--- 10 MHz DUAL-SPI LOOPBACK RUNNING ---")
while True:
    if fpga_needs_attention:
        cs_pin.irq(handler=None) 
        response = dual_spi_exchange('?') 
        
        rx_1 = (response >> 6) & 0x03
        rx_2 = (response >> 4) & 0x03
        rx_3 = (response >> 2) & 0x03
        rx_4 = response & 0x03
        
        print(f"\n[ASYNC FPGA ALERT]")
        print(f"  <- RX Clock 6: {rx_1:02b}")
        print(f"  <- RX Clock 7: {rx_2:02b}")
        print(f"  <- RX Clock 8: {rx_3:02b}")
        print(f"  <- RX Clock 9: {rx_4:02b}")
        print(f"  Total Hex: 0x{response:02X}")
        
        fpga_needs_attention = False 
        cs_pin.irq(trigger=Pin.IRQ_FALLING, handler=cs_irq_handler)

    if poller.poll(0): 
        user_line = sys.stdin.readline().strip() 
        
        if user_line:
            print(f"\n========== TRACING INPUT: '{user_line}' ==========")
            for c in user_line:
                ascii_val = ord(c)
                echo_val  = dual_spi_exchange(c)
                
                tx_1 = (ascii_val >> 6) & 0x03
                tx_2 = (ascii_val >> 4) & 0x03
                tx_3 = (ascii_val >> 2) & 0x03
                tx_4 = ascii_val & 0x03
                
                rx_1 = (echo_val >> 6) & 0x03
                rx_2 = (echo_val >> 4) & 0x03
                rx_3 = (echo_val >> 2) & 0x03
                rx_4 = echo_val & 0x03
                
                print(f"\n--- Character: '{c}' (0x{ascii_val:02X}) ---")
                print(f"  [MCU SENT DATA]")
                print(f"  -> TX Clock 1: {tx_1:02b}")
                print(f"  -> TX Clock 2: {tx_2:02b}")
                print(f"  -> TX Clock 3: {tx_3:02b}")
                print(f"  -> TX Clock 4: {tx_4:02b}")
                print(f"  [FPGA ECHOED DATA]")
                print(f"  <- RX Clock 6: {rx_1:02b}")
                print(f"  <- RX Clock 7: {rx_2:02b}")
                print(f"  <- RX Clock 8: {rx_3:02b}")
                print(f"  <- RX Clock 9: {rx_4:02b}")
            print("==================================================\n")
