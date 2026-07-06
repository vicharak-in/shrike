"""
SPONGENT-88 Pure Software Miner (Diagnostic Tool)
-------------------------------------------------
This script replicates the FPGA's physical 45-round logic gates in pure Python.
It is primarily used as a hardware diagnostic "Source of Truth" to prove the 
correctness of the ASIC and to benchmark CPU vs. FPGA hash rates.
"""

import hashlib
import time
import sys

class Spongent88SoftwareMiner:
    def __init__(self):
        # PRESENT 4-bit Substitution Box (Non-linear scrambler)
        self.sbox = [12, 5, 6, 11, 9, 0, 10, 13, 3, 14, 15, 8, 4, 7, 1, 2]

    def hash_nonce(self, prefix_val, nonce):
        """ Executes the 45-round SPONGENT-88 algorithm on a given seed. """
        
        # Construct the 88-bit State: [24-bit Pad] | [32-bit Prefix] | [32-bit Nonce]
        state = ((prefix_val & 0xFFFFFFFF) << 32) | (nonce & 0xFFFFFFFF)
        
        # 45 Total Cycles of the avalanche effect
        for r in range(45):
            # Step 1: Counter Addition (XOR)
            state ^= r
            
            # Step 2: S-Box Substitution (Confusion Layer)
            s_out = 0
            for j in range(22):
                nibble = (state >> (j * 4)) & 0xF
                s_out |= self.sbox[nibble] << (j * 4)
                
            # Step 3: Bit Permutation (Diffusion Layer)
            p_out = 0
            for j in range(44):
                even_bit = (s_out >> (j * 2)) & 1
                odd_bit = (s_out >> (j * 2 + 1)) & 1
                p_out |= (even_bit << j) | (odd_bit << (j + 44))
                
            state = p_out
            
        return state

    def diagnose_hardware_fault(self):
        """ 
        Simulates an all-zero payload. If the FPGA returns this specific nonce, 
        it indicates the hardware driver is transmitting empty SPI frames.
        """
        print("\n[?] RUNNING HARDWARE DIAGNOSTIC TEST...")
        print("[*] Simulating an entirely blank SPI payload (Prefix: 0x00000000, Start Nonce: 0)")
        nonce = 0
        while True:
            h = self.hash_nonce(0x00000000, nonce)
            
            # Check if the top 16 bits of the 88-bit hash are zeros
            if (h >> 72) == 0:
                print(f"[!] Diagnostic Complete. The mathematical nonce for an all-zero seed is: {nonce}\n")
                return nonce
            nonce += 1

    def mine(self, raw_prefix_str, target_zeros=16):
        """ Brute forces the word using the PC's CPU. """
        print("==================================================")
        print("   SPONGENT-88 PURE SOFTWARE MINER (BRUTE FORCE)  ")
        print("==================================================")
        
        # Pre-hash the string to get the hardware fingerprint
        prefix_bytes = hashlib.sha256(raw_prefix_str.encode('utf-8')).digest()[:4]
        prefix_val = int.from_bytes(prefix_bytes, 'big')
        
        print(f"[*] Raw Input       : '{raw_prefix_str}'")
        print(f"[*] Fingerprint Hex : 0x{prefix_val:08X}")
        print(f"[*] Target Zeros    : {target_zeros}")
        print("[*] Mining in Python. Please wait... (This is much slower than your FPGA)\n")
        
        nonce = 1
        start_time = time.time()
        
        while True:
            h = self.hash_nonce(prefix_val, nonce)
            
            # Match condition: Shift right by (88 - target_zeros)
            if (h >> (88 - target_zeros)) == 0:
                elapsed = time.time() - start_time
                hashrate = nonce / elapsed if elapsed > 0 else 0
                
                print(f"\n\n[!] PROOF OF WORK FOUND!")
                print(f"[*] Winning Nonce   : {nonce} (0x{nonce:08X})")
                print(f"[*] Hash Output     : 0x{h:022X}")
                print(f"[*] Time Taken      : {elapsed:.2f} seconds")
                print(f"[*] Python Hashrate : {int(hashrate):,} H/s")
                print("==================================================")
                return nonce
            
            # Live Status Update (throttled to prevent console lag)
            if nonce % 5000 == 0:
                elapsed = time.time() - start_time
                hashrate = nonce / elapsed if elapsed > 0 else 0
                sys.stdout.write(f"\r[*] Searching... Current Nonce: {nonce:,} | Hashrate: {int(hashrate):,} H/s")
                sys.stdout.flush()
                
            nonce += 1

if __name__ == "__main__":
    miner = Spongent88SoftwareMiner()
    
    # 1. Hardware Calibration
    zero_nonce = miner.diagnose_hardware_fault()
    if zero_nonce == 75523:
        print(">>> MYSTERY SOLVED: 75523 IS THE ALL-ZERO NONCE! <<<")
        print(">>> The RP2040 MicroPython SPI driver is sending empty data to the FPGA for certain words! <<<\n")
    
    # 2. Main Execution
    user_input = input("Enter Block Prefix to mine in software (e.g., hola): ")
    miner.mine(user_input, 16)