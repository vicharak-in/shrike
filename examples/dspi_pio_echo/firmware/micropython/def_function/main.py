import time
import shrike
from dspi_bus import DSPI

print("Flashing FPGA...")
shrike.flash("FPGA_bitstream_MCU.bin")

# 1. Initialize the bus (Uses default pins 1, 2, 14, 15 at 10MHz)
fpga_bus = DSPI()

print("Bus initialized. Sending one-time test packet...")

# ---------------------------------------------------------
# ONE-TIME TRANSMISSION
# ---------------------------------------------------------
tx_string = "hello, how Are you?"
rx_data = fpga_bus.transfer(tx_string)

print(f"Sent: {tx_string}")
print(f"Received (Hex): {[hex(b) for b in rx_data]}")

print("\nEntering listening mode for FPGA alerts (Press Ctrl+C to stop)...")

# ---------------------------------------------------------
# CONTINUOUS LISTENING LOOP
# ---------------------------------------------------------
while True:
    # Check if the FPGA triggered the IRQ pin
    if fpga_bus.has_alert():
        # Read the alert code by sending a dummy byte
        alert_data = fpga_bus.transfer([ord('?')]) 
        print(f"[ALERT] FPGA initiated communication: {hex(alert_data[0])}")

    # Sleep briefly to yield CPU time, keeping it highly responsive to IRQs
    time.sleep(0.1)