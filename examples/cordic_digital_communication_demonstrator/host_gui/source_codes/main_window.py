"""
main_window.py
═══════════════════════════════════════════════════════════════
Top-level GUI for the FPGA-Based CORDIC Digital Communication Demonstrator.
Redesigned to a commercial RF engineering software standard.
"""
import csv
import sys
import time
import traceback
import os
from datetime import datetime
import numpy as np

from PyQt6.QtCore import Qt, QTimer, QUrl, QRectF, QPropertyAnimation, pyqtProperty, QEasingCurve
from PyQt6.QtGui import QColor, QDesktopServices, QPainter
from PyQt6.QtSvg import QSvgRenderer
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QTabWidget,
    QPushButton, QLabel, QComboBox, QFrame, QStatusBar,
    QFileDialog, QMessageBox, QApplication, QRadioButton, QButtonGroup,
    QLineEdit, QSpinBox, QStackedWidget, QTableWidget, QTableWidgetItem, QDialog, QHeaderView, QMenu, QToolButton, QGraphicsOpacityEffect,
    QSplitter, QScrollArea, QSizePolicy
)

from styles import THEME, build_stylesheet
from port_scanner import get_available_ports_detailed
from serial_manager import SerialManager
from fpga_manager import FPGAManager
import modulation as mod
from waveform import WaveformCanvas
from constellation import ConstellationCanvas
from plot_window import DetailPlotWindow
from cordic_calculator import CordicCalculatorWidget
from serial_monitor import SerialMonitorDialog
from backend_visualizer import BackendVisualizerWindow

def _excepthook(et, ev, tb):
    print("=" * 60, file=sys.stderr)
    traceback.print_exception(et, ev, tb)
sys.excepthook = _excepthook

# ══════════════════════════════════════════════════════════════
#  REUSABLE WIDGETS & ANIMATIONS
# ══════════════════════════════════════════════════════════════

class Card(QFrame):
    """Minimalistic card container."""
    def __init__(self, title="", parent=None):
        super().__init__(parent)
        self.setObjectName("card")
        self._v = QVBoxLayout(self)
        self._v.setContentsMargins(16, 16, 16, 16)
        self._v.setSpacing(12)
        if title:
            t = QLabel(title)
            t.setObjectName("card_title")
            self._v.addWidget(t)

    def body_layout(self):
        return self._v

class StatCard(QFrame):
    """Metric tile with smooth animated numeric readout."""
    def __init__(self, label, accent_key="C_ACCENT", is_numeric=True, is_float=True, precision=4, parent=None):
        super().__init__(parent)
        self._accent_key = accent_key
        self.is_numeric = is_numeric
        self.is_float = is_float
        self.precision = precision
        self.setObjectName("stat_card")
        
        self._curr_num = None
        self._target_num = None
        self._prefix = ""
        self._suffix = ""
        self._anim_timer = QTimer(self)
        self._anim_timer.setInterval(20)
        self._anim_timer.timeout.connect(self._on_anim_step)
        self._anim_steps = 0
        self._anim_total = 8

        v = QVBoxLayout(self)
        v.setContentsMargins(12, 12, 12, 12)
        v.setSpacing(4)
        
        lbl = QLabel(label.upper())
        lbl.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 10px; font-weight: 600; letter-spacing: 0.05em;")
        
        self._val = QLabel("—")
        self._val.setStyleSheet(
            f"color: {THEME['C_TEXT']}; font-size: 18px; font-weight: 700; "
            f"font-family: 'Cascadia Mono', 'JetBrains Mono', 'Consolas', monospace;"
        )
        
        v.addWidget(lbl)
        v.addWidget(self._val)
        self._reset_style()

    def _reset_style(self):
        self.setStyleSheet(
            f"#stat_card {{ background: {THEME['C_SURFACE2']}; border: 1px solid {THEME['C_BORDER']}; border-radius: 8px; }}"
        )

    def _format_val(self, n):
        fmt_str = f"{{:+.{self.precision}f}}" if self._prefix == "" and n < 0 and self.is_float else f"{{:.{self.precision}f}}"
        if self.is_float:
            return f"{self._prefix}{fmt_str.format(n)}{self._suffix}"
        else:
            return f"{self._prefix}{int(round(n))}{self._suffix}"

    def _on_anim_step(self):
        self._anim_steps += 1
        if self._anim_steps >= self._anim_total:
            self._anim_timer.stop()
            self._curr_num = self._target_num
            self._val.setText(self._format_val(self._curr_num))
            self._reset_style()
            return
        t = self._anim_steps / float(self._anim_total)
        t = 1 - (1 - t) * (1 - t)
        interp = self._curr_num + (self._target_num - self._curr_num) * t
        self._val.setText(self._format_val(interp))

    def set_value(self, val, prefix="", suffix="", is_error=False):
        if is_error:
            self.setStyleSheet(f"#stat_card {{ background: {THEME['C_SURFACE2']}; border: 1px solid {THEME['C_RED']}; border-radius: 8px; }}")
            QTimer.singleShot(300, self._reset_style)
        else:
            self.setStyleSheet(f"#stat_card {{ background: {THEME['C_SURFACE3']}; border: 1px solid {THEME['C_CYAN']}; border-radius: 8px; }}")
            QTimer.singleShot(180, self._reset_style)

        if self.is_numeric:
            try:
                numeric_val = float(val)
                self._prefix = prefix
                self._suffix = suffix
                if self._curr_num is None:
                    self._curr_num = numeric_val
                    self._val.setText(self._format_val(numeric_val))
                else:
                    self._target_num = numeric_val
                    self._anim_steps = 0
                    self._anim_timer.start()
            except ValueError:
                self._val.setText(f"{prefix}{val}{suffix}")
        else:
            self._val.setText(f"{prefix}{val}{suffix}")

    def set_value_clean(self, val, prefix="", suffix=""):
        """Fast, non-blocking text update without style recalculations or timers."""
        if self.is_numeric:
            try:
                numeric_val = float(val)
                self._prefix = prefix
                self._suffix = suffix
                self._curr_num = numeric_val
                new_text = self._format_val(numeric_val)
            except ValueError:
                new_text = f"{prefix}{val}{suffix}"
        else:
            new_text = f"{prefix}{val}{suffix}"
        if self._val.text() != new_text:
            self._val.setText(new_text)

class AnimatedSocialBanner(QWidget):
    """Cycles between GitHub and LinkedIn full logo + name badges with animation."""
    def __init__(self, parent=None):
        super().__init__(parent)
        from PyQt6.QtGui import QIcon
        from PyQt6.QtCore import QSize
        
        self.setFixedHeight(34)
        layout = QGridLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        base_icon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
        
        links = [
            ("github.svg", "GitHub", "https://github.com/upadhyaypranjal/FPGA-Based-Digital-Communication-Demonstrator-Using-CORDIC"),
            ("linkedin.svg", "LinkedIn", "https://www.linkedin.com/in/pranjalupadhyay0142/"),
            ("portfolio.svg", "Portfolio", "https://pranjalupadhyay.netlify.app")
        ]
        
        self.buttons = []
        self.effects = []
        
        for svg_name, name, url in links:
            btn = QToolButton(self)
            btn.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
            btn.setText(f"  {name}")
            btn.setIcon(QIcon(os.path.join(base_icon_path, svg_name)))
            btn.setIconSize(QSize(18, 18))
            btn.setFixedHeight(30)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.clicked.connect(lambda checked, u=url: QDesktopServices.openUrl(QUrl(u)))
            
            btn.setStyleSheet("""
                QToolButton {
                    background: rgba(255, 255, 255, 0.06);
                    color: #f0f0f0;
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    border-radius: 15px;
                    padding: 0px 14px;
                    font-size: 13px;
                    font-weight: 600;
                }
                QToolButton:hover {
                    background: rgba(0, 122, 204, 0.25);
                    border: 1px solid #007acc;
                    color: #ffffff;
                }
            """)
            
            effect = QGraphicsOpacityEffect(btn)
            btn.setGraphicsEffect(effect)
            
            layout.addWidget(btn, 0, 0, Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
            self.buttons.append(btn)
            self.effects.append(effect)
            
        self.current_idx = 0
        for i, (btn, eff) in enumerate(zip(self.buttons, self.effects)):
            if i == 0:
                btn.setVisible(True)
                eff.setOpacity(1.0)
            else:
                btn.setVisible(False)
                eff.setOpacity(0.0)
                
        self.timer = QTimer(self)
        self.timer.setInterval(3200)
        self.timer.timeout.connect(self._animate_next)
        self.timer.start()

    def _animate_next(self):
        curr_btn = self.buttons[self.current_idx]
        if curr_btn.underMouse():
            return
            
        next_idx = (self.current_idx + 1) % len(self.buttons)
        next_btn = self.buttons[next_idx]
        curr_eff = self.effects[self.current_idx]
        next_eff = self.effects[next_idx]
        
        self.fade_out = QPropertyAnimation(curr_eff, b"opacity", self)
        self.fade_out.setDuration(400)
        self.fade_out.setStartValue(1.0)
        self.fade_out.setEndValue(0.0)
        self.fade_out.setEasingCurve(QEasingCurve.Type.InOutQuad)
        
        def on_fade_out_done():
            curr_btn.setVisible(False)
            next_btn.setVisible(True)
            next_eff.setOpacity(0.0)
            
            self.fade_in = QPropertyAnimation(next_eff, b"opacity", self)
            self.fade_in.setDuration(400)
            self.fade_in.setStartValue(0.0)
            self.fade_in.setEndValue(1.0)
            self.fade_in.setEasingCurve(QEasingCurve.Type.InOutQuad)
            self.fade_in.start()
            self.current_idx = next_idx
            
        self.fade_out.finished.connect(on_fade_out_done)
        self.fade_out.start()

class PulseDot(QLabel):
    """Animated connection indicator."""
    def __init__(self, parent=None):
        super().__init__("● OFFLINE", parent)
        self._pulse = QTimer(self); self._pulse.setInterval(800)
        self._pulse.timeout.connect(self._toggle)
        self._state = False; self._online = False
        self._update_style()
    def set_online(self, v: bool):
        self._online = v
        self._pulse.start() if v else self._pulse.stop()
        self._state = True
        self._update_style()
    def _toggle(self):
        self._state = not self._state
        self._update_style()
    def _update_style(self):
        if self._online:
            alpha = "FF" if self._state else "66"
            self.setText("● CONNECTED")
            self.setStyleSheet(f"color: #{alpha}{THEME['C_GREEN'][1:]}; font-size: 11px; font-weight: 700; letter-spacing: 0.05em;")
        else:
            self.setText("● OFFLINE")
            self.setStyleSheet(f"color: {THEME['C_DIM']}; font-size: 11px; font-weight: 700; letter-spacing: 0.05em;")

class NotificationPanel(QFrame):
    """
    Compact notification bar centered at the bottom of the window.
    Auto-dismisses after 3 seconds.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("notification_panel")
        self.setFixedHeight(38)
        self.setFixedWidth(360)
        
        layout = QHBoxLayout(self)
        layout.setContentsMargins(14, 4, 14, 4)
        layout.setSpacing(10)
        
        self._badge = QLabel("Status")
        self._badge.setStyleSheet(
            f"background: rgba(0, 210, 255, 0.15); color: {THEME['C_CYAN']}; font-size: 11px; "
            f"font-weight: 700; padding: 3px 8px; border-radius: 4px;"
        )
        self._badge.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._badge.setFixedWidth(68)
        
        self._msg = QLabel("Ready.")
        self._msg.setStyleSheet(
            f"color: {THEME['C_WHITE']}; font-size: 12px; font-weight: 500;"
        )
        self._msg.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        layout.addWidget(self._badge, 0)
        layout.addWidget(self._msg, 1)
        
        # Auto-dismiss timer
        self._dismiss_timer = QTimer(self)
        self._dismiss_timer.setSingleShot(True)
        self._dismiss_timer.timeout.connect(self._dismiss)
        
        self.setVisible(False)  # hidden until first notification

    def _dismiss(self):
        self.setVisible(False)

    def show_notification(self, message: str, level: str = "info"):
        for emoji in ("✅ ", "❌ ", "⚠️ ", "⚡ ", "ℹ️ "):
            message = message.replace(emoji, "")
        message = message.replace("\n", " -- ").strip()
        self._msg.setText(message)
        
        # Adjust width dynamically based on message length and notification level
        if level in ("error", "warning") or len(message) > 40:
            calc_w = min(820, max(360, len(message) * 7 + 100))
            self.setFixedWidth(calc_w)
        else:
            self.setFixedWidth(360)
            
        c = THEME
        
        if level in ("error", "warning"):
            color = c["C_RED"] if level == "error" else c["C_ORANGE"]
            badge_txt = "Alert" if level == "error" else "Warning"
            bg_tint = "rgba(255, 51, 51, 0.08)" if level == "error" else "rgba(255, 138, 0, 0.08)"
            self._badge.setText(badge_txt)
            self._badge.setStyleSheet(
                f"background: {color}; color: {c['C_BG']}; font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 4px;"
            )
            self.setStyleSheet(
                f"#notification_panel {{ background: {bg_tint}; border: 1px solid {color}; border-radius: 6px; }}"
            )
        elif level in ("busy", "action"):
            color = c["C_PURPLE"]
            self._badge.setText("Action")
            self._badge.setStyleSheet(
                f"background: rgba(157, 78, 221, 0.25); color: #D882FF; font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 4px;"
            )
            self.setStyleSheet(
                f"#notification_panel {{ background: rgba(157, 78, 221, 0.06); border: 1px solid {color}; border-radius: 6px; }}"
            )
        elif level == "success":
            color = c["C_GREEN"]
            self._badge.setText("Success")
            self._badge.setStyleSheet(
                f"background: rgba(0, 200, 83, 0.2); color: {color}; font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 4px;"
            )
            self.setStyleSheet(
                f"#notification_panel {{ background: rgba(0, 200, 83, 0.06); border: 1px solid {color}; border-radius: 6px; }}"
            )
        else:
            color = c["C_CYAN"]
            self._badge.setText("Status")
            self._badge.setStyleSheet(
                f"background: rgba(0, 210, 255, 0.15); color: {color}; font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 4px;"
            )
            self.setStyleSheet(
                f"#notification_panel {{ background: {c['C_SURFACE2']}; border: 1px solid {c['C_BORDER']}; border-radius: 6px; }}"
            )
        
        self.setVisible(True)
        self._dismiss_timer.start(3000)  # auto-dismiss after 3 seconds

# ══════════════════════════════════════════════════════════════
#  MAIN WINDOW
# ══════════════════════════════════════════════════════════════
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("FPGA-Based CORDIC Digital Communication Demonstrator using Phase Shift Keying")
        self.resize(1400, 900)
        self.setStyleSheet(build_stylesheet())

        self.serial_manager = SerialManager()
        self.fpga = FPGAManager(self.serial_manager)
        
        self._symbols = []
        self._iq_history = []
        self._start_time = None
        self._tx_running = False
        
        self._last_symbol_data = None
        self._last_rendered_count = 0
        self._last_plot_time = 0

        self._waveform_canvas = WaveformCanvas(show_toolbar=False)
        self._constellation_canvas = ConstellationCanvas(show_toolbar=False)
        self._backend_visualizer = None

        self._last_tx_input_type = "Text"
        self._last_tx_input_str = ""
        self._last_tx_bits = []
        self._last_tx_symbols = []
        self._last_tx_mod_type = "QPSK"
        self._last_tx_results = []
        self._last_tx_done = False
        self._last_tx_elapsed = 0.0
        self._last_tx_count = 0

        self._build_ui()
        self._wire_signals()
        self._refresh_ports()
        
        # Throttled UI Refresh Timer
        self._ui_refresh_timer = QTimer(self)
        self._ui_refresh_timer.setInterval(80)
        self._ui_refresh_timer.timeout.connect(self._on_ui_refresh)
        self._ui_refresh_timer.start()

    # ──────────────────────────────────────────────────
    #  BUILD UI — Clean 2-column layout
    # ──────────────────────────────────────────────────
    def _build_ui(self):
        central = QWidget(); self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(16, 12, 16, 8)
        root.setSpacing(10)

        # ── Header bar ──
        root.addWidget(self._build_header(), 0)

        # ── Body: Left sidebar + Right content ──
        self.notification_panel = NotificationPanel()
        body = QHBoxLayout()
        body.setSpacing(14)
        body.addWidget(self._build_left_sidebar(), 0)
        body.addWidget(self._build_right_content(), 1)
        root.addLayout(body, 1)

        # ── Status bar ──
        self.setStatusBar(QStatusBar())
        self.statusBar().setSizeGripEnabled(False)
        self._status_labels = {
            "conn": QLabel(" disconnected "),
            "fw": QLabel(" fw: — "),
            "tx": QLabel(" tx: 0 ")
        }
        for lbl in self._status_labels.values():
            lbl.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 10px; font-family: monospace; border-right: 1px solid {THEME['C_BORDER']}; padding-right: 8px;")
            self.statusBar().addPermanentWidget(lbl)
        self.statusBar().showMessage("Ready.")

    def _build_header(self):
        head = QWidget()
        h = QHBoxLayout(head)
        h.setContentsMargins(4, 0, 4, 4)
        h.setSpacing(16)

        title = QLabel("FPGA CORDIC Digital Communication Demonstrator")
        title.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 16px; font-weight: 700;")

        sys_box = QHBoxLayout()
        sys_box.setSpacing(14)
        self._pulse = PulseDot()
        self._hdr_mode = QLabel("MODE: —")
        self._hdr_port = QLabel("PORT: —")
        for lbl in (self._hdr_mode, self._hdr_port):
            lbl.setStyleSheet(f"color: {THEME['C_TEXT']}; font-size: 11px; font-weight: 600;")
        
        self._btn_export_top = QPushButton("Export ▾")
        self._btn_export_top.setCursor(Qt.CursorShape.PointingHandCursor)
        self._btn_export_top.setStyleSheet(
            f"color: {THEME['C_CYAN']}; font-size: 12px; font-weight: 700; background: transparent; border: none; padding: 0px 4px;"
        )
        
        sys_box.addWidget(self._pulse)
        sys_box.addWidget(self._hdr_mode)
        sys_box.addWidget(self._hdr_port)
        sys_box.addWidget(self._btn_export_top)

        h.addWidget(title)
        h.addStretch(1)
        h.addLayout(sys_box)
        return head

    # ── LEFT SIDEBAR ─────────────────────────────────
    def _build_left_sidebar(self):
        sidebar = QWidget()
        sidebar.setFixedWidth(430)
        v = QVBoxLayout(sidebar)
        v.setContentsMargins(0, 0, 8, 0)
        v.setSpacing(8)

        v.addWidget(self._build_connection_card())
        v.addWidget(self._build_modulation_card())
        v.addWidget(self._build_input_card())
        v.addWidget(self._build_actions_card())
        v.addStretch(1)
        v.addWidget(self._build_footer())
        return sidebar

    def _build_connection_card(self):
        card = Card("Connection")
        lay = card.body_layout()

        # Port selector row
        port_row = QHBoxLayout()
        port_row.setSpacing(6)
        self._cmb_port = QComboBox()
        self._cmb_port.setMinimumHeight(32)
        self._btn_refresh = QPushButton("⟳")
        self._btn_refresh.setFixedSize(32, 32)
        self._btn_refresh.setObjectName("ghost")
        port_row.addWidget(self._cmb_port, 1)
        port_row.addWidget(self._btn_refresh)
        lay.addLayout(port_row)

        # Baud rate row
        baud_row = QHBoxLayout()
        baud_row.setSpacing(8)
        baud_lbl = QLabel("Baud Rate:")
        baud_lbl.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 11px;")
        self._cmb_baud = QComboBox()
        self._cmb_baud.setMinimumHeight(32)
        self._cmb_baud.addItems(["9600", "19200", "38400", "57600", "115200", "230400", "460800", "921600"])
        baud_row.addWidget(baud_lbl)
        baud_row.addWidget(self._cmb_baud, 1)
        lay.addLayout(baud_row)

        # Connect / Disconnect buttons
        btn_row = QHBoxLayout()
        btn_row.setSpacing(8)
        self._btn_connect = QPushButton("Connect")
        self._btn_connect.setObjectName("primary")
        self._btn_connect.setMinimumHeight(36)
        self._btn_disconnect = QPushButton("Disconnect")
        self._btn_disconnect.setMinimumHeight(36)
        self._btn_disconnect.setEnabled(False)
        btn_row.addWidget(self._btn_connect)
        btn_row.addWidget(self._btn_disconnect)
        lay.addLayout(btn_row)
        return card

    def _build_modulation_card(self):
        card = Card("Modulation")
        lay = card.body_layout()
        row = QHBoxLayout()
        row.setSpacing(16)
        self._rb_bpsk = QRadioButton("BPSK")
        self._rb_bpsk.setChecked(True)
        self._rb_qpsk = QRadioButton("QPSK")
        self._mod_group = QButtonGroup(card)
        self._mod_group.addButton(self._rb_bpsk)
        self._mod_group.addButton(self._rb_qpsk)
        row.addWidget(self._rb_bpsk)
        row.addWidget(self._rb_qpsk)
        row.addStretch(1)
        lay.addLayout(row)
        return card

    def _build_input_card(self):
        card = Card("Input Vector")
        lay = card.body_layout()

        self._rb_text = QRadioButton("Text")
        self._rb_binary = QRadioButton("Binary")
        self._rb_random = QRadioButton("Random")
        self._rb_text.setChecked(True)
        
        mode_row = QHBoxLayout()
        mode_row.setSpacing(12)
        mode_row.addWidget(self._rb_text)
        mode_row.addWidget(self._rb_binary)
        mode_row.addWidget(self._rb_random)
        mode_row.addStretch(1)
        lay.addLayout(mode_row)

        self._stack = QStackedWidget()

        p_text = QWidget()
        lt = QVBoxLayout(p_text); lt.setContentsMargins(0, 0, 0, 0)
        self._txt_text = QLineEdit()
        self._txt_text.setText("HELLO FPGA")
        self._txt_text.setMinimumHeight(32)
        lt.addWidget(self._txt_text)
        self._stack.addWidget(p_text)

        p_bin = QWidget()
        lb = QVBoxLayout(p_bin); lb.setContentsMargins(0, 0, 0, 0)
        self._txt_bin = QLineEdit()
        self._txt_bin.setText("010101010")
        self._txt_bin.setMinimumHeight(32)
        lb.addWidget(self._txt_bin)
        self._stack.addWidget(p_bin)

        p_rand = QWidget()
        lr = QHBoxLayout(p_rand); lr.setContentsMargins(0, 0, 0, 0)
        lr.addWidget(QLabel("Bits:"))
        self._spn_random_bits = QSpinBox()
        self._spn_random_bits.setRange(1, 8192)
        self._spn_random_bits.setValue(64)
        self._spn_random_bits.setMinimumHeight(32)
        lr.addWidget(self._spn_random_bits, 1)
        self._stack.addWidget(p_rand)

        lay.addWidget(self._stack)
        return card

    def _build_actions_card(self):
        card = Card("Actions")
        lay = card.body_layout()

        self._btn_transmit = QPushButton("▶  Start Transmission")
        self._btn_transmit.setObjectName("primary")
        self._btn_transmit.setMinimumHeight(44)
        lay.addWidget(self._btn_transmit)

        grid = QGridLayout()
        grid.setSpacing(8)
        
        self._btn_clear = QPushButton("Clear")
        self._btn_table = QPushButton("Data Table")
        self._btn_cordic = QPushButton("CORDIC Calculator")
        self._btn_backend = QPushButton("Backend Processing")
        self._btn_open_const = QPushButton("I/Q Constellation")
        self._btn_serial_monitor = QPushButton("Serial Monitor")
        
        buttons = [
            (self._btn_clear, 0, 0),
            (self._btn_table, 0, 1),
            (self._btn_cordic, 1, 0),
            (self._btn_backend, 1, 1),
            (self._btn_open_const, 2, 0),
            (self._btn_serial_monitor, 2, 1)
        ]
        
        for btn, r, c in buttons:
            btn.setMinimumHeight(36)
            btn.setMaximumHeight(40)
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.setStyleSheet("")
            grid.addWidget(btn, r, c)
            
        grid.setColumnStretch(0, 1)
        grid.setColumnStretch(1, 1)
        lay.addLayout(grid)
        return card

    def _build_footer(self):
        foot = QWidget()
        h = QVBoxLayout(foot)
        h.setContentsMargins(8, 0, 8, 0)
        h.setSpacing(6)
        name = QLabel("Pranjal Upadhyay")
        name.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 17px; font-weight: 800;")
        h.addWidget(name)
        h.addWidget(AnimatedSocialBanner(self))
        return foot

    # ── RIGHT CONTENT AREA ───────────────────────────
    def _build_right_content(self):
        wrap = QWidget()
        v = QVBoxLayout(wrap)
        v.setContentsMargins(0, 0, 0, 0)
        v.setSpacing(10)

        # Stats row
        v.addWidget(self._build_stats_row(), 0)

        # Waveform expanded across the entire width (Constellation removed from main grid)
        plots = QHBoxLayout()
        plots.setSpacing(10)
        plots.addWidget(self._build_waveform_card(), 1)
        v.addLayout(plots, 1)

        # Notification panel container (fixed height 38px in right column so UI never shifts or hides left panel)
        notif_container = QWidget()
        notif_container.setFixedHeight(38)
        notif_row = QHBoxLayout(notif_container)
        notif_row.setContentsMargins(0, 0, 0, 0)
        notif_row.addStretch(1)
        notif_row.addWidget(self.notification_panel)
        notif_row.addStretch(1)
        v.addWidget(notif_container, 0)

        return wrap

    def _build_stats_row(self):
        card = Card()
        lay = card.body_layout()
        grid = QGridLayout()
        grid.setSpacing(8)

        self._stat_symbol = StatCard("Current Symbol", "C_ACCENT", is_numeric=False)
        self._stat_phase  = StatCard("Current Phase", "C_PURPLE", is_numeric=True, precision=1)
        self._stat_status = StatCard("Status", "C_GREEN", is_numeric=False)
        self._stat_sin    = StatCard("SINE", "C_CYAN", is_numeric=True, precision=4)
        self._stat_cos    = StatCard("COSINE", "C_CYAN", is_numeric=True, precision=4)
        self._stat_exec   = StatCard("Exec Time", "C_SUBTEXT", is_numeric=True, precision=3)
        self._stat_i      = StatCard("I Phase", "C_I_COLOR", is_numeric=True, precision=4)
        self._stat_q      = StatCard("Q Phase", "C_Q_COLOR", is_numeric=True, precision=4)
        self._stat_count  = StatCard("Symbol Count", "C_ACCENT", is_numeric=False)
        self._stat_rate   = StatCard("Bit Rate", "C_ORANGE", is_numeric=True, is_float=False)

        stats = [
            self._stat_symbol, self._stat_phase, self._stat_status,
            self._stat_sin, self._stat_cos, self._stat_exec,
            self._stat_i, self._stat_q, self._stat_count,
            self._stat_rate,
        ]
        for idx, c in enumerate(stats):
            grid.addWidget(c, idx // 5, idx % 5)
        lay.addLayout(grid)
        return card

    def _build_waveform_card(self):
        card = Card("Waveforms")
        lay = card.body_layout()

        tb = QHBoxLayout(); tb.setSpacing(8)
        self._btn_reset_wave = QPushButton("⟲ Reset")
        self._btn_pan_left = QPushButton("◀")
        self._btn_pan_left.setToolTip("Pan Left (Left Arrow Key)")
        self._btn_pan_left.setFixedWidth(36)
        self._btn_pan_right = QPushButton("▶")
        self._btn_pan_right.setToolTip("Pan Right (Right Arrow Key)")
        self._btn_pan_right.setFixedWidth(36)
        
        self._btn_full_wave = QPushButton("[ ]")
        self._btn_full_wave.setToolTip("Switch to fullscreen")
        self._btn_full_wave.setFixedWidth(38)
        self._btn_full_wave.clicked.connect(self._expand_waveform)
        self._btn_reset_wave.clicked.connect(self._waveform_canvas.reset_zoom)
        self._btn_pan_left.clicked.connect(lambda: self._waveform_canvas.pan_waveforms("left"))
        self._btn_pan_right.clicked.connect(lambda: self._waveform_canvas.pan_waveforms("right"))
        
        tb.addWidget(self._btn_reset_wave)
        tb.addWidget(self._btn_pan_left)
        tb.addWidget(self._btn_pan_right)
        tb.addStretch(1)
        tb.addWidget(self._btn_full_wave)
        lay.addLayout(tb)

        lay.addWidget(self._waveform_canvas, 1)
        return card

    def _build_constellation_card(self):
        card = Card("I/Q Constellation")
        lay = card.body_layout()

        tb = QHBoxLayout(); tb.setSpacing(8)
        self._btn_reset_const = QPushButton("⟲ Reset")
        self._btn_full_const = QPushButton("[ ]")
        self._btn_full_const.setToolTip("Switch to fullscreen")
        self._btn_full_const.setFixedWidth(38)
        self._btn_full_const.clicked.connect(self._expand_constellation)
        self._btn_reset_const.clicked.connect(self._constellation_canvas.reset_zoom)
        tb.addWidget(self._btn_reset_const)
        tb.addStretch(1)
        tb.addWidget(self._btn_full_const)
        lay.addLayout(tb)

        lay.addWidget(self._constellation_canvas, 1)
        return card

    # ────────────────────────────────────────────────────────
    #  SERIAL MONITOR & CORDIC CALCULATOR WINDOWS
    # ────────────────────────────────────────────────────────
    def _open_serial_monitor(self):
        """Opens the real-time Serial Debug & Protocol Monitor Studio."""
        self._serial_dialog = SerialMonitorDialog(self, serial_manager=self.serial_manager)
        self._serial_dialog.show()

    def _open_cordic_calculator(self):
        """Opens the CORDIC Calculator Studio in a maximized dedicated window."""
        self._cordic_dialog = QDialog(self)
        self._cordic_dialog.setWindowTitle("Circular CORDIC Calculator Studio — Pranjal Upadhyay")
        self._cordic_dialog.setStyleSheet(build_stylesheet())

        root = QVBoxLayout(self._cordic_dialog)
        root.setContentsMargins(12, 10, 12, 8)
        root.setSpacing(8)

        self.cordic_calc_widget = CordicCalculatorWidget(
            self._cordic_dialog,
            fpga_manager=self.fpga,
            in_dialog=True
        )
        self.cordic_calc_widget.notification_triggered.connect(
            self.notification_panel.show_notification
        )
        # Update connection status
        if self.serial_manager.is_connected():
            port = self._cmb_port.currentData() or ""
            fw = self._status_labels["fw"].text().strip().replace("fw: ", "")
            self.cordic_calc_widget.update_connection_status(True, port, fw)
        else:
            self.cordic_calc_widget.update_connection_status(False)

        root.addWidget(self.cordic_calc_widget, 1)

        # ── Footer: name + social links ──
        footer = QWidget()
        footer.setStyleSheet(f"background: {THEME['C_SURFACE2']}; border-radius: 6px;")
        fh = QHBoxLayout(footer)
        fh.setContentsMargins(16, 6, 16, 6)
        fh.setSpacing(16)

        name_lbl = QLabel("Pranjal Upadhyay")
        name_lbl.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 15px; font-weight: 800; background: transparent;")
        fh.addWidget(name_lbl)
        fh.addStretch(1)

        # Social link buttons
        from PyQt6.QtGui import QIcon
        from PyQt6.QtCore import QSize
        base_icon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
        links = [
            ("github.svg", "GitHub", "https://github.com/upadhyaypranjal/FPGA-Based-Digital-Communication-Demonstrator-Using-CORDIC"),
            ("linkedin.svg", "LinkedIn", "https://www.linkedin.com/in/pranjalupadhyay0142/"),
            ("portfolio.svg", "Portfolio", "https://pranjalupadhyay.netlify.app"),
        ]
        for svg_name, label, url in links:
            btn = QToolButton(footer)
            btn.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
            btn.setText(f"  {label}")
            btn.setIcon(QIcon(os.path.join(base_icon_path, svg_name)))
            btn.setIconSize(QSize(18, 18))
            btn.setFixedHeight(30)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.clicked.connect(lambda checked, u=url: QDesktopServices.openUrl(QUrl(u)))
            btn.setStyleSheet("""
                QToolButton {
                    background: rgba(255,255,255,0.06);
                    color: #f0f0f0;
                    border: 1px solid rgba(255,255,255,0.12);
                    border-radius: 15px;
                    padding: 0 14px;
                    font-size: 13px;
                    font-weight: 600;
                }
                QToolButton:hover {
                    background: rgba(0,122,204,0.25);
                    border: 1px solid #007acc;
                    color: #ffffff;
                }
            """)
            fh.addWidget(btn)

        root.addWidget(footer, 0)
        self._cordic_dialog.resize(1180, 740)
        self._cordic_dialog.setWindowFlags(self._cordic_dialog.windowFlags() & ~Qt.WindowType.WindowMaximizeButtonHint)
        self._cordic_dialog.show()

    def _open_backend_visualizer(self):
        self.notification_panel.show_notification("Opening the backend processing...", "info")
        QApplication.processEvents()
        if self._backend_visualizer is None:
            self._backend_visualizer = BackendVisualizerWindow(self)
        if self._last_tx_symbols:
            self._backend_visualizer.sync_with_state(
                self._last_tx_input_type, self._last_tx_input_str, self._last_tx_bits,
                self._last_tx_symbols, self._last_tx_mod_type, self._last_tx_results,
                self._last_tx_done, self._last_tx_elapsed, self._last_tx_count
            )
        self._backend_visualizer.show()
        self._backend_visualizer.raise_()
        self._backend_visualizer.activateWindow()

    # ────────────────────────────────────────────────────────
    #  SIGNAL WIRING & LOGIC
    # ────────────────────────────────────────────────────────
    def _wire_signals(self):
        self._btn_refresh.clicked.connect(self._refresh_ports)
        self._btn_connect.clicked.connect(self._on_connect)
        self._btn_disconnect.clicked.connect(self._on_disconnect)
        self._btn_transmit.clicked.connect(self._on_transmit)
        self._btn_clear.clicked.connect(self._on_clear)
        self._btn_export_top.clicked.connect(self._on_export)
        self._btn_table.clicked.connect(self._show_data_table)
        self._btn_cordic.clicked.connect(self._open_cordic_calculator)
        self._btn_backend.clicked.connect(self._open_backend_visualizer)
        self._btn_serial_monitor.clicked.connect(self._open_serial_monitor)
        self._btn_open_const.clicked.connect(self._expand_constellation)

        self._rb_text.toggled.connect(lambda c: c and self._stack.setCurrentIndex(0))
        self._rb_binary.toggled.connect(lambda c: c and self._stack.setCurrentIndex(1))
        self._rb_random.toggled.connect(lambda c: c and self._stack.setCurrentIndex(2))

        self.serial_manager.log_message.connect(lambda m, l: self.statusBar().showMessage(m, 3000))
        self.serial_manager.connection_lost.connect(self._on_connection_lost)

        self.fpga.connected.connect(self._on_fpga_connected)
        self.fpga.connection_failed.connect(self._on_fpga_connection_failed)
        # FIX: fpga.status was emitted (e.g. "Opening COMx…", "Awaiting MCU
        # startup handshake (READY message)…", "Modulation set to BPSK")
        # but never connected to anything, so all of it silently vanished.
        # A slow-but-normal ~1-8s handshake while the RP2040 flashes the
        # FPGA looked exactly like a hang because the GUI gave zero
        # feedback during that window.
        self.fpga.status.connect(lambda m: self.notification_panel.show_notification(m, "info"))
        
        def update_mode(is_checked, mode_str):
            if is_checked:
                self.fpga.set_mode(mode_str)
                self._hdr_mode.setText(f"MODE: {mode_str}")
                self.notification_panel.show_notification(f"Modulation mode set to {mode_str}.", "info")
                
        self._rb_bpsk.toggled.connect(lambda c: update_mode(c, "BPSK"))
        self._rb_qpsk.toggled.connect(lambda c: update_mode(c, "QPSK"))

        self.fpga.symbol_result.connect(self._on_symbol_result)
        self.fpga.progress.connect(self._on_progress)
        self.fpga.transmission_done.connect(self._on_transmission_done)
        self.fpga.error.connect(self._on_fpga_error)

    def _refresh_ports(self):
        self._cmb_port.clear()
        for device, desc in get_available_ports_detailed():
            self._cmb_port.addItem(f"{device} — {desc}", userData=device)

    def _on_connect(self):
        device = self._cmb_port.currentData()
        if not device: return
        self._btn_connect.setEnabled(False)
        self._btn_connect.setText("Connecting…")
        self.fpga.set_mode("QPSK" if self._rb_qpsk.isChecked() else "BPSK")
        self.notification_panel.show_notification(f"Connecting to {device}...", "busy")
        self.fpga.connect(device, int(self._cmb_baud.currentText()))

    def _on_fpga_connected(self, info: str):
        self._btn_connect.setText("Connect")
        self._btn_connect.setEnabled(False)
        self._btn_disconnect.setEnabled(True)
        self._pulse.set_online(True)
        self._hdr_port.setText(f"PORT: {self._cmb_port.currentData()}")
        self._hdr_mode.setText(f"MODE: {'QPSK' if self._rb_qpsk.isChecked() else 'BPSK'}")
        
        fw_ver = info.split(",")[-1] if info else "1.0"
        self._status_labels["conn"].setText(f" {self._cmb_port.currentData()} connected ")
        self._status_labels["fw"].setText(f" fw: v{fw_ver} ")
        self._set_controls_enabled(True)
        self._stat_status.set_value("READY")
        self.notification_panel.show_notification(
            f"Connected to {self._cmb_port.currentData()} (FW v{fw_ver}). Ready.", "success"
        )

    def _on_fpga_connection_failed(self, reason: str):
        self.fpga.disconnect()
        self._btn_connect.setText("Connect")
        self._btn_connect.setEnabled(True)
        self._btn_disconnect.setEnabled(False)
        self._pulse.set_online(False)
        self._stat_status.set_value("ERR", is_error=True)
        short_reason = reason.replace("\n", " -- ")
        self.notification_panel.show_notification(f"Handshake Failed: {short_reason}", "error")
        QMessageBox.critical(self, "Connection Failed", f"Handshake failed:\n{reason}")

    def _on_disconnect(self):
        self.fpga.disconnect()
        self._btn_connect.setEnabled(True)
        self._btn_disconnect.setEnabled(False)
        self._pulse.set_online(False)
        self._set_controls_enabled(False)
        self._status_labels["conn"].setText(" disconnected ")
        self._stat_status.set_value("OFFLINE")
        self.notification_panel.show_notification("Board disconnected.", "warning")
        if self._backend_visualizer:
            self._backend_visualizer.on_transmission_stopped()

    def _on_connection_lost(self, reason):
        self._on_disconnect()
        self.notification_panel.show_notification(f"Connection Lost: {reason}", "error")

    def _on_transmit(self):
        if not self.serial_manager.is_connected() or self._tx_running:
            if not self.serial_manager.is_connected():
                self.notification_panel.show_notification("Board not connected!", "error")
            return
        mod_type = "QPSK" if self._rb_qpsk.isChecked() else "BPSK"
        
        if self._rb_text.isChecked():
            input_type = "Text"
            input_str = self._txt_text.text()
            bits = mod.text_to_bits(input_str)
            symbols = mod.bits_to_symbols(bits, mod_type)
        elif self._rb_binary.isChecked():
            input_type = "Binary"
            input_str = self._txt_bin.text()
            bits = mod.binary_string_to_bits(input_str)
            symbols = mod.bits_to_symbols(bits, mod_type)
        else:
            input_type = "Random"
            input_str = f"Random {self._spn_random_bits.value()} bits"
            bits = mod.random_bits(self._spn_random_bits.value())
            symbols = mod.bits_to_symbols(bits, mod_type)

        if not symbols:
            return
        self._symbols = []
        self._iq_history = []
        self._tx_running = True
        self._start_time = time.time()
        self._btn_transmit.setEnabled(False)
        self._stat_status.set_value("BUSY")
        self.statusBar().showMessage(f"⚡ Transmitting and plotting {len(symbols)} {mod_type} symbols...")
        self.notification_panel.show_notification(
            f"⚡ Transmitting and plotting {len(symbols)} {mod_type} symbols...", "busy"
        )
        
        self._last_tx_input_type = input_type
        self._last_tx_input_str = input_str
        self._last_tx_bits = bits
        self._last_tx_symbols = symbols
        self._last_tx_mod_type = mod_type
        self._last_tx_results = []
        self._last_tx_done = False

        if self._backend_visualizer:
            self._backend_visualizer.on_transmission_start(input_type, input_str, bits, symbols, mod_type)
        self.fpga.transmit_symbols_async(symbols, mod_type)

    def _on_symbol_result(self, idx, total, symbol, sin_f, cos_f, i_val, q_val):
        """Decoupled: only appends to memory, no UI rendering."""
        mod_type = "QPSK" if self._rb_qpsk.isChecked() else "BPSK"
        self._symbols.append(symbol)
        self._iq_history.append((i_val, q_val))
        elapsed = time.time() - self._start_time if self._start_time else 0.001
        bits = len(self._symbols) * (1 if mod_type == "BPSK" else 2)
        rate = bits / elapsed
        self._last_symbol_data = (idx, total, symbol, sin_f, cos_f, i_val, q_val, elapsed, rate)
        self._last_tx_results.append((idx, total, symbol, sin_f, cos_f, i_val, q_val))
        if self._backend_visualizer:
            self._backend_visualizer.on_symbol_result(idx, total, symbol, sin_f, cos_f, i_val, q_val)

    def _on_ui_refresh(self):
        """Throttled UI update to prevent event loop starvation."""
        if self._last_symbol_data is None:
            return
        if self._last_rendered_count == len(self._symbols):
            return
        
        self._last_rendered_count = len(self._symbols)
        idx, total, symbol, sin_f, cos_f, i_val, q_val, elapsed, rate = self._last_symbol_data
        mod_type = "QPSK" if self._rb_qpsk.isChecked() else "BPSK"

        self._stat_symbol.set_value_clean(mod.symbol_to_bit_string(symbol, mod_type))
        self._stat_phase.set_value_clean(mod.expected_phase_deg(symbol, mod_type), suffix="°")
        self._stat_sin.set_value_clean(sin_f)
        self._stat_cos.set_value_clean(cos_f)
        self._stat_i.set_value_clean(i_val)
        self._stat_q.set_value_clean(q_val)
        self._stat_count.set_value_clean(f"{len(self._symbols)}/{total}")
        self._stat_exec.set_value_clean(elapsed, suffix=" s")
        self._stat_rate.set_value_clean(rate, suffix=" bps")
        self._status_labels["tx"].setText(f" tx: {len(self._symbols)} ")
        
        now = time.time()
        if now - self._last_plot_time > 0.6 or len(self._symbols) == total:
            self._last_plot_time = now
            self._waveform_canvas.plot(self._symbols, mod_type, self._iq_history, table_symbols=self._symbols)
            self._constellation_canvas.plot(mod_type, self._iq_history, self._symbols)

    def _on_progress(self, current, total):
        pass

    def _on_transmission_done(self, elapsed, count):
        self._tx_running = False
        self._btn_transmit.setEnabled(True)
        self._stat_status.set_value("IDLE")
        mod_type = "QPSK" if self._rb_qpsk.isChecked() else "BPSK"
        self._waveform_canvas.plot(self._symbols, mod_type, self._iq_history, table_symbols=self._symbols)
        self._constellation_canvas.plot(mod_type, self._iq_history, self._symbols)
        self.statusBar().showMessage(f"✅ Transmission & Plotting Complete: {count} {mod_type} symbols plotted in {elapsed:.3f} s.", 5000)
        self.notification_panel.show_notification(
            f"✅ Transmission & Plotting Complete: {count} {mod_type} symbols plotted in {elapsed:.3f} s.", "success"
        )
        self._last_tx_done = True
        self._last_tx_elapsed = elapsed
        self._last_tx_count = count
        if self._backend_visualizer:
            self._backend_visualizer.on_transmission_done(elapsed, count)

    def _on_fpga_error(self, msg):
        self._tx_running = False
        self._btn_transmit.setEnabled(True)
        self._stat_status.set_value("ERR", is_error=True)
        self.notification_panel.show_notification(f"FPGA Error: {msg}", "error")
        if self._backend_visualizer:
            self._backend_visualizer.on_transmission_stopped()

    def _on_clear(self):
        self._symbols = []
        self._iq_history = []
        self._last_symbol_data = None
        self._last_rendered_count = 0
        self._waveform_canvas.reset()
        self._constellation_canvas.reset()
        for s in (self._stat_symbol, self._stat_phase, self._stat_sin, self._stat_cos,
                  self._stat_exec, self._stat_i, self._stat_q, self._stat_count, self._stat_rate):
            s.set_value(0 if s.is_numeric else "—")

    def _on_reset_view(self):
        self._waveform_canvas.reset_zoom()
        self._constellation_canvas.reset_zoom()
        self.statusBar().showMessage("Views reset to default zoom.", 3000)
        self.notification_panel.show_notification("Views reset to default zoom.", "info")

    def _on_export(self):
        now = time.time()
        if now - getattr(self, '_last_export_close_time', 0) < 0.3:
            return
        menu = QMenu(self)
        menu.setStyleSheet(
            f"QMenu {{ background-color: {THEME['C_SURFACE3']}; color: {THEME['C_TEXT']}; "
            f"border: 1px solid {THEME['C_BORDER']}; border-radius: 6px; padding: 6px; font-size: 13px; min-width: 250px; }} "
            f"QMenu::item {{ padding: 8px 24px 8px 12px; border-radius: 4px; }} "
            f"QMenu::item:selected {{ background-color: {THEME['C_ACCENT']}; color: #ffffff; }}"
        )
        a_csv = menu.addAction("Export Data as CSV")
        a_png_w = menu.addAction("Export Waveform as PNG")
        a_png_c = menu.addAction("Export Constellation as PNG")
        a_svg_w = menu.addAction("Export Waveform as SVG")
        a_svg_c = menu.addAction("Export Constellation as SVG")
        a_pdf_w = menu.addAction("Export Waveform as PDF")
        a_pdf_c = menu.addAction("Export Constellation as PDF")
        
        self._btn_export_top.setText("Export ▴")
        def on_hide():
            self._last_export_close_time = time.time()
            self._btn_export_top.setText("Export ▾")
        menu.aboutToHide.connect(on_hide)
        action = menu.exec(self._btn_export_top.mapToGlobal(self._btn_export_top.rect().bottomLeft()))
        self._btn_export_top.setText("Export ▾")
        if action == a_csv:
            self._export_csv()
        elif action in (a_png_w, a_svg_w, a_pdf_w):
            ext = action.text()[-3:].lower()
            path, _ = QFileDialog.getSaveFileName(self, f"Export Waveform {ext.upper()}", "", f"{ext.upper()} Files (*.{ext})")
            if path:
                self._waveform_canvas.fig.savefig(path, format=ext, dpi=300, bbox_inches='tight', facecolor=THEME["C_BG"])
                self.notification_panel.show_notification(f"Exported to {os.path.basename(path)}.", "success")
        elif action in (a_png_c, a_svg_c, a_pdf_c):
            ext = action.text()[-3:].lower()
            path, _ = QFileDialog.getSaveFileName(self, f"Export Constellation {ext.upper()}", "", f"{ext.upper()} Files (*.{ext})")
            if path:
                self._constellation_canvas.fig.savefig(path, format=ext, dpi=300, bbox_inches='tight', facecolor=THEME["C_BG"])
                self.notification_panel.show_notification(f"Exported to {os.path.basename(path)}.", "success")

    def _export_csv(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export CSV", "", "CSV Files (*.csv)")
        if not path or not self._symbols:
            return
        mod_type = "QPSK" if self._rb_qpsk.isChecked() else "BPSK"
        with open(path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["Index", "Bits", "Phase", "I_Val", "Q_Val", "DAC_I", "DAC_Q"])
            for i, (sym, (I, Q)) in enumerate(zip(self._symbols, self._iq_history)):
                w.writerow([i, mod.symbol_to_bit_string(sym, mod_type), mod.expected_phase_deg(sym, mod_type), I, Q, I, Q])
        self.notification_panel.show_notification(f"CSV exported to {os.path.basename(path)}.", "success")

    def _show_data_table(self):
        if not self._symbols:
            return
        dialog = QDialog(self)
        dialog.setWindowTitle("Transmitted Data Table")
        dialog.resize(700, 450)
        dialog.setStyleSheet(build_stylesheet())
        
        layout = QVBoxLayout(dialog)
        table = QTableWidget(len(self._symbols), 6)
        table.setHorizontalHeaderLabels(["Index", "Symbol", "Bits", "Phase", "I Phase", "Q Phase"])
        table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        table.verticalHeader().setVisible(False)
        table.setAlternatingRowColors(True)
        table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        table.setStyleSheet(
            f"QTableWidget {{ background-color: {THEME['C_SURFACE2']}; alternate-background-color: {THEME['C_SURFACE']}; "
            f"color: {THEME['C_TEXT']}; gridline-color: {THEME['C_BORDER']}; font-family: 'Cascadia Mono', monospace; }}"
            f"QHeaderView::section {{ background-color: {THEME['C_SURFACE3']}; color: {THEME['C_WHITE']}; font-weight: bold; padding: 6px; }}"
        )
        
        mod_type = "QPSK" if self._rb_qpsk.isChecked() else "BPSK"
        for i, (sym, (I, Q)) in enumerate(zip(self._symbols, self._iq_history)):
            items = [
                QTableWidgetItem(str(i)),
                QTableWidgetItem(f"0x{sym:02X}"),
                QTableWidgetItem(mod.symbol_to_bit_string(sym, mod_type)),
                QTableWidgetItem(f"{mod.expected_phase_deg(sym, mod_type)}°"),
                QTableWidgetItem(f"{I:.4f}"),
                QTableWidgetItem(f"{Q:.4f}"),
            ]
            for col, item in enumerate(items):
                item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                table.setItem(i, col, item)
        layout.addWidget(table)
        dialog.exec()

    def _expand_waveform(self):
        self.wave_detail = DetailPlotWindow(
            "Waveform", "QPSK" if self._rb_qpsk.isChecked() else "BPSK",
            self._symbols, self._iq_history, self
        )
        self.wave_detail.show()

    def _expand_constellation(self):
        self.const_detail = DetailPlotWindow(
            "Constellation", "QPSK" if self._rb_qpsk.isChecked() else "BPSK",
            self._symbols, self._iq_history, self
        )
        self.const_detail.show()

    def _set_controls_enabled(self, en: bool):
        for w in (self._btn_transmit, self._rb_bpsk, self._rb_qpsk,
                  self._rb_text, self._rb_binary, self._rb_random,
                  self._txt_text, self._txt_bin, self._spn_random_bits):
            w.setEnabled(en)

    def closeEvent(self, e):
        self.fpga.abort()
        self.serial_manager.disconnect()
        e.accept()