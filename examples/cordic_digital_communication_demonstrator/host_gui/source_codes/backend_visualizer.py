"""
FPGA Backend Processing & Hardware Architecture Visualization Studio
=====================================================================
Live educational verification and visualization of internal ForgeFPGA / Verilog
hardware execution during digital communication transmissions.

Architecture Pipeline:
  quadrant.v
          ↓
  cordic_core.v (Circular CORDIC 8-Iteration Engine)
          ↓
  SIN Register, COS Register
          ↓
  linear_divide.v (Linear Divide CORDIC Quotient Engine)
          ↓
  TAN Register
          ↓
  I/Q Baseband Constellation & RF Waveform
"""

import sys
import math
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QFrame, QScrollArea, QTableWidget,
    QTableWidgetItem, QHeaderView, QGridLayout, QSizePolicy,
    QTextEdit, QAbstractItemView
)
from PyQt6.QtCore import Qt, pyqtSlot
from PyQt6.QtGui import QColor, QFont

from styles import THEME
import modulation as mod


class Card(QFrame):
    """Standard professional dark theme card container for visualization stages."""
    def __init__(self, title: str, subtitle: str = "", parent=None):
        super().__init__(parent)
        self.setObjectName("card")
        self.setStyleSheet(f"""
            QFrame#card {{
                background: {THEME['C_SURFACE']};
                border: 1px solid {THEME['C_BORDER']};
                border-radius: 8px;
            }}
        """)
        self._layout = QVBoxLayout(self)
        self._layout.setContentsMargins(16, 14, 16, 14)
        self._layout.setSpacing(10)

        # Header
        head = QHBoxLayout()
        t_box = QVBoxLayout()
        t_box.setSpacing(3)
        
        t_lbl = QLabel(title)
        t_lbl.setStyleSheet(f"color: {THEME['C_ACCENT']}; font-weight: 800; font-size: 15px; font-family: 'Segoe UI', sans-serif;")
        t_box.addWidget(t_lbl)
        
        if subtitle:
            s_lbl = QLabel(subtitle)
            s_lbl.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 12px; font-family: 'Segoe UI', sans-serif;")
            t_box.addWidget(s_lbl)
            
        head.addLayout(t_box)
        head.addStretch(1)
        self._layout.addLayout(head)

    def body_layout(self):
        return self._layout


class BackendVisualizerWindow(QMainWindow):
    """
    Dedicated educational studio window visualizing every stage of the FPGA
    processing pipeline in real-time during transmission.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("FPGA Backend Processing & Hardware Architecture Studio")
        self.resize(1050, 720)
        self.setMinimumSize(900, 600)
        self.setWindowFlags(self.windowFlags() & ~Qt.WindowType.WindowMaximizeButtonHint)

        self._symbols = []
        self._bits = []
        self._iq_history = []
        self._mod_type = "QPSK"
        self._current_idx = -1
        self._input_type = "Text"

        # CORDIC Q14 Constants from Verilog
        self.K_INV_Q14 = 9949  # 0.607252935 * 16384
        self.ATAN_TABLE_Q14 = [
            12868, 7596, 4014, 2037, 1022, 512, 256, 128,
            64,    32,   16,   8,    4,    2,   1,   0
        ]

        self._build_ui()
        self._apply_styles()
        self.reset_visualization()

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_lay = QVBoxLayout(central)
        main_lay.setContentsMargins(16, 16, 16, 16)
        main_lay.setSpacing(12)

        # ── Top Toolbar ────────────────────────────────────────────
        top_bar = QWidget()
        tb_lay = QHBoxLayout(top_bar)
        tb_lay.setContentsMargins(0, 0, 0, 0)

        t = QLabel("Backend Pipeline")
        t.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 19px; font-weight: 800; font-family: 'Segoe UI', sans-serif;")
        tb_lay.addWidget(t)
        tb_lay.addStretch(1)

        btn_clear = QPushButton("Clear")
        btn_clear.setMinimumHeight(36)
        btn_clear.setMinimumWidth(80)
        btn_clear.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_clear.clicked.connect(self.reset_visualization)
        
        btn_close = QPushButton("Close")
        btn_close.setObjectName("primary")
        btn_close.setMinimumHeight(36)
        btn_close.setMinimumWidth(80)
        btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_close.clicked.connect(self.close)

        tb_lay.addWidget(btn_clear)
        tb_lay.addWidget(btn_close)
        main_lay.addWidget(top_bar)

        # ── Main Scrollable Pipeline View ──────────────────────────
        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll_area.setStyleSheet(f"background: {THEME['C_BG']};")

        scroll_content = QWidget()
        self.pipe_lay = QVBoxLayout(scroll_content)
        self.pipe_lay.setContentsMargins(8, 8, 16, 16)
        self.pipe_lay.setSpacing(12)

        self._build_pipeline_stages()
        
        # Back to Top Button
        btn_top = QPushButton("⬆  Scroll Back to Top")
        btn_top.setMinimumHeight(44)
        btn_top.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_top.setStyleSheet(f"""
            QPushButton {{
                background: {THEME['C_SURFACE2']};
                color: {THEME['C_CYAN']};
                font-family: 'Segoe UI', sans-serif;
                font-weight: 700;
                font-size: 14px;
                border: 1px solid {THEME['C_BORDER']};
                border-radius: 6px;
            }}
            QPushButton:hover {{
                background: {THEME['C_ACCENT']};
                color: #000000;
            }}
        """)
        btn_top.clicked.connect(lambda: self.scroll_area.verticalScrollBar().setValue(0))
        self.pipe_lay.addSpacing(10)
        self.pipe_lay.addWidget(btn_top)
        self.pipe_lay.addStretch(1)

        self.scroll_area.setWidget(scroll_content)
        main_lay.addWidget(self.scroll_area, 1)

    def _create_arrow(self, text="↓"):
        lbl = QLabel(text)
        lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl.setStyleSheet(f"color: #007ACC; font-size: 22px; font-weight: 900; margin: 2px 0px;")
        return lbl

    def _setup_table(self, table: QTableWidget, headers: list):
        table.setColumnCount(len(headers))
        table.setHorizontalHeaderLabels(headers)
        table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        table.setAlternatingRowColors(True)
        table.verticalHeader().setVisible(False)
        table.setVerticalScrollMode(QAbstractItemView.ScrollMode.ScrollPerPixel)
        table.setHorizontalScrollMode(QAbstractItemView.ScrollMode.ScrollPerPixel)
        table.setStyleSheet(f"""
            QTableWidget {{
                background-color: {THEME['C_SURFACE2']};
                color: #E0E4F0;
                gridline-color: rgba(255, 255, 255, 0.08);
                border: 1px solid rgba(255, 255, 255, 0.12);
                border-radius: 6px;
                font-family: 'Segoe UI', sans-serif;
                font-size: 13px;
            }}
            QTableWidget::item {{
                padding: 6px 10px;
                border-bottom: 1px solid rgba(255, 255, 255, 0.04);
            }}
            QTableWidget::item:selected {{
                background-color: rgba(0, 210, 255, 0.15);
                color: #FFFFFF;
            }}
            QHeaderView::section {{
                background-color: {THEME['C_SURFACE3']};
                color: #00D2FF;
                font-weight: 700;
                font-size: 12px;
                font-family: 'Segoe UI', sans-serif;
                padding: 8px 10px;
                border: none;
                border-right: 1px solid rgba(255, 255, 255, 0.08);
                border-bottom: 1px solid rgba(255, 255, 255, 0.15);
                text-transform: uppercase;
            }}
        """)

    def _build_pipeline_stages(self):
        mono_font = QFont("Consolas", 13, QFont.Weight.Bold)
        mono_font.setStyleHint(QFont.StyleHint.Monospace)

        # ── INPUT SECTION ──────────────────────────────────────────
        c_in = Card("INPUT SECTION: ORIGINAL MESSAGE / PAYLOAD", "Raw user message string or generated binary bitstream")
        self.lbl_input_msg = QLabel("—")
        self.lbl_input_msg.setFont(mono_font)
        self.lbl_input_msg.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 16px; font-weight: bold; padding: 10px; background: {THEME['C_SURFACE2']}; border-radius: 6px; border: 1px solid rgba(255, 255, 255, 0.12);")
        self.lbl_input_msg.setWordWrap(True)
        c_in.body_layout().addWidget(self.lbl_input_msg)
        self.pipe_lay.addWidget(c_in)
        
        self.arrow_in = self._create_arrow("↓")
        self.pipe_lay.addWidget(self.arrow_in)

        # ── STAGE 1: ASCII CONVERSION (Skipped if Binary/Random) ───
        self.card_stage1 = Card("STAGE 1: ASCII CHARACTER DECODING", "Character to ASCII Decimal and Hexadecimal representation (Skipped for raw binary input)")
        self.table_stage1 = QTableWidget()
        self._setup_table(self.table_stage1, ["S.No.", "Character", "ASCII Decimal", "ASCII Hex"])
        self.table_stage1.setMinimumHeight(140)
        self.table_stage1.setMaximumHeight(200)
        self.card_stage1.body_layout().addWidget(self.table_stage1)
        self.pipe_lay.addWidget(self.card_stage1)
        
        self.arrow_stage1 = self._create_arrow("↓")
        self.pipe_lay.addWidget(self.arrow_stage1)

        # ── STAGE 2: BINARY CONVERSION ─────────────────────────────
        c_s2 = Card("STAGE 2: 8-BIT BINARY SERIALIZATION", "Every ASCII byte expanded into 8-bit binary format")
        self.lbl_stage2_bytes = QLabel("—")
        self.lbl_stage2_bytes.setFont(mono_font)
        self.lbl_stage2_bytes.setStyleSheet(f"color: {THEME['C_CYAN']}; font-size: 14px; padding: 8px; background: {THEME['C_SURFACE2']}; border-radius: 6px; border: 1px solid rgba(255, 255, 255, 0.08);")
        self.lbl_stage2_bytes.setWordWrap(True)
        c_s2.body_layout().addWidget(self.lbl_stage2_bytes)
        self.pipe_lay.addWidget(c_s2)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 3: BIT STREAM ────────────────────────────────────
        c_s3 = Card("STAGE 3: SERIALIZED BITSTREAM & LIVE TX CURSOR", "Continuous stream sent to modulator; highlighted orange box indicates currently transmitting bit(s)")
        self.txt_stage3_stream = QTextEdit()
        self.txt_stage3_stream.setFont(mono_font)
        self.txt_stage3_stream.setReadOnly(True)
        self.txt_stage3_stream.setMinimumHeight(80)
        self.txt_stage3_stream.setMaximumHeight(130)
        self.txt_stage3_stream.setStyleSheet(f"background: {THEME['C_SURFACE2']}; color: {THEME['C_TEXT']}; border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 6px; padding: 8px; font-size: 14px;")
        c_s3.body_layout().addWidget(self.txt_stage3_stream)
        self.pipe_lay.addWidget(c_s3)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 4: MODULATION ────────────────────────────────────
        c_s4 = Card("STAGE 4: DIGITAL MODULATION & PHASE MAPPING", "BPSK (1-bit -> Phase) or QPSK (Dibit -> Phase) mapping table")
        self.table_stage4 = QTableWidget()
        self._setup_table(self.table_stage4, ["S.No.", "Symbol Index", "Bit / Dibit", "Assigned Phase", "Transmission Status"])
        self.table_stage4.setMinimumHeight(160)
        self.table_stage4.setMaximumHeight(230)
        c_s4.body_layout().addWidget(self.table_stage4)
        self.pipe_lay.addWidget(c_s4)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 5: ANGLE CONVERSION ──────────────────────────────
        c_s5 = Card("STAGE 5: ANGLE CONVERSION TO Q2.14 FIXED-POINT INTEGER", "Degrees -> Radians (USB CDC) -> Q2.14 Integer sent over SPI bus to FPGA")
        s5_layout = QHBoxLayout()
        s5_layout.setSpacing(12)
        
        self.lbl_stage5_deg = self._create_box("Phase (Degrees)", "—", THEME['C_WHITE'], mono_font)
        self.lbl_stage5_rad = self._create_box("Radians (USB CDC)", "—", THEME['C_CYAN'], mono_font)
        self.lbl_stage5_q14 = self._create_box("Q2.14 Integer (SPI to FPGA)", "—", THEME['C_GREEN'], mono_font)
        
        s5_layout.addWidget(self.lbl_stage5_deg, 1)
        s5_layout.addWidget(self._create_arrow("➔"), 0)
        s5_layout.addWidget(self.lbl_stage5_rad, 1)
        s5_layout.addWidget(self._create_arrow("➔"), 0)
        s5_layout.addWidget(self.lbl_stage5_q14, 1)
        c_s5.body_layout().addLayout(s5_layout)
        self.pipe_lay.addWidget(c_s5)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 6: QUADRANT REDUCTION ────────────────────────────
        c_s6 = Card("STAGE 6: QUADRANT PRE-PROCESSING (quadrant.v)", "Verilog hardware reduction to Quadrant I (0° - 90°) & sign bit generation")
        s6_layout = QHBoxLayout()
        s6_layout.setSpacing(12)
        
        self.lbl_stage6_orig = self._create_box("Original Angle", "—", THEME['C_WHITE'], mono_font)
        self.lbl_stage6_quad = self._create_box("Detected Quadrant", "—", THEME['C_CYAN'], mono_font)
        self.lbl_stage6_red  = self._create_box("Reduced Angle (Q14)", "—", THEME['C_GREEN'], mono_font)
        self.lbl_stage6_sneg = self._create_box("sin_neg (Sign Bit)", "—", "#FFB800", mono_font)
        self.lbl_stage6_cneg = self._create_box("cos_neg (Sign Bit)", "—", "#FFB800", mono_font)
        
        s6_layout.addWidget(self.lbl_stage6_orig, 1)
        s6_layout.addWidget(self.lbl_stage6_quad, 1)
        s6_layout.addWidget(self.lbl_stage6_red,  1)
        s6_layout.addWidget(self.lbl_stage6_sneg, 1)
        s6_layout.addWidget(self.lbl_stage6_cneg, 1)
        c_s6.body_layout().addLayout(s6_layout)
        self.pipe_lay.addWidget(c_s6)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 7: CIRCULAR CORDIC CORE ──────────────────────────
        c_s7 = Card("STAGE 7: CIRCULAR CORDIC ITERATIVE ENGINE (cordic_core.v)", "8 Hardware Circular CORDIC shift-add iterations executing in real-time")
        self.table_stage7 = QTableWidget()
        self._setup_table(self.table_stage7, [
            "S.No.", "Iteration (iter)", "X (Q14 / Float)", "Y (Q14 / Float)", "Z (Q14 Angle)", "Remaining (Deg)", "Remaining (Rad)"
        ])
        self.table_stage7.setMinimumHeight(250)
        self.table_stage7.setMaximumHeight(310)
        c_s7.body_layout().addWidget(self.table_stage7)
        self.pipe_lay.addWidget(c_s7)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 8: CIRCULAR CORDIC OUTPUT (SIN / COS ONLY) ───────
        c_s8 = Card("STAGE 8: CIRCULAR CORDIC HARDWARE OUTPUT REGISTERS", "Exact SIN and COS values generated by cordic_core.v after sign restoration")
        s8_grid = QHBoxLayout()
        s8_grid.setSpacing(16)
        self.box_stage8_sin = self._create_box("FPGA Hardware SIN Register", "—", THEME['C_CYAN'], mono_font)
        self.box_stage8_cos = self._create_box("FPGA Hardware COS Register", "—", THEME['C_CYAN'], mono_font)
        s8_grid.addWidget(self.box_stage8_sin)
        s8_grid.addWidget(self.box_stage8_cos)
        c_s8.body_layout().addLayout(s8_grid)
        self.pipe_lay.addWidget(c_s8)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 9: LINEAR DIVIDE CORDIC (linear_divide.v) ────────
        c_s9 = Card("STAGE 9: LINEAR DIVIDE CORDIC ENGINE (linear_divide.v)", "Verilog hardware linear vectoring CORDIC dividing SIN by COS in real-time")
        self.table_stage9_div = QTableWidget()
        self._setup_table(self.table_stage9_div, [
            "S.No.", "Iteration (iter)", "Divisor X (COS)", "Dividend Y (SIN / Remainder)", "Quotient Z (TAN)", "Step Value (2^-i)"
        ])
        self.table_stage9_div.setMinimumHeight(250)
        self.table_stage9_div.setMaximumHeight(310)
        c_s9.body_layout().addWidget(self.table_stage9_div)
        self.pipe_lay.addWidget(c_s9)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 10: LINEAR DIVIDE OUTPUT (TAN REGISTER) ──────────
        c_s10 = Card("STAGE 10: FPGA HARDWARE TAN REGISTER (linear_divide.v Output)", "Exact tangent quotient generated inside ForgeFPGA by linear_divide.v module")
        self.box_stage10_tan = self._create_box("FPGA Hardware TAN Register (linear_divide.v)", "—", THEME['C_GREEN'], mono_font)
        c_s10.body_layout().addWidget(self.box_stage10_tan)
        self.pipe_lay.addWidget(c_s10)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 11: I/Q SYMBOL & CONSTELLATION ───────────────────
        c_s11 = Card("STAGE 11: I/Q BASEBAND SYMBOL & CONSTELLATION POINT", "I = COS, Q = SIN plotted on orthogonal phase plane")
        self.lbl_stage11_iq = QLabel("I = —   |   Q = —")
        self.lbl_stage11_iq.setFont(mono_font)
        self.lbl_stage11_iq.setStyleSheet(f"color: {THEME['C_WHITE']}; font-weight: bold; font-size: 15px; padding: 8px; background: {THEME['C_SURFACE2']}; border-radius: 6px; border: 1px solid rgba(255, 255, 255, 0.08);")
        c_s11.body_layout().addWidget(self.lbl_stage11_iq)
        
        self.lbl_stage11_status = QLabel("✅  Constellation diagram is active and plotted on the main Dashboard.")
        self.lbl_stage11_status.setStyleSheet(f"color: {THEME['C_GREEN']}; font-weight: 700; font-size: 13px; font-family: 'Segoe UI', sans-serif; padding: 4px;")
        c_s11.body_layout().addWidget(self.lbl_stage11_status)
        self.pipe_lay.addWidget(c_s11)
        self.pipe_lay.addWidget(self._create_arrow("↓"))

        # ── STAGE 12: RF WAVEFORM ──────────────────────────────────
        c_s12 = Card("STAGE 12: RF MODULATED WAVEFORM GENERATION", "Baseband bits → Carrier wave → Modulated RF signal")
        self.lbl_stage12_status = QLabel("✅  RF Modulated Waveform generation is complete and plotted on the main Dashboard.")
        self.lbl_stage12_status.setStyleSheet(f"color: {THEME['C_GREEN']}; font-weight: 700; font-size: 13px; font-family: 'Segoe UI', sans-serif; padding: 8px; background: {THEME['C_SURFACE2']}; border-radius: 6px; border: 1px solid rgba(255, 255, 255, 0.08);")
        c_s12.body_layout().addWidget(self.lbl_stage12_status)
        self.pipe_lay.addWidget(c_s12)

    def _create_box(self, title: str, val: str, color: str = None, font: QFont = None) -> QFrame:
        if color is None:
            color = THEME['C_CYAN']
        box = QFrame()
        box.setStyleSheet(f"""
            QFrame {{
                background: {THEME['C_SURFACE2']};
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 6px;
            }}
        """)
        lay = QVBoxLayout(box)
        lay.setContentsMargins(10, 8, 10, 8)
        lay.setSpacing(4)
        t = QLabel(title)
        t.setStyleSheet(f"color: #8E99B3; font-size: 11px; font-weight: 700; font-family: 'Segoe UI', sans-serif; text-transform: uppercase; letter-spacing: 0.5px; border: none; background: transparent;")
        v = QLabel(val)
        v.setObjectName("val_label")
        if font:
            v.setFont(font)
        else:
            v.setFont(QFont("Consolas", 14, QFont.Weight.Bold))
        v.setStyleSheet(f"color: {color}; font-size: 15px; font-weight: 800; border: none; background: transparent;")
        v.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(t)
        lay.addWidget(v)
        return box

    def _set_box_val(self, box: QFrame, val: str):
        lbl = box.findChild(QLabel, "val_label")
        if lbl:
            lbl.setText(val)

    def _apply_styles(self):
        self.setStyleSheet(f"""
            QMainWindow {{
                background-color: {THEME['C_BG']};
            }}
        """)

    # ── LIVE SYNCHRONIZATION SIGNALS ───────────────────────────

    def sync_with_state(self, input_type, input_str, bits, symbols, mod_type, results, done, elapsed, count):
        """Immediately populates all stages with the latest transmission state."""
        self.on_transmission_start(input_type, input_str, bits, symbols, mod_type)
        for res in results:
            self.on_symbol_result(*res)
        if done:
            self.on_transmission_done(elapsed, count)

    @pyqtSlot(str, str, list, list, str)
    def on_transmission_start(self, input_type: str, input_str: str, bits: list, symbols: list, mod_type: str):
        """Called when transmission begins in main window."""
        self._input_type = input_type
        self._mod_type = mod_type
        self._bits = bits
        self._symbols = symbols
        self._iq_history = []
        self._current_idx = 0

        # Input Section
        self.lbl_input_msg.setText(f"[{input_type}]  {input_str}")

        # Stage 1: ASCII (Skipped if Binary or Random)
        is_text = (input_type == "Text")
        self.card_stage1.setVisible(is_text)
        self.arrow_stage1.setVisible(is_text)
        
        self.table_stage1.setRowCount(0)
        if is_text:
            self.table_stage1.setRowCount(len(input_str))
            for r, ch in enumerate(input_str):
                c_val = ord(ch)
                self.table_stage1.setItem(r, 0, QTableWidgetItem(str(r + 1)))
                self.table_stage1.setItem(r, 1, QTableWidgetItem(f"'{ch}'"))
                self.table_stage1.setItem(r, 2, QTableWidgetItem(str(c_val)))
                self.table_stage1.setItem(r, 3, QTableWidgetItem(f"0x{c_val:02X}"))
                for c in range(4):
                    if self.table_stage1.item(r, c):
                        self.table_stage1.item(r, c).setTextAlignment(Qt.AlignmentFlag.AlignCenter)

        # Stage 2: Binary Bytes
        if is_text:
            byte_strs = [f"'{ch}': {ord(ch):08b}" for ch in input_str]
            self.lbl_stage2_bytes.setText("  |  ".join(byte_strs))
        else:
            self.lbl_stage2_bytes.setText(f"Raw Bitstream ({len(bits)} bits): {''.join(map(str, bits[:64]))}...")

        # Stage 3: Bit Stream
        self._update_stage3_highlight(0)

        # Stage 4: Modulation Table
        self.table_stage4.setRowCount(len(symbols))
        for r, sym in enumerate(symbols):
            phase_deg = mod.expected_phase_deg(sym, mod_type)
            if mod_type == "BPSK":
                bit_str = str(sym & 1)
            else:
                bit_str = f"{sym & 3:02b}"
            self.table_stage4.setItem(r, 0, QTableWidgetItem(str(r + 1)))
            self.table_stage4.setItem(r, 1, QTableWidgetItem(f"Sym #{r}"))
            self.table_stage4.setItem(r, 2, QTableWidgetItem(bit_str))
            self.table_stage4.setItem(r, 3, QTableWidgetItem(f"{phase_deg}°"))
            self.table_stage4.setItem(r, 4, QTableWidgetItem("⏳ Pending..."))
            for c in range(5):
                if self.table_stage4.item(r, c):
                    self.table_stage4.item(r, c).setTextAlignment(Qt.AlignmentFlag.AlignCenter)

        # Clear downward stages until first symbol arrives
        self._clear_downward_stages()

    @pyqtSlot(int, int, int, float, float, float, float)
    def on_symbol_result(self, idx: int, total: int, symbol: int, sin_f: float, cos_f: float, i_val: float, q_val: float):
        """Called for every symbol received from FPGA."""
        self._current_idx = idx
        self._iq_history.append((i_val, q_val))

        # Update Stage 3 highlight
        self._update_stage3_highlight(idx)

        # Update Stage 4 Table
        if idx < self.table_stage4.rowCount():
            it = self.table_stage4.item(idx, 4)
            if it:
                it.setText("✅ Transmitted")
                it.setForeground(QColor(THEME['C_GREEN']))
            self.table_stage4.selectRow(idx)

        # Stage 5: Angle Conversion
        phase_deg = mod.expected_phase_deg(symbol, self._mod_type)
        angle_rad = math.radians(phase_deg)
        q14_val = int(round(angle_rad * 16384.0))
        self._set_box_val(self.lbl_stage5_deg, f"{phase_deg}°")
        self._set_box_val(self.lbl_stage5_rad, f"{angle_rad:.6f} rad")
        self._set_box_val(self.lbl_stage5_q14, f"{q14_val} (0x{q14_val:04X})")

        # Stage 6: Quadrant Pre-processing (quadrant.v math)
        if phase_deg <= 90:
            quad_str = "Quadrant I (0° - 90°)"
            red_deg = phase_deg
            sneg, cneg = 0, 0
        elif phase_deg <= 180:
            quad_str = "Quadrant II (90° - 180°)"
            red_deg = 180.0 - phase_deg
            sneg, cneg = 0, 1
        elif phase_deg <= 270:
            quad_str = "Quadrant III (180° - 270°)"
            red_deg = phase_deg - 180.0
            sneg, cneg = 1, 1
        else:
            quad_str = "Quadrant IV (270° - 360°)"
            red_deg = 360.0 - phase_deg
            sneg, cneg = 1, 0

        red_rad = math.radians(red_deg)
        red_q14 = int(round(red_rad * 16384.0))
        self._set_box_val(self.lbl_stage6_orig, f"{phase_deg}°")
        self._set_box_val(self.lbl_stage6_quad, quad_str)
        self._set_box_val(self.lbl_stage6_red,  f"{red_deg}° ({red_q14} Q14)")
        self._set_box_val(self.lbl_stage6_sneg, str(sneg))
        self._set_box_val(self.lbl_stage6_cneg, str(cneg))

        # Stage 7: Circular CORDIC Core 8 Iterations (cordic_core.v math)
        x = self.K_INV_Q14
        y = 0
        z = red_q14
        self.table_stage7.setRowCount(8)
        for iter_idx in range(8):
            z_deg = math.degrees(z / 16384.0)
            z_rad = z / 16384.0
            self.table_stage7.setItem(iter_idx, 0, QTableWidgetItem(str(iter_idx + 1)))
            self.table_stage7.setItem(iter_idx, 1, QTableWidgetItem(f"Iter {iter_idx}"))
            self.table_stage7.setItem(iter_idx, 2, QTableWidgetItem(f"{x} ({x/16384.0:.4f})"))
            self.table_stage7.setItem(iter_idx, 3, QTableWidgetItem(f"{y} ({y/16384.0:.4f})"))
            self.table_stage7.setItem(iter_idx, 4, QTableWidgetItem(f"{z}"))
            self.table_stage7.setItem(iter_idx, 5, QTableWidgetItem(f"{z_deg:.2f}°"))
            self.table_stage7.setItem(iter_idx, 6, QTableWidgetItem(f"{z_rad:.4f} rad"))
            for c in range(7):
                if self.table_stage7.item(iter_idx, c):
                    self.table_stage7.item(iter_idx, c).setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            
            if z >= 0:
                x_next = x - (y >> iter_idx)
                y_next = y + (x >> iter_idx)
                z_next = z - self.ATAN_TABLE_Q14[iter_idx]
            else:
                x_next = x + (y >> iter_idx)
                y_next = y - (x >> iter_idx)
                z_next = z + self.ATAN_TABLE_Q14[iter_idx]
            x, y, z = x_next, y_next, z_next

        # Stage 8: Circular CORDIC Output (SIN / COS)
        self._set_box_val(self.box_stage8_sin, f"{sin_f:+.8f}")
        self._set_box_val(self.box_stage8_cos, f"{cos_f:+.8f}")

        # Stage 9: Linear Divide CORDIC Engine (linear_divide.v)
        div_x = cos_f
        div_y = sin_f
        div_z = 0.0
        self.table_stage9_div.setRowCount(8)
        for iter_idx in range(8):
            step_val = 2.0 ** (-iter_idx)
            self.table_stage9_div.setItem(iter_idx, 0, QTableWidgetItem(str(iter_idx + 1)))
            self.table_stage9_div.setItem(iter_idx, 1, QTableWidgetItem(f"Iter {iter_idx}"))
            self.table_stage9_div.setItem(iter_idx, 2, QTableWidgetItem(f"{div_x:+.6f}"))
            self.table_stage9_div.setItem(iter_idx, 3, QTableWidgetItem(f"{div_y:+.6f}"))
            self.table_stage9_div.setItem(iter_idx, 4, QTableWidgetItem(f"{div_z:+.6f}"))
            self.table_stage9_div.setItem(iter_idx, 5, QTableWidgetItem(f"{step_val:.6f}"))
            for c in range(6):
                if self.table_stage9_div.item(iter_idx, c):
                    self.table_stage9_div.item(iter_idx, c).setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            
            if div_y >= 0:
                div_y_next = div_y - (div_x * step_val)
                div_z_next = div_z + step_val
            else:
                div_y_next = div_y + (div_x * step_val)
                div_z_next = div_z - step_val
            div_y, div_z = div_y_next, div_z_next

        # Stage 10: Linear Divide Output (TAN Register)
        tan_f = sin_f / cos_f if abs(cos_f) > 1e-9 else 0.0
        self._set_box_val(self.box_stage10_tan, f"{tan_f:+.8f}")

        # Stage 11 & 12 Status update
        self.lbl_stage11_iq.setText(f"I (COS) = {i_val:+.6f}   |   Q (SIN) = {q_val:+.6f}")

    @pyqtSlot(float, int)
    def on_transmission_done(self, elapsed: float, count: int):
        """Called when transmission finishes."""
        self._update_stage3_highlight(len(self._symbols))

    @pyqtSlot()
    def on_transmission_stopped(self):
        """Called if transmission is aborted or disconnected."""
        pass

    def _update_stage3_highlight(self, active_sym_idx: int):
        if not self._bits:
            self.txt_stage3_stream.clear()
            return
        
        bits_per_sym = 1 if self._mod_type == "BPSK" else 2
        active_bit_idx = active_sym_idx * bits_per_sym
        
        bit_str = "".join(map(str, self._bits))
        if active_bit_idx >= len(bit_str):
            html = f'<span style="color: {THEME["C_GREEN"]}; font-weight: bold;">{bit_str}</span>'
        else:
            done_part = bit_str[:active_bit_idx]
            active_part = bit_str[active_bit_idx : active_bit_idx + bits_per_sym]
            pend_part = bit_str[active_bit_idx + bits_per_sym :]
            html = (
                f'<span style="color: {THEME["C_GREEN"]};">{done_part}</span>'
                f'<span style="background-color: #ff8a00; color: #000000; font-weight: bold; padding: 2px;">{active_part}</span>'
                f'<span style="color: {THEME["C_SUBTEXT"]};">{pend_part}</span>'
            )
        self.txt_stage3_stream.setHtml(html)

    def _clear_downward_stages(self):
        self._set_box_val(self.lbl_stage5_deg, "⏳ Waiting...")
        self._set_box_val(self.lbl_stage5_rad, "⏳ Waiting...")
        self._set_box_val(self.lbl_stage5_q14, "⏳ Waiting...")
        
        self._set_box_val(self.lbl_stage6_orig, "⏳ Waiting...")
        self._set_box_val(self.lbl_stage6_quad, "⏳ Waiting...")
        self._set_box_val(self.lbl_stage6_red,  "⏳ Waiting...")
        self._set_box_val(self.lbl_stage6_sneg, "⏳ Waiting...")
        self._set_box_val(self.lbl_stage6_cneg, "⏳ Waiting...")
        
        self.table_stage7.clearContents()
        self.table_stage7.setRowCount(0)
        self._set_box_val(self.box_stage8_sin, "⏳ Waiting...")
        self._set_box_val(self.box_stage8_cos, "⏳ Waiting...")
        
        self.table_stage9_div.clearContents()
        self.table_stage9_div.setRowCount(0)
        self._set_box_val(self.box_stage10_tan, "⏳ Waiting...")
        self.lbl_stage11_iq.setText("I = —   |   Q = —")

    def reset_visualization(self):
        self.lbl_input_msg.setText("No active transmission. Press 'Start Transmission' on Dashboard.")
        self.table_stage1.setRowCount(0)
        self.lbl_stage2_bytes.setText("—")
        self.txt_stage3_stream.clear()
        self.table_stage4.setRowCount(0)
        self._clear_downward_stages()
