"""
serial_monitor.py
═══════════════════════════════════════════════════════════════
Dedicated Serial Protocol & Debug Monitor Studio for the FPGA CORDIC
Demonstrator. Displays real-time and historical TX -> / RX <- ASCII
protocol exchanges with automatic engineering annotations.
"""
import csv
import time
import os
from datetime import datetime

from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QColor, QFont
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QPushButton, QLabel,
    QTableWidget, QTableWidgetItem, QHeaderView, QRadioButton,
    QButtonGroup, QFrame, QFileDialog, QMessageBox, QSizePolicy
)

from styles import THEME, build_stylesheet


def annotate_serial_message(direction: str, text: str) -> str:
    """Provide RF engineering annotations for raw ASCII serial protocol lines."""
    t = text.strip()
    if direction in ("TX", "tx", "TX ->"):
        if t == "PING":
            return "Handshake Probe / Startup Banner Request"
        elif t.startswith("MODE:"):
            return f"Set Modulation Scheme ({t.split(':', 1)[-1]})"
        elif t.startswith("SYM:"):
            return f"Transmit Symbol Vector (Bits: {t.split(':', 1)[-1]})"
        elif t.startswith("ANG:"):
            return f"CORDIC Angle Query ({t.split(':', 1)[-1]} rad)"
        elif t == "RESET":
            return "FPGA Hardware & State Reset"
        else:
            return "ASCII Command Transmission"
    else:
        if t.startswith("READY"):
            return "MCU Startup Banner & Protocol Capability Announcement"
        elif t == "OK":
            return "Command Acknowledge / State Ready"
        elif t.startswith("SIN="):
            return "CORDIC Sine Result Word"
        elif t.startswith("COS="):
            return "CORDIC Cosine Result Word"
        elif t == "DONE":
            return "CORDIC Transaction Complete Flag (End of Packet)"
        elif t.startswith("ERR:"):
            return f"Hardware / Protocol Error ({t})"
        else:
            return "MCU Serial Response"


class SerialMonitorDialog(QDialog):
    """
    Real-time Serial Debug & Protocol Monitor Window.
    Allows RF engineers to inspect every ASCII line sent/received over USB.
    """
    def __init__(self, parent=None, serial_manager=None):
        super().__init__(parent)
        self.serial_manager = serial_manager
        self.setWindowTitle("Serial Protocol & Debug Monitor Studio")
        self.setWindowFlags(self.windowFlags() | Qt.WindowType.WindowMinMaxButtonsHint)
        self.resize(1100, 700)
        self.setStyleSheet(build_stylesheet())

        self._filter_mode = "ALL"  # "ALL", "TX", "RX"
        self._rendered_count = 0

        self._build_ui()
        self._populate_history()

        # Wire real-time live log updates
        if self.serial_manager:
            self.serial_manager.log_message.connect(self._on_live_log)

        # Refresh timer to ensure table scrolling and UI responsiveness
        self._timer = QTimer(self)
        self._timer.setInterval(250)
        self._timer.timeout.connect(self._check_refresh)
        self._timer.start()

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(12)

        # ── Top Toolbar ──────────────────────────────────────────
        toolbar = QFrame()
        toolbar.setObjectName("card")
        th = QHBoxLayout(toolbar)
        th.setContentsMargins(14, 10, 14, 10)
        th.setSpacing(14)

        title_box = QVBoxLayout()
        title_box.setSpacing(2)
        title = QLabel("🔌 Serial Debug & Protocol Monitor")
        title.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 16px; font-weight: 800;")
        sub = QLabel("Live inspection of ASCII line protocol terminated by '\\n' (Single Reader Thread)")
        sub.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 12px;")
        title_box.addWidget(title)
        title_box.addWidget(sub)
        th.addLayout(title_box)
        th.addStretch(1)

        # Filter Radio Buttons
        filter_box = QHBoxLayout()
        filter_box.setSpacing(10)
        lbl_filter = QLabel("Filter:")
        lbl_filter.setStyleSheet(f"color: {THEME['C_ACCENT']}; font-weight: 700; font-size: 12px;")
        filter_box.addWidget(lbl_filter)

        self._rb_all = QRadioButton("All (TX & RX)")
        self._rb_tx  = QRadioButton("TX -> Only")
        self._rb_rx  = QRadioButton("RX <- Only")
        self._rb_all.setChecked(True)

        self._grp = QButtonGroup(self)
        self._grp.addButton(self._rb_all)
        self._grp.addButton(self._rb_tx)
        self._grp.addButton(self._rb_rx)

        self._rb_all.toggled.connect(lambda c: c and self._set_filter("ALL"))
        self._rb_tx.toggled.connect(lambda c: c and self._set_filter("TX"))
        self._rb_rx.toggled.connect(lambda c: c and self._set_filter("RX"))

        filter_box.addWidget(self._rb_all)
        filter_box.addWidget(self._rb_tx)
        filter_box.addWidget(self._rb_rx)
        th.addLayout(filter_box)

        # Buttons
        btn_clear = QPushButton("⟲ Clear Log")
        btn_clear.setObjectName("ghost")
        btn_clear.setMinimumHeight(34)
        btn_clear.clicked.connect(self._clear_log)

        btn_close = QPushButton("✕ Close")
        btn_close.setObjectName("primary")
        btn_close.setMinimumHeight(34)
        btn_close.clicked.connect(self.close)

        th.addWidget(btn_clear)
        th.addWidget(btn_close)
        layout.addWidget(toolbar)

        # ── Table View ───────────────────────────────────────────
        self._table = QTableWidget(0, 4)
        self._table.setHorizontalHeaderLabels([
            "Timestamp", "Direction", "Raw ASCII Protocol Line (ended with \\n)", "Protocol Meaning / Annotation"
        ])
        self._table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        self._table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents)
        self._table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self._table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        self._table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self._table.setAlternatingRowColors(True)
        self._table.verticalHeader().setVisible(False)
        self._table.setStyleSheet(
            f"QTableWidget {{ background-color: {THEME['C_SURFACE2']}; alternate-background-color: {THEME['C_SURFACE']}; "
            f"color: {THEME['C_TEXT']}; gridline-color: {THEME['C_BORDER']}; font-family: 'Cascadia Mono', 'Consolas', monospace; font-size: 13px; }}"
            f"QHeaderView::section {{ background-color: {THEME['C_SURFACE3']}; color: {THEME['C_WHITE']}; font-weight: bold; padding: 8px; border: none; border-bottom: 2px solid {THEME['C_ACCENT']}; }}"
        )
        layout.addWidget(self._table, 1)

        # ── Footer Status ────────────────────────────────────────
        foot = QFrame()
        foot.setStyleSheet(f"background: {THEME['C_SURFACE']}; border-radius: 6px; padding: 4px;")
        fh = QHBoxLayout(foot)
        fh.setContentsMargins(12, 4, 12, 4)
        self._lbl_status = QLabel("Ready. Monitoring live USB serial traffic.")
        self._lbl_status.setStyleSheet(f"color: {THEME['C_CYAN']}; font-size: 11px; font-weight: 600;")
        fh.addWidget(self._lbl_status)
        fh.addStretch(1)
        self._lbl_count = QLabel("Total Messages: 0")
        self._lbl_count.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 11px; font-family: monospace;")
        fh.addWidget(self._lbl_count)
        layout.addWidget(foot, 0)

    def _set_filter(self, mode: str):
        self._filter_mode = mode
        self._rebuild_table()

    def _populate_history(self):
        if not self.serial_manager or not hasattr(self.serial_manager, "history"):
            return
        self._rebuild_table()

    def _rebuild_table(self):
        self._table.setRowCount(0)
        if not self.serial_manager or not hasattr(self.serial_manager, "history"):
            return
        
        for ts, direction, text in self.serial_manager.history:
            self._add_row(ts, direction, text, scroll=False)
        self._table.scrollToBottom()
        self._update_count()

    def _on_live_log(self, msg: str, level: str):
        if level not in ("tx", "rx"):
            return
        direction = "TX" if level == "tx" else "RX"
        text = msg.replace("TX -> ", "").replace("RX <- ", "").strip()
        ts = time.time()
        self._add_row(ts, direction, text, scroll=True)
        self._update_count()

    def _add_row(self, ts: float, direction: str, text: str, scroll: bool = True):
        if self._filter_mode == "TX" and direction != "TX":
            return
        if self._filter_mode == "RX" and direction != "RX":
            return

        row = self._table.rowCount()
        self._table.insertRow(row)

        dt_str = datetime.fromtimestamp(ts).strftime("%H:%M:%S.%f")[:-3]
        dir_str = "TX ->" if direction == "TX" else "RX <-"
        annot_str = annotate_serial_message(direction, text)

        items = [
            QTableWidgetItem(dt_str),
            QTableWidgetItem(dir_str),
            QTableWidgetItem(text),
            QTableWidgetItem(annot_str)
        ]

        c = THEME
        for col, it in enumerate(items):
            it.setTextAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter if col >= 2 else Qt.AlignmentFlag.AlignCenter)
            
            # Color coding
            if direction == "TX":
                if col == 1: it.setForeground(QColor(c["C_ACCENT"]))
                else: it.setForeground(QColor(c["C_WHITE"]))
            else:
                if text.startswith("ERR:"):
                    it.setForeground(QColor(c["C_RED"]))
                elif text.startswith("READY") or text == "DONE":
                    it.setForeground(QColor(c["C_GREEN"]))
                elif col == 1:
                    it.setForeground(QColor(c["C_CYAN"]))
                else:
                    it.setForeground(QColor(c["C_TEXT"]))
            
            if col == 1:
                font = QFont("Cascadia Mono", 10, QFont.Weight.Bold)
                it.setFont(font)

            self._table.setItem(row, col, it)

        if scroll:
            self._table.scrollToBottom()

    def _update_count(self):
        total = len(self.serial_manager.history) if self.serial_manager and hasattr(self.serial_manager, "history") else self._table.rowCount()
        self._lbl_count.setText(f"Total Messages: {total} (Showing: {self._table.rowCount()})")

    def _clear_log(self):
        if self.serial_manager and hasattr(self.serial_manager, "history"):
            self.serial_manager.history.clear()
        self._table.setRowCount(0)
        self._update_count()
        self._lbl_status.setText("Log cleared.")


    def _check_refresh(self):
        pass

    def closeEvent(self, event):
        if self.serial_manager:
            try:
                self.serial_manager.log_message.disconnect(self._on_live_log)
            except Exception:
                pass
        event.accept()
