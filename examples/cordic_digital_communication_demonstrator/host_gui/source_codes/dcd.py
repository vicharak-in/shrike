"""
dcd.py
═══════════════════════════════════════════════════════════════
RP2040 <-> ForgeFPGA SLG47910 CORDIC communication service.

Refactor of the original interactive dcd.py. All FPGA communication
logic for the CORDIC angle path is UNCHANGED and byte-for-byte
identical to the working interactive script: shrike.flash(), the
reset-pin sequence, SPI initialization, and the SPI transaction byte
layout in query() / send_angle() / signed16() / read_results().

MODE:/SYM: (used by the modulation/constellation views) do NOT map to
any native FPGA command -- the bitstream only understands "here is an
angle, give me SIN/COS/TAN". They are implemented purely in software
by converting the requested symbol to its constellation phase angle
and reusing the angle path (see transmit_symbol()).

What changed is only the front end: instead of input()/print()
driving an interactive menu, the board waits forever for line-based
text commands arriving over USB serial from the PyQt6 GUI, and
replies with line-based text responses.

Serial reading note
------------------------------------------------------------------
sys.stdin.readline() is used here. On Shrike-Lite and MicroPython
over USB-CDC, sys.stdin.readline() reliably blocks until a line
terminated by '\\n' is received from the host PC. This avoids
relying on select.poll(), which is often unsupported over USB-CDC.

Serial protocol
------------------------------------------------------------------
GUI -> board                  board -> GUI
  PING                          READY,CORDIC,BPSK,QPSK,1.1
  MODE:BPSK                     OK
  MODE:QPSK                     OK
  SYM:0   (BPSK, 0 or 1)        SIN=<float>
  SYM:01  (QPSK, 00/01/10/11)   COS=<float>
                                 DONE
  ANG:<float_rad>               SIN=<float>
                                 COS=<float>
                                 DONE
  RESET                         OK
  (on error)                    ERR:<message>

Each line is terminated with '\\n'. Every response line is followed
by an explicit stdout flush so the GUI never waits on buffered
output.
"""
import sys
from machine import Pin, SPI
import time

try:
    import shrike
    HAS_SHRIKE = True
except ImportError:
    HAS_SHRIKE = False

FIRMWARE_VERSION = "1.1"


# ══════════════════════════════════════════════════════════════
#  COMMAND BYTES  (unchanged)
# ══════════════════════════════════════════════════════════════
CMD_ANGLE  = 0xA1

CMD_DONE   = 0xA2      # SIN/COS ready flag

CMD_SIN_L  = 0xA3
CMD_SIN_H  = 0xA4

CMD_TAN_DONE = 0xA5    # TAN ready flag (separate from CMD_DONE, unused here)

CMD_COS_L  = 0xA6
CMD_COS_H  = 0xA7

# NOTE: 0xA8 / 0xA9 are the FPGA's TAN_LO / TAN_HI read commands.
# There used to be a CMD_MODE = 0xA8 / CMD_SYMBOL = 0xA9 here, which
# collided with those TAN read commands. The bitstream currently on the
# SLG47910 has no separate "select modulation" or "load symbol" command
# of its own -- it only ever accepts an angle via CMD_ANGLE and returns
# SIN/COS/TAN. MODE:/SYM: are now handled entirely in software below by
# converting the requested symbol into its constellation phase angle and
# driving the existing CORDIC angle path (see transmit_symbol()).

MODE_CODE = {"BPSK": 0, "QPSK": 1}

# Same Gray-coded phase mapping as modulation.py on the GUI side --
# keep these in sync if that table ever changes.
BPSK_PHASE_DEG = {0: 0.0, 1: 180.0}
QPSK_PHASE_DEG = {0b00: 45.0, 0b01: 135.0, 0b10: 225.0, 0b11: 315.0}

# Globals set up by initialize_spi()
cs = None
spi = None
current_mode = None  # "BPSK" or "QPSK", tracked for clarity/diagnostics


# ══════════════════════════════════════════════════════════════
#  FPGA / SPI SETUP  (unchanged logic, just wrapped in functions)
# ══════════════════════════════════════════════════════════════
def initialize_fpga():
    """Flash the FPGA bitstream and pulse the reset pin. Unchanged."""
    if HAS_SHRIKE:
        shrike.flash("FPGA_bitstream_MCU.bin")

    reset_pin = Pin(14, Pin.OUT)
    reset_pin.value(0)
    time.sleep(0.1)
    reset_pin.value(1)
    time.sleep(0.1)


def initialize_spi():
    """Set up the chip-select pin and SPI bus exactly as before."""
    global cs, spi

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


# ══════════════════════════════════════════════════════════════
#  SPI TRANSACTIONS  (byte-for-byte unchanged)
# ══════════════════════════════════════════════════════════════
def query(cmd):

    tx = bytes([cmd, 0, 0])
    rx = bytearray(3)

    cs.value(0)
    spi.write_readinto(tx, rx)
    cs.value(1)

    return rx[2]


def send_angle(angle_rad):
    import math
    angle_rad = angle_rad % (2 * math.pi)
    angle_fixed = int(round(angle_rad * 16384))
    b0 = angle_fixed & 0xFF
    b1 = (angle_fixed >> 8) & 0xFF
    b2 = (angle_fixed >> 16) & 0xFF
    b3 = (angle_fixed >> 24) & 0xFF
    tx = bytes([CMD_ANGLE, b0, b1, b2, b3])
    rx = bytearray(5)
    cs.value(0)
    spi.write_readinto(tx, rx)
    cs.value(1)


def signed16(x):

    if x & 0x8000:
        return x - 65536

    return x


def read_results():

    sin_l = query(CMD_SIN_L)
    sin_h = query(CMD_SIN_H)

    cos_l = query(CMD_COS_L)
    cos_h = query(CMD_COS_H)

    sin_raw = signed16((sin_h << 8) | sin_l)
    cos_raw = signed16((cos_h << 8) | cos_l)

    return sin_raw, cos_raw


# ══════════════════════════════════════════════════════════════
#  TRANSMIT ONE SYMBOL  (same sequence the interactive script used)
# ══════════════════════════════════════════════════════════════
def transmit_symbol(symbol, mode):
    """
    Convert a modulation symbol to its constellation phase angle and
    drive it through the same CORDIC angle path as ANG:/transmit_angle().
    The FPGA has no native "load symbol" command, so this is the only
    way to get real SIN/COS out of it for a given symbol.
    Returns (sin_float, cos_float) or raises TimeoutError.
    """
    import math

    table = BPSK_PHASE_DEG if mode == "BPSK" else QPSK_PHASE_DEG
    phase_deg = table.get(symbol, 0.0)
    angle_rad = math.radians(phase_deg)

    return transmit_angle(angle_rad)


def transmit_angle(angle_rad):
    """
    Send arbitrary angle in radians to the FPGA CORDIC core, wait for DONE, read back SIN/COS.
    Returns (sin_float, cos_float) or raises TimeoutError.
    """
    send_angle(angle_rad)

    timeout = 1000
    while timeout > 0:
        if query(CMD_DONE) & 1:
            break
        time.sleep_ms(1)
        timeout -= 1

    if timeout == 0:
        raise TimeoutError("FPGA did not signal DONE")

    sin_raw, cos_raw = read_results()
    return sin_raw / 16384.0, cos_raw / 16384.0


# ══════════════════════════════════════════════════════════════
#  SERIAL COMMAND PROCESSOR
# ══════════════════════════════════════════════════════════════
def process_command(line):
    """
    Parse one line of text received from the GUI and return the
    text response (without trailing newline). May return a
    multi-line string (e.g. "SIN=...\\nCOS=...\\nDONE").
    """
    global current_mode

    line = line.strip()
    if not line:
        return None

    if line == "PING":
        return "READY,CORDIC,BPSK,QPSK,{}".format(FIRMWARE_VERSION)

    if line == "RESET":
        initialize_fpga()
        current_mode = None
        return "OK"

    if line.startswith("MODE:"):
        requested = line.split(":", 1)[1].strip().upper()
        if requested not in MODE_CODE:
            return "ERR:UNKNOWN_MODE"
        # No SPI transaction here: the FPGA has no mode-select command,
        # it only cares about the angle it's given. This just tells us
        # how to interpret SYM: bit patterns below.
        current_mode = requested
        return "OK"

    if line.startswith("SYM:"):
        if current_mode is None:
            return "ERR:MODE_NOT_SET"

        sym_text = line.split(":", 1)[1].strip()

        if current_mode == "BPSK":
            if sym_text not in ("0", "1"):
                return "ERR:INVALID_SYMBOL"
            symbol = int(sym_text)
        else:  # QPSK
            if sym_text not in ("00", "01", "10", "11"):
                return "ERR:INVALID_SYMBOL"
            symbol = int(sym_text, 2)

        try:
            sin_f, cos_f = transmit_symbol(symbol, current_mode)
        except TimeoutError:
            return "ERR:TIMEOUT"

        return "SIN={:.6f}\nCOS={:.6f}\nDONE".format(sin_f, cos_f)

    if line.startswith("ANG:"):
        try:
            val_str = line.split(":", 1)[1].strip()
            angle_rad = float(val_str)
        except ValueError:
            return "ERR:INVALID_ANGLE"
        try:
            sin_f, cos_f = transmit_angle(angle_rad)
        except TimeoutError:
            return "ERR:TIMEOUT"
        return "SIN={:.8f}\nCOS={:.8f}\nDONE".format(sin_f, cos_f)

    return "ERR:UNKNOWN_COMMAND"


# ══════════════════════════════════════════════════════════════
#  SERIAL LINE READER
# ══════════════════════════════════════════════════════════════
def _read_line():
    """
    Read a complete line from sys.stdin.
    On MicroPython over USB-CDC, sys.stdin.readline() reliably blocks until
    a line terminated by '\\n' or '\\r\\n' is received from the host PC.
    """
    try:
        line = sys.stdin.readline()
        if not line:
            return None
        return line.strip()
    except Exception:
        return None


# ══════════════════════════════════════════════════════════════
#  MAIN SERVICE LOOP
# ══════════════════════════════════════════════════════════════
def main():
    """
    Flash FPGA -> reset FPGA -> init SPI -> print READY ->
    forever: wait for a serial command line, process it, reply.
    Robust to unexpected exceptions in a single command, and
    flushes stdout after every response so the GUI never blocks
    on buffered output.
    """
    initialize_fpga()
    initialize_spi()

    print("READY,CORDIC,BPSK,QPSK,{}".format(FIRMWARE_VERSION))
    if hasattr(sys.stdout, "flush"):
        sys.stdout.flush()

    while True:
        line = _read_line()
        if line is None:
            continue

        print("RX:", line)
        if hasattr(sys.stdout, "flush"):
            sys.stdout.flush()

        try:
            response = process_command(line)
            if response is not None:
                print(response)
                if hasattr(sys.stdout, "flush"):
                    sys.stdout.flush()

        except Exception as e:
            print("ERR:{}".format(e))
            if hasattr(sys.stdout, "flush"):
                sys.stdout.flush()
            


if __name__ == "__main__":
    main()
