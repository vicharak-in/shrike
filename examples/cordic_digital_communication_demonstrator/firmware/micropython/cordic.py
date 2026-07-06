import shrike
from machine import Pin, SPI
import time
import math

shrike.flash("FPGA_bitstream_MCU.bin")

reset_pin = Pin(14, Pin.OUT)
reset_pin.value(0)
time.sleep(0.1)
reset_pin.value(1)
time.sleep(0.1)

cs = Pin(1, Pin.OUT, value=1)

spi = SPI(
    0,
    baudrate=100000,
    polarity=0,
    phase=0,
    bits=8,
    firstbit=SPI.MSB,
    sck=Pin(2),
    mosi=Pin(3),
    miso=Pin(0)
)


def query(cmd):
    tx = bytes([cmd, 0, 0])
    rx = bytearray(3)
    cs.value(0)
    spi.write_readinto(tx, rx)
    cs.value(1)
    return rx[2]


def send_angle(angle_rad):
    angle_rad = angle_rad % (2 * math.pi)

    angle_fixed = int(round(angle_rad * 16384))

    b0 = angle_fixed & 0xFF
    b1 = (angle_fixed >> 8) & 0xFF
    b2 = (angle_fixed >> 16) & 0xFF
    b3 = (angle_fixed >> 24) & 0xFF

    tx = bytes([0xA1, b0, b1, b2, b3])
    rx = bytearray(5)

    cs.value(0)
    spi.write_readinto(tx, rx)
    cs.value(1)


def signed16(x):
    if x & 0x8000:
        return x - 65536
    return x


print("\nCORDIC ====================")

while True:

    print()

    mode = input("Angle Mode: ").strip().upper()

    if mode == "E":
        print("\nProgram terminated.")
        break

    if mode not in ("D", "R"):
        print("Invalid selection.")
        continue

    degree_mode = (mode == "D")

    value = input("Enter the Angle: ").strip()

    if value.upper() == "E":
        print("\nProgram terminated.")
        break

    try:
        angle = float(value)
    except ValueError:
        print("Invalid angle.\n")
        continue

    if degree_mode:
        angle_deg = angle % 360.0
        angle_rad = math.radians(angle_deg)
    else:
        angle_rad = angle % (2 * math.pi)
        angle_deg = math.degrees(angle_rad)

    send_angle(angle_rad)

    # -----------------------------
    # Wait for SIN/COS completion
    # -----------------------------
    timeout = 1000

    while timeout > 0:
        status = query(0xA2)
        if status & 1:
            break
        time.sleep_ms(1)
        timeout -= 1

    if timeout == 0:
        print("CORDIC Timeout\n")
        continue

    # -----------------------------
    # Wait for TAN completion
    # -----------------------------
    timeout = 1000

    while timeout > 0:
        status = query(0xA5)
        if status & 1:
            break
        time.sleep_ms(1)
        timeout -= 1

    if timeout == 0:
        print("TAN Timeout\n")
        continue

    # -----------------------------
    # Read SIN
    # -----------------------------
    sin_l = query(0xA3)
    sin_h = query(0xA4)

    # -----------------------------
    # Read COS
    # -----------------------------
    cos_l = query(0xA6)
    cos_h = query(0xA7)

    # -----------------------------
    # Read TAN
    # -----------------------------
    tan_l = query(0xA8)
    tan_h = query(0xA9)

    # -----------------------------
    # Convert to signed integers
    # -----------------------------
    sin_raw = signed16((sin_h << 8) | sin_l)
    cos_raw = signed16((cos_h << 8) | cos_l)
    tan_raw = signed16((tan_h << 8) | tan_l)

    # -----------------------------
    # Convert from Q1.14
    # -----------------------------
    sin_fpga = sin_raw / 16384.0
    cos_fpga = cos_raw / 16384.0
    tan_fpga = tan_raw / 16384.0

    # -----------------------------
    # Software reference
    # -----------------------------
    expected_sin = math.sin(angle_rad)
    expected_cos = math.cos(angle_rad)

    if abs(expected_cos) < 1e-12:
        expected_tan = float("inf")
    else:
        expected_tan = math.tan(angle_rad)

    if abs(expected_sin) < 1e-6:
        expected_sin = 0.0

    if abs(expected_cos) < 1e-6:
        expected_cos = 0.0

    print()
    print("Angle Mode        : {}".format("Degree" if degree_mode else "Radian"))

    if degree_mode:
        print("Angle             : {:.4f}°".format(angle_deg))
    else:
        print("Angle             : {:.6f} rad".format(angle_rad))

    print()
    print("Calculated Values")
    print("-----------------")
    print("SIN               : {:.8f}".format(sin_fpga))
    print("COS               : {:.8f}".format(cos_fpga))

    if abs(cos_fpga) < 1e-6:
        print("TAN               : Infinity")
    else:
        print("TAN               : {:.8f}".format(tan_fpga))

    print()
    print("Expected Values")
    print("---------------")
    print("SIN               : {:.8f}".format(expected_sin))
    print("COS               : {:.8f}".format(expected_cos))

    if expected_tan == float("inf"):
        print("TAN               : Infinity")
    else:
        print("TAN               : {:.8f}".format(expected_tan))

    print()
    print("=" * 40)