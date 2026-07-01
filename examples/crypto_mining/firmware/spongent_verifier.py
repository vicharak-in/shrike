"""
SPONGENT-88 ASIC Verification Console
-------------------------------------
Because FPGAs are physical "black boxes," environmental noise or timing 
violations can cause them to report false positives. This auditor script 
takes the ASIC's claim and independently mathematically verifies it.
"""

import hashlib

def run_spongent_88(prefix_bytes, nonce):
    """ Runs exactly one cycle of the SPONGENT-88 logic to audit the result. """
    
    # Reconstruct the 64-bit seed exactly as the FPGA registers see it
    prefix_val = int.from_bytes(prefix_bytes, 'big')
    state = (prefix_val << 32) | nonce
    
    sbox = [12, 5, 6, 11, 9, 0, 10, 13, 3, 14, 15, 8, 4, 7, 1, 2]
    
    for r in range(45):
        state ^= r
        
        s_out = 0
        for j in range(22):
            nibble = (state >> (j * 4)) & 0xF
            s_out |= sbox[nibble] << (j * 4)
            
        p_out = 0
        for j in range(44):
            even_bit = (s_out >> (j * 2)) & 1
            odd_bit = (s_out >> (j * 2 + 1)) & 1
            p_out |= (even_bit << j) | (odd_bit << (j + 44))
            
        # Enforce strict 88-bit bounds
        state = p_out & 0xFFFFFFFFFFFFFFFFFFFFFF
        
    return state

# =============================================================================
# CLI INTERFACE
# =============================================================================
print("===========================================")
print(" SPONGENT-88 ASIC VERIFICATION CONSOLE     ")
print("===========================================")

raw_input = input("Enter Block Prefix (Any length allowed): ")
nonce_input = input("Enter Winning Nonce from FPGA: ")
diff_input = input("Enter Target Difficulty (e.g., 16): ")

# Handle Hexadecimal entries
if nonce_input.lower().startswith('0x'):
    winning_nonce = int(nonce_input, 16)
else:
    winning_nonce = int(nonce_input)

target_difficulty = int(diff_input)

# Pre-hash the user's string entry using SHA-256 to match the MCU pipeline
prefix_bytes = hashlib.sha256(raw_input.encode('utf-8')).digest()[:4]

print("\n>>> INITIALIZING HARDWARE VERIFICATION SEQUENCE <<<")
print("===========================================")

final_hash = run_spongent_88(prefix_bytes, winning_nonce)

# Format the 88-bit output structure
hash_hex = f"{final_hash:022X}"
hash_bin = f"{final_hash:088b}"

# Count leading zero bits dynamically
leading_zeros = len(hash_bin) - len(hash_bin.lstrip('0'))

# =============================================================================
# AUDIT RESULTS
# =============================================================================
print("[VERIFICATION RESULTS]")
print(f"Raw Input Block : {raw_input}")
print(f"Compressed Token: 0x{prefix_bytes.hex().upper()}")
print(f"Nonce Value     : {winning_nonce} (0x{winning_nonce:08X})")
print(f"Hash Output     : 0x{hash_hex}")
print(f"Difficulty      : {leading_zeros} Leading Zero Bits")
print(f"Binary Hash     : {hash_bin[:24]}...")

print("\n-------------------------------------------")
if leading_zeros >= target_difficulty:
    print(">>> STATUS: [MATCH] - VALID ASIC PROOF OF WORK! <<<")
else:
    print(">>> STATUS: [MISMATCH] - INVALID HASH <<<")
    print(f">>> Found {leading_zeros} zeros, but required {target_difficulty}. <<<")
print("===========================================")