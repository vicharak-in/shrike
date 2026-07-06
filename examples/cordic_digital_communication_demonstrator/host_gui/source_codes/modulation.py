
import random
from typing import List


# ══════════════════════════════════════════════════════════════
#  BIT-SOURCE GENERATION
# ══════════════════════════════════════════════════════════════
def text_to_bits(text: str) -> List[int]:
    """ASCII text → list of bits (MSB first per byte)."""
    bits: List[int] = []
    for ch in text:
        byte = ord(ch) & 0xFF
        for i in range(7, -1, -1):
            bits.append((byte >> i) & 1)
    return bits


def binary_string_to_bits(text: str) -> List[int]:
    """A string such as '0101 1100' → list of bits. Ignores whitespace."""
    cleaned = "".join(ch for ch in text if ch in "01")
    return [int(ch) for ch in cleaned]


def random_bits(n_bits: int) -> List[int]:
    return [random.randint(0, 1) for _ in range(n_bits)]


def bits_to_text(bits: List[int]) -> str:
    """Inverse of text_to_bits, best-effort (drops incomplete trailing byte)."""
    out = []
    for i in range(0, len(bits) - 7, 8):
        byte = 0
        for b in bits[i:i + 8]:
            byte = (byte << 1) | b
        out.append(chr(byte) if 32 <= byte <= 126 else "·")
    return "".join(out)


# ══════════════════════════════════════════════════════════════
#  MODULATION SYMBOL MAPPING
# ══════════════════════════════════════════════════════════════
# BPSK: 1 bit / symbol  → symbol value is the bit itself (0 or 1)
# QPSK: 2 bits / symbol → symbol value is 0..3 (00,01,10,11)

BITS_PER_SYMBOL = {"BPSK": 1, "QPSK": 2}

# Standard Gray-coded QPSK phase mapping (degrees), purely for the
# on-screen "expected phase" readout — actual SIN/COS always come
# from the FPGA's CORDIC core.
BPSK_PHASE_DEG = {0: 0.0, 1: 180.0}
QPSK_PHASE_DEG = {0b00: 45.0, 0b01: 135.0, 0b10: 225.0, 0b11: 315.0}


def bits_to_symbols(bits: List[int], modulation: str) -> List[int]:
    """Pack a bit list into modulation symbols, zero-padding the tail."""
    n = BITS_PER_SYMBOL[modulation]
    padded = list(bits)
    if len(padded) % n != 0:
        padded += [0] * (n - (len(padded) % n))

    symbols = []
    for i in range(0, len(padded), n):
        chunk = padded[i:i + n]
        val = 0
        for b in chunk:
            val = (val << 1) | b
        symbols.append(val)
    return symbols


def symbol_to_bit_string(symbol: int, modulation: str) -> str:
    n = BITS_PER_SYMBOL[modulation]
    return format(symbol, f"0{n}b")


def expected_phase_deg(symbol: int, modulation: str) -> float:
    if modulation == "BPSK":
        return BPSK_PHASE_DEG.get(symbol, 0.0)
    return QPSK_PHASE_DEG.get(symbol, 0.0)


def manual_symbols_to_list(text: str, modulation: str) -> List[int]:
    """
    Parse a manual symbol entry like '00 11 10 01' (QPSK) or '0 1 1 0' (BPSK)
    into a list of integer symbol values. Tokens may also be unseparated,
    e.g. '00111001' for QPSK is treated as one long bit string and re-chunked.
    """
    n = BITS_PER_SYMBOL[modulation]
    tokens = text.split()
    if tokens and all(set(t) <= {"0", "1"} and len(t) == n for t in tokens):
        return [int(t, 2) for t in tokens]
    # fall back: treat as a raw bit string and rechunk
    bits = binary_string_to_bits(text)
    return bits_to_symbols(bits, modulation)