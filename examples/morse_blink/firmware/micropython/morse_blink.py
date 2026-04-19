import time
from machine import UART, Pin
import shrike

# To flash the bitstream to the FPGA
#shrike.flash("morse_blink.bin")

# Initialize UART0 (TX=GPIO0, RX=GPIO1)
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))

def send_byte(value):
    uart.write(bytes([value]))
    
    #print("Sent (hex): 0x{:02X}".format(value))
    #print("Sent (bin): {:08b}".format(value))
    bits = [(value >> i) & 1 for i in range(7, -1, -1)]
    #print("Bits sent:", bits)

def send_morse_string(s: str, dot: float = 0.20, baudrate: int = 115200) -> None:

    # this is essentially just to calculate how long it takes for each
    # of these characters to be blinked by the fpga. 
    # this function basically sends each letter one by one 
    # by waiting the time required for the previous character to finish
    # transmission.
    MORSE = {
        "A": ".-",    "B": "-...",  "C": "-.-.",  "D": "-..",   "E": ".",
        "F": "..-.",  "G": "--.",   "H": "....",  "I": "..",    "J": ".---",
        "K": "-.-",   "L": ".-..",  "M": "--",    "N": "-.",    "O": "---",
        "P": ".--.",  "Q": "--.-",  "R": ".-.",   "S": "...",   "T": "-",
        "U": "..-",   "V": "...-",  "W": ".--",   "X": "-..-",  "Y": "-.--",
        "Z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
    }

    def char_duration(ch: str) -> float:
        up = ch.upper()
        if up not in MORSE:
            return 0.0
        pattern = MORSE[up]
        t = 0.0
        for sym in pattern:
            on = dot if sym == "." else 3 * dot
            off = dot
            t += on + off
        return t + 2 * dot  # safety + "letter gap" feel

    for ch in s:
        if ch == " ":
            time.sleep(7 * dot)
            continue
        send_byte(ord(ch) & 0xFF)
        time.sleep(char_duration(ch))

# EXAMPLE:
# send_morse_string("SOS", dot=0.2)

def morse_loop():
    print("Input something to send in morse.")
    print("Press Ctrl+C to return to REPL.\n")
    
    while True:
        try:
            user_input = input("[morse] ")
            print("Sending your string to FPGA and emitting corresponding Morse code.")
            send_morse_string(user_input)
            print("Finished blinking Morse code.\n")
    
        except KeyboardInterrupt:
            print("\nInterrupted. Returning to REPL.")
            print("You may start this again by calling `morse_loop()`")
            break

morse_loop()
