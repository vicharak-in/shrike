"""
DSPI (Dual-SPI) PIO Driver for RP2040
-------------------------------------
This module manages high-speed hardware communication between the RP2040 MCU 
and the FPGA using the RP2040's Programmable I/O (PIO) state machines.

Key Engineering Features:
1. Hardware Queue Flushing: Purges stale data left in the TX/RX FIFOs from 
   MicroPython soft-reboots, preventing "ghost" payloads.
2. Sign-Bit Override: Uses the 'struct' library to safely pack bytes into 
   unsigned 32-bit C-integers, completely bypassing MicroPython's 31-bit 
   signed integer limit that causes silent memory crashes.
"""

import time
import struct
from machine import Pin
import rp2

# =============================================================================
# PIO STATE MACHINE DEFINITION
# =============================================================================
@rp2.asm_pio(
    out_shiftdir=rp2.PIO.SHIFT_LEFT, 
    in_shiftdir=rp2.PIO.SHIFT_LEFT,  
    set_init=(rp2.PIO.OUT_LOW, rp2.PIO.OUT_LOW),
    out_init=(rp2.PIO.OUT_LOW, rp2.PIO.OUT_LOW),
    sideset_init=rp2.PIO.OUT_LOW     
)
def _dual_spi_core():
    """ 
    Assembly-level instructions for the RP2040 PIO.
    Operates a custom half-duplex Dual-SPI protocol.
    """
    pull(block)           .side(0)  
    
    set(pindirs, 3)       .side(0) 
    
    # Transmit 8 bits (4 pairs of 2 bits)
    out(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    out(pins, 2)          .side(0) [1]
    nop()                 .side(1) [1]
    out(pins, 2)          .side(0) [1]
    nop()                 .side(1) [1]
    out(pins, 2)          .side(0) [1]
    nop()                 .side(1) [1]

    # Switch pin directions from OUT to IN
    set(pindirs, 0)       .side(0) [1] 
    nop()                 .side(0) [1] 

    # Receive 8 bits (4 pairs of 2 bits)
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    nop()                 .side(1) [1] 
    in_(pins, 2)          .side(0) [1] 
    
    push(block)           .side(0)  


# =============================================================================
# HARDWARE CONTROLLER CLASS
# =============================================================================
class DSPI:
    def __init__(self, cs_pin=1, sck_pin=2, data_base=14, freq=10_000_000, sm_id=0):
        # Initialize physical pins
        self.cs_pin = Pin(cs_pin, Pin.OUT, value=1) # Chip Select active LOW
        self.sck_pin = Pin(sck_pin, Pin.OUT, value=0)
        self.data_base = Pin(data_base)
        
        for i in range(data_base, data_base + 2):
            Pin(i, Pin.IN, Pin.PULL_DOWN)

        # Initialize and restart the PIO State Machine
        self.sm = rp2.StateMachine(
            sm_id, _dual_spi_core, freq=freq,  
            sideset_base=self.sck_pin,  
            out_base=self.data_base,  
            in_base=self.data_base,  
            set_base=self.data_base
        )
        self.sm.restart() 
        self.sm.active(1)
        
        # FIX: Hard flush of TX/RX hardware queues to clear MicroPython cache
        while self.sm.rx_fifo():
            self.sm.get()
        for _ in range(8):
            self.sm.put(0)
            self.sm.get()

    def transfer(self, data):
        """
        Sends an array of bytes to the FPGA and returns the hardware response.
        """
        if isinstance(data, str):
            data = data.encode('utf-8')
            
        rx_buffer = bytearray(len(data))
        
        # Clear receiver queue before transaction
        while self.sm.rx_fifo():
            self.sm.get()
        
        # Assert Chip Select (CS) LOW to begin transaction
        self.cs_pin.value(0)
        time.sleep_us(5) 
        
        for i, byte_val in enumerate(data):
            # FIX: Safely pack bytes into standard C-style 32-bit unsigned integers
            # This prevents MicroPython sign-bit overflows on bytes like 0xB2.
            safe_32bit_word = struct.unpack('>I', bytes([byte_val, 0, 0, 0]))[0]
            
            self.sm.put(safe_32bit_word)
            rx_buffer[i] = self.sm.get() & 0xFF
            
        time.sleep_us(2)
        # Assert Chip Select (CS) HIGH to end transaction
        self.cs_pin.value(1)
        time.sleep_us(10) 
        
        return rx_buffer