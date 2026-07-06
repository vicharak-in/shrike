"""
serial_manager.py
═══════════════════════════════════════════════════════════════
Low-level, single-threaded serial transport for CORDIC demonstrator.
Line protocol
  Commands are sent as UTF-8 text terminated with \n.
  The reader accumulates raw bytes from the port on every poll tick
  and splits on \n, emitting one clean string per complete line.
"""
import time
import traceback

from PyQt6.QtCore import QObject, pyqtSignal, QTimer

try:
    import serial
    HAS_PYSERIAL = True
except ImportError:
    HAS_PYSERIAL = False


class SerialManager(QObject):
    """Single-threaded, timer-polled serial transport for CORDIC demonstrator."""

    line_received   = pyqtSignal(str)    # one clean line per emission
    connection_lost = pyqtSignal(str)
    log_message     = pyqtSignal(str, str)

    def __init__(self):
        super().__init__()
        self._ser      = None
        self.port_name = None
        self._rx_buf   = b""   # accumulates partial lines across poll ticks
        self.history   = []    # records (timestamp, direction, text) of all TX/RX
        self._timer    = QTimer(self)
        self._timer.setInterval(20)
        self._timer.timeout.connect(self._poll_serial)

    # ── Connection ───────────────────────────────────────────
    def is_connected(self) -> bool:
        return self._ser is not None and self._ser.is_open

    def connect(self, port: str, baud: int = 115200) -> bool:
        """Open the serial port and start QTimer polling loop.
        Returns True on success (port opened), False on error.
        """
        if not HAS_PYSERIAL:
            self.log_message.emit("pyserial is not installed.", "error")
            return False
        if self.is_connected():
            self.disconnect()
        try:
            self.port_name = port
            self._ser = serial.Serial(
                port=port,
                baudrate=baud,
                timeout=0.05
            )
            self._ser.dtr = True
            self._ser.rts = True
            time.sleep(0.1)
            # 1. Interrupt any running script (like main.py)
            self._ser.write(b"\x03\x03")
            self._ser.flush()
            time.sleep(0.2)  # Wait for traceback to finish printing
            # 2. Exit Raw REPL mode if trapped by Thonny
            self._ser.write(b"\x02")
            self._ser.flush()
            time.sleep(0.1)
            # 3. Soft-reboot to run main.py cleanly from boot
            self._ser.write(b"\x04")
            self._ser.flush()
            # Do NOT reset input buffer here: preserving incoming bytes in the
            # OS receive buffer ensures the startup banner (READY,CORDIC,...)
            # printed by the MCU at boot/connect is not discarded.
            self._ser.reset_output_buffer()
        except Exception as e:
            self.log_message.emit(f"Could not open {port}: {e}", "error")
            self._ser = None
            return False

        self._rx_buf = b""
        self._timer.start()
        time.sleep(0.1)
        self.log_message.emit(f"Port {port} opened @ {baud} baud.", "info")
        return True

    def disconnect(self):
        self._timer.stop()
        self._rx_buf = b""
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass
            self._ser = None
        self.log_message.emit("Port closed.", "info")

    # ── I/O ──────────────────────────────────────────────────
    def write_line(self, text: str) -> bool:
        """Send one ASCII command terminated with \n (UTF-8)."""
        if not self.is_connected():
            return False
        try:
            print(f"TX -> {text}")
            self.history.append((time.time(), "TX", text))
            self.log_message.emit(f"TX -> {text}", "tx")
            self._ser.write((text + "\r\n").encode("utf-8"))
            self._ser.flush()
            return True
        except Exception as e:
            self.log_message.emit(f"Write error: {e}", "error")
            self._handle_disconnect(str(e))
            return False

    # ── Polling Loop ──────────────────────────────────────────
    def _poll_serial(self):
        """
        Single-threaded serial polling loop executing on QTimer.

        FIX: previously this called self._ser.readline() in a loop, which
        uses the port's *read* timeout (0.05s) to decide when to give up
        looking for '\n'. If a line's bytes arrived split across two USB
        packets (very common with the RP2040's USB-CDC driver on longer
        multi-line replies such as "SIN=...\nCOS=...\nDONE"), readline()
        could return a line with no trailing '\n' -- i.e. a truncated
        fragment -- and the remaining bytes would then be mis-parsed as
        the start of an unrelated line on the next tick. That intermittently
        corrupted the SIN/COS/DONE and MODE OK responses, which is exactly
        the "communication randomly fails" symptom.

        The fix: pull in *all* currently available bytes with one non-
        blocking read, append them to a persistent buffer, and only ever
        emit text up to a '\n'. Any leftover partial line is kept in
        self._rx_buf and completed on a later tick -- so a line is never
        split or truncated, no matter how the OS chooses to chunk it.
        """
        if not self.is_connected():
            return
        try:
            n = self._ser.in_waiting
            if not n:
                return
            self._rx_buf += self._ser.read(n)

            while b"\n" in self._rx_buf:
                raw_line, self._rx_buf = self._rx_buf.split(b"\n", 1)
                decoded = raw_line.decode("utf-8", errors="ignore").strip()
                if decoded:
                    print(f"RX <- {decoded}")
                    self.history.append((time.time(), "RX", decoded))
                    self.log_message.emit(f"RX <- {decoded}", "rx")
                    self.line_received.emit(decoded)

            # Check if remaining buffer contains interactive prompts without trailing \n
            # (such as input("Angle Mode: "), input("Enter the Angle: "), or REPL ">>> ")
            if self._rx_buf:
                decoded_partial = self._rx_buf.decode("utf-8", errors="ignore").strip()
                if any(prompt in decoded_partial for prompt in ("Angle Mode", "Enter the Angle", ">>>", "Angle Mode (D/R/E):", "Angle Mode (D/R):", "Invalid selection")):
                    print(f"RX <- {decoded_partial}")
                    self.history.append((time.time(), "RX", decoded_partial))
                    self.log_message.emit(f"RX <- {decoded_partial}", "rx")
                    self.line_received.emit(decoded_partial)
                    self._rx_buf = b""
        except Exception as e:
            traceback.print_exc()
            self._handle_disconnect(str(e))

    def _handle_disconnect(self, reason: str):
        self._timer.stop()
        self._rx_buf = b""
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass
            self._ser = None
        self.connection_lost.emit(reason)