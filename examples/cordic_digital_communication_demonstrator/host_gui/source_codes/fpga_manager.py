"""
fpga_manager.py
GUI-side driver communicating with the RP2040/FPGA over serial.
Implemented using a single-reader, event-driven state machine architecture.
"""

import threading
import time
import math
from typing import List, Optional

import modulation as mod
from PyQt6.QtCore import QObject, pyqtSignal, QTimer, QCoreApplication

# ── Timing ──────────────────────────────────────────────────
CMD_TIMEOUT    =  6.0   # seconds to wait for SIN/COS/DONE after SYM or ANG


class FPGAManager(QObject):
    """
    Event-driven state machine managing CORDIC communication over serial.
    Reacts to lines emitted by SerialManager's single reader thread.
    
    States: IDLE -> WAITING_READY -> WAITING_MODE_OK -> WAITING_SIN -> WAITING_COS -> WAITING_DONE -> READY
    """

    connected         = pyqtSignal(str)             # PING/Connect OK; payload = firmware info
    connection_failed = pyqtSignal(str)             # Connect failed

    symbol_result     = pyqtSignal(int, int, int, float, float, float, float)
    progress          = pyqtSignal(int, int)
    transmission_done = pyqtSignal(float, int)
    error             = pyqtSignal(str)
    status            = pyqtSignal(str)
    ang_result        = pyqtSignal(float, float, bool, str)

    def __init__(self, serial_manager):
        super().__init__()
        self.serial_manager = serial_manager
        self.serial_manager.line_received.connect(self._on_line)
        self.serial_manager.connection_lost.connect(self._on_connection_lost)

        self._state = "IDLE"
        self._state_start_time = 0.0
        self._cmd_timeout = CMD_TIMEOUT
        self._is_ready = False
        self._firmware_type = "DCD"
        self._abort_flag = threading.Event()
        self.current_modulation = "BPSK"

        # Active command tracking
        self._active_command_type = None  # "SYMBOLS" or "ANGLE"
        self._current_sin = None
        self._current_cos = None

        # Symbol transmission tracking
        self._tx_symbols: List[int] = []
        self._tx_mod = "BPSK"
        self._tx_idx = 0
        self._tx_total = 0
        self._tx_start_time = 0.0
        self._tx_sent_count = 0

        # Periodic timer for command timeouts
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._on_timer_tick)
        self._timer.start(100)

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    # ── Public API ────────────────────────────────────────────
    def connect(self, port: str, baud: int = 115200) -> bool:
        """Open the serial port and await the READY handshake line from MCU."""
        self._is_ready = False
        self._state = "IDLE"

        self.status.emit(f"Opening {port} @ {baud} baud…")
        ok = self.serial_manager.connect(port, baud)
        if not ok:
            self.connection_failed.emit(f"Could not open serial port {port}")
            return False

        # Transition to WAITING_READY state and wait for the board's READY announcement.
        self._state = "WAITING_READY"
        self._state_start_time = time.time()
        self._last_ping_time = time.time()
        self._cmd_timeout = 8.0  # Give the RP2040 boot script up to 8s to finish flashing the FPGA
        self.status.emit("Awaiting MCU startup handshake (READY message)…")
        self._send("PING")
        return True

    def disconnect(self):
        """Close the serial port and reset state machine."""
        self.abort()
        self.serial_manager.disconnect()
        self._is_ready = False
        self._state = "IDLE"

    def ping(self):
        """No-op or simple check when already connected."""
        if not self.serial_manager.is_connected():
            return
        self.status.emit("Connected.")

    def abort(self):
        """Aborts any active transmission."""
        self._abort_flag.set()
        if self._state != "IDLE":
            self._state = "READY" if self._is_ready else "IDLE"
        self._active_command_type = None
        self.status.emit("Aborted.")

    def set_mode(self, mode: str):
        """Sets modulation mode asynchronously."""
        self.current_modulation = mode
        if not self.serial_manager.is_connected() or not self._is_ready:
            return
        if self._firmware_type == "EXTENDED_PY":
            self.status.emit(f"Modulation set to {mode}")
            return
        if self._state != "READY":
            self.error.emit("MCU busy; cannot change mode right now.")
            return

        self._send(f"MODE:{mode}")
        self._state = "WAITING_MODE_OK"
        self._state_start_time = time.time()
        self._cmd_timeout = CMD_TIMEOUT

    def reset_fpga(self):
        """Send RESET command to re-initialize FPGA on the board."""
        if not self.serial_manager.is_connected() or not self._is_ready:
            return
        if self._state != "READY":
            self.error.emit("MCU busy; cannot reset right now.")
            return
        self._send("RESET")
        self._state = "WAITING_MODE_OK"
        self._state_start_time = time.time()
        self._cmd_timeout = CMD_TIMEOUT

    def transmit_symbol(self, symbol: int):
        self.transmit_symbols_async([symbol], self.current_modulation)

    def transmit_text(self, text: str):
        bits = mod.text_to_bits(text)
        symbols = mod.bits_to_symbols(bits, self.current_modulation)
        self.transmit_symbols_async(symbols, self.current_modulation)

    def transmit_binary(self, binary: str):
        bits = mod.binary_string_to_bits(binary)
        symbols = mod.bits_to_symbols(bits, self.current_modulation)
        self.transmit_symbols_async(symbols, self.current_modulation)

    def transmit_symbols_async(self, symbols: List[int], modulation: str):
        if not self.serial_manager.is_connected():
            self.error.emit("Not connected to the board.")
            return
        if not self._is_ready:
            self.error.emit("MCU is not ready — connect first.")
            return
        if self._state != "READY":
            self.error.emit("A transmission is already in progress.")
            return

        self._abort_flag.clear()
        self._tx_symbols = list(symbols)
        self._tx_mod = modulation
        self._tx_idx = 0
        self._tx_total = len(symbols)
        self._tx_start_time = time.time()
        self._tx_sent_count = 0
        self._active_command_type = "SYMBOLS"
        self._cmd_timeout = CMD_TIMEOUT

        if self._firmware_type != "EXTENDED_PY" and modulation != self.current_modulation:
            self.current_modulation = modulation
            self._send(f"MODE:{modulation}")
            self._state = "WAITING_MODE_OK"
            self._state_start_time = time.time()
        else:
            self.current_modulation = modulation
            self._send_next_symbol()

    def compute_angle_async(self, angle_rad: float, timeout: float = 4.0):
        if not self.serial_manager.is_connected() or not self._is_ready:
            self.ang_result.emit(0.0, 0.0, False, "Board not connected or not ready.")
            return
        if self._state != "READY":
            self.ang_result.emit(0.0, 0.0, False, "A transmission is currently in progress.")
            return

        self._active_command_type = "ANGLE"
        self._pending_angle_rad = angle_rad
        self._current_sin = None
        self._current_cos = None
        self._cmd_timeout = timeout

        if self._firmware_type == "EXTENDED_PY":
            self._send("R")
            time.sleep(0.05)
            self._send(f"{angle_rad:.8f}")
        else:
            self._send(f"ANG:{angle_rad:.8f}")

        self._state = "WAITING_SIN"
        self._state_start_time = time.time()

    def compute_angle_sync(self, angle_rad: float, timeout: float = 4.0) -> tuple:
        """
        Synchronous wrapper around event-driven compute_angle_async.

        FIX: this used to block with threading.Event.wait(), which freezes
        the Qt event loop when called from the GUI thread. In this
        architecture the FPGA's reply can only ever be delivered by
        SerialManager's QTimer, and that timer can only fire while the
        event loop is spinning -- so the old wait() guaranteed a deadlock
        (this call could never succeed, only time out) whenever it was
        invoked from the main thread. Pumping processEvents() while
        waiting keeps the event loop alive so the timer, and therefore
        the reply, can actually arrive.
        """
        res = [0.0, 0.0, False]
        done_evt = threading.Event()
        def _cb(s, c, ok, err):
            res[0], res[1], res[2] = s, c, ok
            done_evt.set()
        self.ang_result.connect(_cb)
        self.compute_angle_async(angle_rad, timeout)

        deadline = time.time() + timeout + 0.5
        while not done_evt.is_set() and time.time() < deadline:
            QCoreApplication.processEvents()
            time.sleep(0.005)

        try:
            self.ang_result.disconnect(_cb)
        except Exception:
            pass
        return res[0], res[1], res[2]

    # ── Internal Helpers ──────────────────────────────────────
    def _send(self, cmd: str) -> bool:
        # SerialManager already logs clean TX -> cmd
        return self.serial_manager.write_line(cmd)

    def _send_next_symbol(self):
        if self._abort_flag.is_set() or self._tx_idx >= self._tx_total:
            elapsed = time.time() - self._tx_start_time
            self._state = "READY"
            self._active_command_type = None
            self.transmission_done.emit(elapsed, self._tx_sent_count)
            return

        sym = self._tx_symbols[self._tx_idx]
        if self._firmware_type == "EXTENDED_PY":
            phase_deg = mod.expected_phase_deg(sym, self._tx_mod)
            angle_rad = math.radians(phase_deg)
            self._send("R")
            time.sleep(0.05)
            self._send(f"{angle_rad:.8f}")
        else:
            if self._tx_mod == "BPSK":
                sym_str = str(sym & 1)
            else:
                sym_str = f"{sym & 3:02b}"
            self._send(f"SYM:{sym_str}")

        self._current_sin = None
        self._current_cos = None
        self._state = "WAITING_SIN"
        self._state_start_time = time.time()
        self._cmd_timeout = CMD_TIMEOUT

    # ── Event-Driven State Machine (RX Line Parser) ───────────
    def _on_line(self, line: str):
        """Processes each complete line from SerialManager according to current state."""
        if not line:
            return

        # SerialManager already logs clean RX <- line


        # 2. Global spontaneous or mid-command EXTENDED_PY detection
        if self._firmware_type != "EXTENDED_PY" and any(k in line for k in ("Angle Mode", "Invalid selection", "Enter the Angle", "Angle Mode (D/R/E):", "Angle Mode (D/R):", "Calculated Values", "Expected Values", "====")):
            print(f"Detected EXTENDED_PY firmware from RX line: {line}")
            self._firmware_type = "EXTENDED_PY"
            if self._state in ("WAITING_MODE_OK", "WAITING_SIN", "WAITING_COS", "WAITING_DONE", "WAITING_READY"):
                self._is_ready = True
                old_state = self._state
                self._state = "READY"
                if old_state == "WAITING_READY":
                    self.connected.emit("READY,EXTENDED_PY,1.0")
                    self.status.emit("Connected to CORDIC Extended MCU firmware.")
                elif self._active_command_type == "SYMBOLS":
                    self._send_next_symbol()
                elif self._active_command_type == "ANGLE":
                    self.compute_angle_async(getattr(self, '_pending_angle_rad', 0.0), timeout=self._cmd_timeout)
            return

        if self._state in ("READY", "IDLE"):
            if line.startswith("READY"):
                self._firmware_type = "DCD"
            return

        # State: WAITING_READY
        if self._state == "WAITING_READY":
            if line.startswith("READY"):
                self._firmware_type = "DCD"
                self._is_ready = True
                self.connected.emit(line)
                self._send(f"MODE:{self.current_modulation}")
                self._state = "WAITING_MODE_OK"
                self._state_start_time = time.time()
                self._cmd_timeout = CMD_TIMEOUT
            elif any(k in line for k in ("Angle Mode", "Invalid selection", "Enter the Angle", "CORDIC", "====")):
                self._firmware_type = "EXTENDED_PY"
                self._is_ready = True
                self._state = "READY"
                self.connected.emit("READY,EXTENDED_PY,1.0")
                self.status.emit("Connected to CORDIC Extended MCU firmware.")
            return

        # State: WAITING_MODE_OK
        if self._state == "WAITING_MODE_OK":
            if line == "OK":
                self._state = "READY"
                self.status.emit(f"Modulation set to {self.current_modulation}")
                if self._active_command_type == "SYMBOLS":
                    self._send_next_symbol()
            elif line.startswith("ERR:"):
                self._state = "READY"
                self._active_command_type = None
                self.error.emit(f"MCU error setting MODE: {line}")
            else:
                print(f"[FPGAManager] Ignoring non-OK line while waiting for MODE OK: {line}")
            return

        # State: WAITING_SIN
        if self._state == "WAITING_SIN":
            if line.startswith("SIN") and ("=" in line or ":" in line):
                val_str = line.split("=")[-1].split(":")[-1].strip()
                try:
                    self._current_sin = float(val_str)
                    self._state = "WAITING_COS"
                    self._state_start_time = time.time()
                except ValueError as e:
                    print(f"[FPGAManager] Failed to parse SIN float from '{val_str}': {e}")
            elif line.startswith("ERR:"):
                self._state = "READY"
                self._active_command_type = None
                self.error.emit(f"MCU error: {line}")
            else:
                print(f"[FPGAManager] Ignoring non-SIN line while waiting for SIN: {line}")
            return

        # State: WAITING_COS
        if self._state == "WAITING_COS":
            if line.startswith("COS") and ("=" in line or ":" in line):
                val_str = line.split("=")[-1].split(":")[-1].strip()
                try:
                    self._current_cos = float(val_str)
                    self._state = "WAITING_DONE"
                    self._state_start_time = time.time()
                except ValueError as e:
                    print(f"[FPGAManager] Failed to parse COS float from '{val_str}': {e}")
            elif line.startswith("ERR:"):
                self._state = "READY"
                self._active_command_type = None
                self.error.emit(f"MCU error: {line}")
            else:
                print(f"[FPGAManager] Ignoring non-COS line while waiting for COS: {line}")
            return

        # State: WAITING_DONE
        if self._state == "WAITING_DONE":
            if line == "DONE" or any(k in line for k in ("Angle Mode", "====")):
                if self._current_sin is not None and self._current_cos is not None:
                    sin_f = self._current_sin
                    cos_f = self._current_cos
                    if self._active_command_type == "SYMBOLS":
                        idx = self._tx_idx
                        sym = self._tx_symbols[idx]
                        if self._tx_mod == "BPSK" and cos_f is not None:
                            cos_f = -cos_f
                        i_val, q_val = cos_f, sin_f
                        self.symbol_result.emit(idx, self._tx_total, sym, sin_f, cos_f, i_val, q_val)
                        self.progress.emit(idx + 1, self._tx_total)
                        self._tx_sent_count += 1
                        self._tx_idx += 1
                        self._send_next_symbol()
                    elif self._active_command_type == "ANGLE":
                        self._state = "READY"
                        self._active_command_type = None
                        self.ang_result.emit(sin_f, cos_f, True, "")
                    else:
                        self._state = "READY"
            elif line.startswith("ERR:"):
                self._state = "READY"
                self._active_command_type = None
                self.error.emit(f"MCU error: {line}")
            else:
                print(f"[FPGAManager] Ignoring non-DONE line while waiting for DONE: {line}")
            return

    # ── Timer Tick (Command Timeouts) ───────────────
    def _on_timer_tick(self):
        now = time.time()
        if self._state == "WAITING_READY":
            if now - self._state_start_time >= self._cmd_timeout:
                print("[FPGAManager] Handshake Timeout waiting for READY boot message from RP2040.")
                self.disconnect()
                self.connection_failed.emit("Timeout waiting for READY handshake from MCU.")
                return
            if not hasattr(self, '_last_ping_time'):
                self._last_ping_time = self._state_start_time
            if now - self._last_ping_time >= 1.5:
                self._last_ping_time = now
                self._send("PING")
            return

        if self._state in ("WAITING_MODE_OK", "WAITING_SIN", "WAITING_COS", "WAITING_DONE"):
            if now - self._state_start_time >= self._cmd_timeout:
                state_name = self._state.replace("WAITING_", "")
                print(f"Timeout waiting for {state_name}")
                self._state = "READY"
                if self._active_command_type == "ANGLE":
                    self._active_command_type = None
                    self.ang_result.emit(0.0, 0.0, False, f"Timeout waiting for {state_name} from FPGA.")
                else:
                    self._active_command_type = None
                    self.error.emit(f"Timeout waiting for {state_name} from FPGA.")

    def _on_connection_lost(self, reason: str):
        self._is_ready = False
        self._state = "IDLE"
        self._active_command_type = None
        self.error.emit(f"Connection lost: {reason}")