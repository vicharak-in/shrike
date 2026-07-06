from machine import SPI, Pin
import time

# -------------------------------------------------
# SPI Configuration
# -------------------------------------------------

spi = SPI(
    0,
    baudrate=500000,
    polarity=0,
    phase=0,
    bits=8
)

cs = Pin(5, Pin.OUT)
cs.value(1)

# -------------------------------------------------
# Load Dictionary
# -------------------------------------------------

frequency_dict = {}

try:

    with open("top512.txt") as f:

        for line in f:

            line = line.strip()

            if line == "":
                continue

            word, freq = line.split(",")

            frequency_dict[word] = int(freq)

except:

    print("top512.txt not found")

dictionary = set(frequency_dict.keys())

# -------------------------------------------------
# Candidate Generator
# -------------------------------------------------

LETTERS = "abcdefghijklmnopqrstuvwxyz"

def edits1(word):

    splits = [(word[:i], word[i:]) for i in range(len(word)+1)]

    deletes = [L+R[1:] for L,R in splits if R]

    transposes = [L+R[1]+R[0]+R[2:] for L,R in splits if len(R)>1]

    replaces = [L+c+R[1:] for L,R in splits if R for c in LETTERS]

    inserts = [L+c+R for L,R in splits for c in LETTERS]

    return set(

        deletes +

        transposes +

        replaces +

        inserts

    )

# -------------------------------------------------
# Spell Correction
# -------------------------------------------------

def spell(word):

    if word in dictionary:

        return word

    best = word

    best_freq = 0

    for candidate in edits1(word):

        if candidate in dictionary:

            freq = frequency_dict.get(candidate,0)

            if freq > best_freq:

                best_freq = freq

                best = candidate

    return best

# -------------------------------------------------
# FPGA Echo
# -------------------------------------------------

def fpga_echo(word):

    echoed = ""

    #
    # send one byte at a time
    #

    for ch in word:

        tx = bytearray(1)
        rx = bytearray(1)

        tx[0] = ord(ch)

        cs.value(0)

        spi.write_readinto(tx, rx)

        cs.value(1)

        #
        # small delay
        #

        time.sleep_us(100)

        #
        # ignore first pipeline byte
        #

        echoed += chr(rx[0])

    return echoed

# -------------------------------------------------
# Main
# -------------------------------------------------

while True:

    word = input("Word : ")

    corrected = spell(word)

    print()

    print("Corrected :", corrected)

    echoed = fpga_echo(corrected)



    print()