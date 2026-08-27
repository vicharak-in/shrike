#!/usr/bin/env python3
"""serv_shell.py -- robust interactive host-side terminal for the SERV monitor.

Runs on your computer (needs pyserial: `pip install pyserial`). It brings the
board up -- flashes the shrike_serv bitstream, streams monitor.bin into the CPU,
switches the shared pins to the UART -- then gives you a `serv>` prompt: type a
command, it goes to the CPU over the FPGA UART, the answer comes back.

    ./serv_shell.py                     # auto-detect the board
    ./serv_shell.py --port /dev/cu.usbmodemXXXX

Type `quit` (or Ctrl-D / Ctrl-C) to exit. On first run it uploads the bitstream
and builds + uploads monitor.bin automatically, so a fresh board needs no setup
(building monitor.bin needs a riscv gcc; the bitstream is shipped in the repo).

The Shrike-lite's USB link can drop intermittently (a marginal cable/port browns
out the board mid-session). This shell survives it: on a drop it waits for the
board to re-enumerate, re-flashes and reconnects automatically, then hands the
prompt back -- so a session keeps working even across drops. For a drop-free
experience use a short data-grade cable straight into the machine (or a powered
hub).

Why host-side: the RP2040's UART0 talks to the FPGA, not to USB, so something has
to shuttle bytes between them. Doing it here -- over the MicroPython REPL, one
line at a time -- is simpler and steadier than a board-side USB<->UART bridge.
"""
import argparse, glob, os, shutil, subprocess, sys, time
try:
    import serial
except ImportError:
    sys.exit("pyserial is required:  pip install pyserial   (or: pip3 install pyserial)")
try:
    # arrow-key history for input() below; this shell reads whole lines, so the
    # monitor's own history never sees the arrow keys (see COMMANDS.md)
    import readline                                   # noqa: F401
except ImportError:
    pass

# Every way a vanished USB device can surface from pyserial / the OS. termios.error
# (from tcflush on a dropped device) is NOT an OSError, so it must be listed too.
DROP_ERRORS = (OSError, serial.SerialException)
try:
    import termios
    DROP_ERRORS = DROP_ERRORS + (termios.error,)
except ImportError:                             # non-POSIX (e.g. Windows)
    pass

# Repo files are found relative to THIS script, so serv_shell.py runs from any cwd.
HERE = os.path.dirname(os.path.abspath(__file__))
REPO_BITSTREAM = os.path.join(HERE, "..", "bitstream", "shrike_serv.bin")
MONITOR_C = os.path.join(HERE, "monitor.c")

# board-side setup: flash, load monitor.bin, hand the shared pins to UART0, and
# define _send(line) which writes a line to the CPU and prints its reply.
SETUP = r"""
import time
from machine import Pin, SPI, UART
import shrike
shrike.flash('shrike_serv.bin')
time.sleep(1)
_spi = SPI(0, baudrate=1000000, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
           sck=Pin(2), mosi=Pin(3), miso=Pin(0))
_cs = Pin(1, Pin.OUT, value=1)
def _c(b):
    _cs.value(0); _spi.write(bytes([b])); _cs.value(1)
_f = open('monitor.bin','rb'); _img = _f.read(); _f.close()
_img = (_img + b'\x00'*4096)[:4096]
_c(0xA3); _c(0xA0); _cs.value(0); _spi.write(_img); _cs.value(1); _c(0xA2)
_spi.deinit(); _cs.init(Pin.IN); time.sleep_ms(50)
uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1), timeout=50)
def _drain(ms=250):
    # read until the line is quiet for `ms` (resets the timer on every byte), so
    # a banner/stale output still mid-transmission is fully cleared -- a one-shot
    # 'while uart.any()' would miss bytes that arrive during the drain.
    t = time.ticks_ms()
    while time.ticks_diff(time.ticks_ms(), t) < ms:
        if uart.any():
            uart.read(); t = time.ticks_ms()
        else:
            time.sleep_ms(5)
time.sleep_ms(300)
_drain(400)                            # clear boot banner + pin-handover glitch + stale
def _readprompt(wait):
    # accumulate until the monitor is idle at a prompt ('serv> ' or '? ') with a
    # short quiet window, or `wait` ms elapse (a long compute prints nothing until
    # it finishes, so wait must be generous). Returns (text, saw_prompt).
    t0 = time.ticks_ms(); last = t0; buf = b''
    while time.ticks_diff(time.ticks_ms(), t0) < wait:
        n = uart.any()
        if n:
            buf += uart.read(n); last = time.ticks_ms()
        else:
            if (buf.endswith(b'serv> ') or buf.endswith(b'? ')) and \
               time.ticks_diff(time.ticks_ms(), last) > 80:
                return bytes(c for c in buf if c < 128).decode(), True
            time.sleep_ms(5)
    return bytes(c for c in buf if c < 128).decode(), False
def _send(line, wait=60000):
    _drain(120)                            # clear any stale bytes before sending
    for ch in line + '\r':
        uart.write(ch); time.sleep_ms(6)   # paced like typing (no RX overrun)
    t, ok = _readprompt(wait)
    print(('P' if ok else 'T') + t)        # 1st char: P=at prompt, T=timed out
def _resync(wait=60000):                    # catch up if a prior command overran
    t, ok = _readprompt(wait)
    print(('P' if ok else 'T') + t)
print('READY')
"""


class Dropped(Exception):
    """The USB serial link went away mid-operation."""


def list_ports():
    # RP2040 CDC shows up as /dev/cu.usbmodem* on macOS and /dev/ttyACM* on Linux.
    return sorted(glob.glob("/dev/cu.usbmodem*") + glob.glob("/dev/ttyACM*"))


def find_port(preferred=None):
    ports = list_ports()
    if preferred and preferred in ports:
        return preferred
    return ports[0] if ports else None


def wait_for_port(preferred=None, timeout=60, announce=False):
    end = time.time() + timeout
    while time.time() < end:
        p = find_port(preferred)
        if p:
            if announce:
                sys.stdout.write("\n"); sys.stdout.flush()
            time.sleep(1.0)          # let the CDC settle after enumeration
            return p
        if announce:                 # heartbeat so a reconnect wait isn't silent
            sys.stdout.write("."); sys.stdout.flush()
        time.sleep(0.5)
    return None


class Board:
    def __init__(self, port):
        self.port = port
        self.s = None

    # -- low-level, all raising Dropped on a vanished device -----------------
    def _open(self):
        try:
            self.s = serial.Serial(self.port, 115200, timeout=0.2)
            self.s.dtr = True                   # RP2040 CDC needs DTR asserted
        except DROP_ERRORS:
            raise Dropped() from None                     # port vanished between detect and open
        time.sleep(0.3)

    def _read_until(self, marker, timeout):
        end = time.time() + timeout
        buf = b""
        while time.time() < end:
            try:
                c = self.s.read(4096)
            except DROP_ERRORS:
                raise Dropped() from None
            if c:
                buf += c
                if marker in buf:
                    return buf
            else:
                time.sleep(0.005)
        return buf

    def _write(self, data):
        try:
            self.s.write(data)
        except DROP_ERRORS:
            raise Dropped() from None

    def _enter_raw(self):
        self._write(b"\r\x03\x03"); time.sleep(0.2)
        try:
            self.s.reset_input_buffer()
        except DROP_ERRORS:
            raise Dropped() from None
        self._write(b"\r\x01"); self._read_until(b"raw REPL", 3); self._read_until(b">", 1)

    def exec(self, code, timeout=60):
        try:
            self.s.reset_input_buffer()
        except DROP_ERRORS:
            raise Dropped() from None
        self._write(code.encode() + b"\x04")
        buf = self._read_until(b"\x04\x04", timeout)
        if b"\x04\x04" not in buf:               # never saw the end markers -> link died
            raise Dropped() from None
        if buf.startswith(b"OK"):
            buf = buf[2:]
        return buf.split(b"\x04")[0].decode(errors="replace")

    def listdir(self):
        return self.exec("import os\nprint(os.listdir())", timeout=10)

    def put(self, local, dest):
        with open(local, "rb") as f:
            data = f.read()
        self.exec("f=open(%r,'wb')" % dest)
        for i in range(0, len(data), 512):
            self.exec("f.write(%r)" % data[i:i + 512])
        self.exec("f.close()")
        return len(data)

    # -- connect + run the board-side setup, retrying across drops -----------
    def connect(self, provisioner=None):
        for _attempt in range(6):
            try:
                self._open()
                self._enter_raw()
                if provisioner:
                    provisioner(self)            # upload bitstream/monitor if missing
                r = self.exec(SETUP, timeout=30)
                if "READY" in r:
                    return True
            except Dropped:
                pass
            self._safe_close()
            p = wait_for_port(self.port, timeout=20, announce=True)
            if not p:
                return False                     # no board present -> stop (no long hang)
            self.port = p
        return False

    def _safe_close(self):
        if self.s:
            try:
                self.s.close()
            except Exception:
                pass
            self.s = None

    def close(self):
        if self.s:
            try:
                self.s.write(b"\r\x02")
            except Exception:
                pass
        self._safe_close()


def build_monitor():
    """Compile monitor.c -> monitor.bin (in /tmp). Needs a riscv gcc."""
    rv = None
    for p in ("riscv64-elf-gcc", "riscv32-unknown-elf-gcc",
              "riscv64-unknown-elf-gcc", "riscv-none-elf-gcc"):
        if shutil.which(p):
            rv = p[:-3]; break
    if not rv:
        sys.exit("monitor.bin isn't on the board and no riscv gcc was found to build it.\n"
                 "Install a riscv toolchain, or copy a prebuilt monitor.bin to the board.")
    elf, binf = "/tmp/monitor.elf", "/tmp/monitor.bin"
    try:
        # keep these flags in step with run.py's compile_program()
        subprocess.run([rv + "gcc", "-Os", "-march=rv32i", "-mabi=ilp32", "-ffreestanding",
                        "-nostdlib", "-ffunction-sections", "-fdata-sections",
                        "-T", os.path.join(HERE, "link.ld"), "-Wl,--gc-sections",
                        os.path.join(HERE, "crt0.S"), os.path.join(HERE, "nolibc.c"),
                        MONITOR_C, "-lgcc", "-o", elf], check=True)
        subprocess.run([rv + "objcopy", "-O", "binary", elf, binf], check=True)
    except subprocess.CalledProcessError:
        sys.exit("failed to build monitor.bin from monitor.c (see the compiler error above).")
    return binf


def provision(board):
    """Ensure the board has shrike_serv.bin + monitor.bin; upload any that are missing."""
    fs = board.listdir()
    if "shrike_serv.bin" not in fs:
        if not os.path.exists(REPO_BITSTREAM):
            sys.exit("board is missing shrike_serv.bin and it's not at %s" % REPO_BITSTREAM)
        print("uploading shrike_serv.bin to the board (one-time)...")
        board.put(REPO_BITSTREAM, "shrike_serv.bin")
    if "monitor.bin" not in fs:
        print("building + uploading monitor.bin (one-time)...")
        board.put(build_monitor(), "monitor.bin")


def bringup(board):
    print("Bringing up SERV monitor...")
    if not board.connect(provisioner=provision):
        sys.exit("could not reach the board. Check: the USB cable/port; that no other\n"
                 "program is using it (close Thonny / mpremote); and that it is running\n"
                 "Shrike MicroPython (not the XIP firmware -- reflash MicroPython if so).")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", default=None)
    a = ap.parse_args()
    board = None
    # One handler for the whole run: Ctrl-C / Ctrl-D anywhere -- waiting for a
    # board, bringing it up, at the prompt, mid-command, or mid-reconnect --
    # exits cleanly, never a traceback.
    try:
        port = a.port or find_port()
        if not port:
            print("waiting for a board... (Ctrl-C to quit)")
            port = wait_for_port(timeout=15, announce=True)
        if not port:
            sys.exit("no board found (looked for /dev/cu.usbmodem* and /dev/ttyACM*).\n"
                     "connect the Shrike-Lite, or pass --port. On Linux you may need to be\n"
                     "in the 'dialout' group (sudo usermod -aG dialout $USER, then re-login).")

        board = Board(port)
        bringup(board)
        print("Connected on %s." % board.port)   # actual port (may differ if it fell back)
        print("Ready. Type a command (help, fib 20, primes 100, guess, led on, ...).")
        print("Exit with 'quit', Ctrl-D, or Ctrl-C.\n")

        prompt = "serv> "
        while True:
            line = input(prompt).strip()
            if line in ("quit", "exit"):
                break
            try:
                out = board.exec("_send(%r)" % line, timeout=90)
                # 1st char is the status flag (P=at prompt, T=timed out mid-run).
                # On T, the CPU is still computing -- wait for it rather than
                # firing the next command into a busy monitor (which would desync).
                stalls = 0
                while out[:1] == "T":
                    stalls += 1
                    if stalls > 4:               # ~6 min: the monitor is stuck, not slow
                        print("[monitor not responding -- it may have crashed "
                              "(e.g. a poke into its own code). Re-run to reload it.]")
                        return
                    print("[still working...]")
                    out = board.exec("_resync()", timeout=90)
            except Dropped:
                print("\n[link dropped -- waiting for the board to reconnect; "
                      "Ctrl-C to quit]")
                board._safe_close()
                if not board.connect(provisioner=provision):
                    print("could not reconnect. Check the cable/port and that nothing else\n"
                          "is using it (Thonny / mpremote).")
                    break
                print("[reconnected]\n")
                prompt = "serv> "
                continue
            body = out[1:].replace("\r\n", "\n").rstrip("\n")   # drop status flag + _send's \n
            prompt = "? " if body.endswith("? ") else "serv> "  # '? ' = guess wants input
            # strip the trailing prompt, then the leading echo of the typed command;
            # what remains is exactly the monitor's output for this command.
            if body.endswith("serv> "):
                body = body[:-6]
            elif body.endswith("? "):
                body = body[:-2]
            body = body.rstrip("\n")
            nl = body.find("\n")
            first = body if nl < 0 else body[:nl]
            if first.strip() == line:                            # drop the command echo
                body = "" if nl < 0 else body[nl + 1:]
            if body:
                print(body)
    except (EOFError, KeyboardInterrupt):
        print("\nbye")
    finally:
        if board:
            board.close()


if __name__ == "__main__":
    main()
