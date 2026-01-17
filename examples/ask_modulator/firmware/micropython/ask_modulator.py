"""
This specific example demonstrates a simple ASK (Amplitude Shift Key) Modulator that sends out "HelloShrike123" with the specified CODEBOOK, as long as the CODEBOOK is no larger than 2^6 (64 bits) the example should work as is.

"""


from machine import Pin
import time

print("Shrike Transmitter: 6-Bit ASK Mode")


# 6-Bit Bus (RP GPIO 5-10)
freq_pins = [
    Pin(5, Pin.OUT),
    Pin(6, Pin.OUT),
    Pin(7, Pin.OUT),
    Pin(8, Pin.OUT),
    Pin(9, Pin.OUT),
    Pin(10, Pin.OUT),
]

# Data Line & Power
data_pin = Pin(16, Pin.OUT)
fpga_power = Pin(12, Pin.OUT)
fpga_enable = Pin(13, Pin.OUT)

# Wake up FPGA
fpga_power.value(1)
time.sleep_ms(10)
fpga_enable.value(1)
time.sleep_ms(10)


CODEBOOK = {
    "H": 1,
    "e": 2,
    "l": 3,
    "o": 4,
    "S": 5,
    "h": 6,
    "r": 7,
    "i": 8,
    "k": 9,
    "1": 51,
    "2": 52,
    "3": 53,
    "*": 60,
    "#": 61,
    " ": 0,
}


def set_tuning_word(value):
    """Sets the Carrier Frequency"""
    if value > 63:
        value = 63
    for i in range(6):
        bit = (value >> i) & 1
        freq_pins[i].value(bit)


def transmit_bit(logic_level):
    """
    Sends a single bit using Amplitude Modulation.
    Duration: 50ms per bit.
    """
    if logic_level == 1:
        data_pin.value(1)  # Carrier ON
    else:
        data_pin.value(0)  # Carrier OFF

    time.sleep_ms(50)


def transmit_char(char):
    """
    Looks up the char, gets the 6-bit code, and sends it.
    Frame: [START 1] + [6 DATA BITS] + [STOP 0]
    """

    if char in CODEBOOK:
        code_val = CODEBOOK[char]
    else:
        code_val = 63  # Error code

    print(f"Sending '{char}' -> Code {code_val:02d} -> {code_val:06b}")

    transmit_bit(1)

    for i in range(5, -1, -1):
        bit = (code_val >> i) & 1
        transmit_bit(bit)

    transmit_bit(0)

    time.sleep_ms(100)


try:
    set_tuning_word(1)

    message = "HelloShrike123"

    while True:
        print(f"\n--- Transmitting: {message} ---")
        for char in message:
            transmit_char(char)

        time.sleep(2)

except KeyboardInterrupt:
    set_tuning_word(0)
    data_pin.value(0)
    print("Stopped.")
