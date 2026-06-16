import time
from machine import Pin
import rp2

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
def _dual_spi_core():
    pull(block)           .side(0)  

    # Transmit Phase (4 Clocks x 2 bits)
    set(pindirs, 3)       .side(0) 
    
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

# ---------------------------------------------------------
# DSPI Class Interface
# ---------------------------------------------------------
class DSPI:
    def __init__(self, cs_pin=1, sck_pin=2, data_base=14, freq=10_000_000, sm_id=0):
        self.cs_pin = Pin(cs_pin, Pin.IN, Pin.PULL_UP)
        self.sck_pin = Pin(sck_pin, Pin.OUT, value=0)
        self.data_base = Pin(data_base)
        
        # Drain physical line capacitance
        for i in range(data_base, data_base + 2):
            Pin(i, Pin.IN, Pin.PULL_DOWN)

        # Initialize PIO
        self.sm = rp2.StateMachine(
            sm_id, _dual_spi_core, freq=freq, 
            sideset_base=self.sck_pin, 
            out_base=self.data_base, 
            in_base=self.data_base, 
            set_base=self.data_base
        )
        self.sm.active(1)
        
        # Async Alert Tracking
        self.fpga_alert_flag = False
        self.cs_pin.irq(trigger=Pin.IRQ_FALLING, handler=self._irq_handler)

    def _irq_handler(self, pin):
        """Internal callback for FPGA initiated communication."""
        self.fpga_alert_flag = True

    def has_alert(self):
        """Check if the FPGA has signaled an async alert."""
        if self.fpga_alert_flag:
            self.fpga_alert_flag = False
            return True
        return False

    def _exchange_byte(self, byte_val):
        """Low-level single byte exchange."""
        self.cs_pin.init(mode=Pin.OUT)
        self.cs_pin.value(0) 
        
        time.sleep_us(5) # FPGA wake up
        
        self.sm.put(byte_val << 24)
        result = self.sm.get() & 0xFF
        
        time.sleep_us(2)
        self.cs_pin.value(1) 
        self.cs_pin.init(mode=Pin.IN, pull=Pin.PULL_UP)
        
        return result

    def transfer(self, data):
        """
        Standardized method for larger projects.
        Sends a string, list of ints, or bytearray.
        Returns a bytearray of the echoed/received data.
        """
        # Convert strings to byte arrays automatically
        if isinstance(data, str):
            data = data.encode('utf-8')
            
        rx_buffer = bytearray(len(data))
        
        # Temporarily disable the IRQ so the MCU doesn't self-interrupt during transmission
        self.cs_pin.irq(handler=None) 
        
        # Note: We toggle CS per byte because the FPGA Verilog FSM 
        # (STATE_TX_4 -> STATE_IDLE) relies on the CS pulse to reset for the next byte.
        for i, byte_val in enumerate(data):
            rx_buffer[i] = self._exchange_byte(byte_val)
            
        # Re-enable the IRQ for async alerts
        self.cs_pin.irq(trigger=Pin.IRQ_FALLING, handler=self._irq_handler)
        
        return rx_buffer