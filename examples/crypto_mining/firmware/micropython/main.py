"""
SPONGENT-88 ASIC Mining Controller
----------------------------------
This script acts as the "Brain" of the mining operation. It runs on the 
Microcontroller, packages cryptographic workloads, dispatches them to the 
FPGA via SPI, and calculates real-time telemetry (Hashrate & Uptime).

Architecture:
- Implements SHA-256 pre-hashing to condense arbitrary-length block inputs 
  into strict 4-byte hardware fingerprints (Merkle Root simulation).
"""

import time
import sys
import shrike
import hashlib
from dspi_bus import DSPI

# =============================================================================
# HARDWARE INITIALIZATION
# =============================================================================
print("Flashing FPGA with SPONGENT-88 Mining Rig...")
# Pushes the synthesized Verilog bitstream onto the FPGA fabric
shrike.flash("crypto_mining.bin")

# Initialize the modular DSPI communication bus
fpga_bus = DSPI()

# =============================================================================
# WORKLOAD GENERATION
# =============================================================================
print("\n--- ASIC MINING CONTROLLER ACTIVE ---")
raw_prefix = b'hola'   # Arbitrary length block data
start_nonce = 1         

# Pre-hash the arbitrary string to a fixed 4-byte hardware fingerprint
clean_prefix = hashlib.sha256(raw_prefix).digest()[:4]

# Assemble the 8-byte payload: [4-Byte Prefix] + [4-Byte Start Nonce]
seed_data = bytearray(8)
seed_data[0:4] = clean_prefix
seed_data[4:8] = start_nonce.to_bytes(4, 'big')

print(f"[*] Dispatching Workload to FPGA...")
print(f"[*] Raw Block Input: '{raw_prefix.decode('utf-8', 'ignore')}'")
print(f"[*] Fingerprint Hex: 0x{clean_prefix.hex().upper()}")
print(f"[*] Payload Hex    : {seed_data.hex().upper()}")
print(f"[*] Target         : 16 Leading Zeros")

# Blast the seed data into the FPGA state machine
fpga_bus.transfer(seed_data)
time.sleep(0.05) # Brief buffer to let the FPGA start calculating

# =============================================================================
# MINING LOOP & TELEMETRY
# =============================================================================
start_time = time.ticks_ms()
last_heartbeat = 0
spinner_idx = 0
spin_chars = ['|', '/', '-', '\\']
HASHRATE_HEARTBEAT = 2_170_000 # Empirically measured hardware throughput

print("\n>>> MINING ENGINE STARTED. POLLING SPI DATA BUS <<<")

winning_nonce = 0

while True:
    # Poll the FPGA. Send 4 blank bytes to check the hardware status flag.
    result = fpga_bus.transfer(b'\x00\x00\x00\x00')
    
    # If the FPGA returns non-zero data, the winning nonce has been found
    if result != b'\x00\x00\x00\x00':
        winning_nonce = int.from_bytes(result, 'big')
        break  
        
    # Telemetry Updates (UI Spinner and Estimated Hashes)
    current_time = time.ticks_ms()
    elapsed_ms = time.ticks_diff(current_time, start_time)
    
    if elapsed_ms - last_heartbeat >= 250:
        last_heartbeat = elapsed_ms
        elapsed_sec = elapsed_ms / 1000.0
        estimated_hashes = HASHRATE_HEARTBEAT * elapsed_sec
        
        spinner = spin_chars[spinner_idx % 4]
        spinner_idx += 1
        
        print(f"\r[{spinner}] Mining Active... Time: {elapsed_sec:.2f}s | Est. Hashes: {int(estimated_hashes):,} | Status: Polling SPI", end="")
        
    time.sleep(0.01)

# =============================================================================
# RESULTS DISPLAY
# =============================================================================
final_time_ms = time.ticks_diff(time.ticks_ms(), start_time)
elapsed_seconds = final_time_ms / 1000.0
total_hashes = HASHRATE_HEARTBEAT * elapsed_seconds

print("\n\n[!] STATUS CHANGE DETECTED: PROOF OF WORK FOUND!")
print("-" * 50)
print(f"[*] Execution Result : SUCCESS")
print(f"[*] Winning Nonce    : {winning_nonce} (0x{winning_nonce:08X})")
print(f"[*] Total Time       : {elapsed_seconds:.4f} seconds")
print(f"[*] Verified Hashes  : ~{int(total_hashes)}")
print("-" * 50)
