import math
import csv
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QColor
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QWidget, QLabel, QLineEdit,
    QPushButton, QRadioButton, QButtonGroup, QTableWidget, QTableWidgetItem,
    QHeaderView, QGridLayout, QFrame, QFileDialog, QMessageBox, QSplitter, QSizePolicy
)
from styles import THEME


class CordicCalculatorWidget(QWidget):
    """
    Embeddable Interactive Circular CORDIC Calculator Studio.
    Provides a responsive 3-column splitter layout for direct integration into RF engineering dashboards
    or standalone dialog windows without clipping or overlapping on any resolution.
    """
    notification_triggered = pyqtSignal(str, str)  # (message, level: info/warning/error/success/busy)

    def __init__(self, parent=None, fpga_manager=None, in_dialog=False):
        super().__init__(parent)
        self.fpga_manager = fpga_manager
        self.in_dialog = in_dialog
        self._history = []
        self._calculating = False
        self._pending_angle_rad  = None
        self._pending_exp_sin    = None
        self._pending_exp_cos    = None
        self._pending_exp_tan    = None
        self._pending_disp_ang   = None
        self._pending_mode_str   = None

        self._build_ui()
        self._apply_styles()

        # Wire async result signal
        if self.fpga_manager:
            self.fpga_manager.ang_result.connect(self._on_ang_result)

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(12)

        # ── Header ─────────────────────────────────────────────
        head = QWidget()
        hl = QHBoxLayout(head)
        hl.setContentsMargins(0, 0, 0, 0)

        title_box = QVBoxLayout()
        title_box.setSpacing(2)
        title = QLabel("CORDIC Calculator Studio")
        title.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 16px; font-weight: 800;")
        sub = QLabel("Circular Mode")
        sub.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 12px;")
        title_box.addWidget(title)
        title_box.addWidget(sub)
        hl.addLayout(title_box)
        hl.addStretch(1)
        layout.addWidget(head)

        # ── Main Responsive 3-Column Splitter ───────────────────
        split = QSplitter(Qt.Orientation.Horizontal)
        split.setChildrenCollapsible(False)
        split.setHandleWidth(8)

        # Column 1: Control & Angle Input
        left_panel = QFrame()
        left_panel.setObjectName("panel")
        left_panel.setMinimumWidth(260)
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(14, 14, 14, 14)
        left_layout.setSpacing(10)

        lbl_mode = QLabel("Angle Mode")
        lbl_mode.setStyleSheet(f"color: {THEME['C_ACCENT']}; font-weight: 700; font-size: 13px;")
        left_layout.addWidget(lbl_mode)

        mode_row = QHBoxLayout()
        self._rb_deg = QRadioButton("Degree (°)")
        self._rb_rad = QRadioButton("Radian (rad)")
        self._rb_deg.setChecked(True)
        self._mode_grp = QButtonGroup(self)
        self._mode_grp.addButton(self._rb_deg)
        self._mode_grp.addButton(self._rb_rad)
        mode_row.addWidget(self._rb_deg)
        mode_row.addWidget(self._rb_rad)
        mode_row.addStretch(1)
        left_layout.addLayout(mode_row)

        lbl_input = QLabel("Enter Angle Value")
        lbl_input.setStyleSheet(f"color: {THEME['C_ACCENT']}; font-weight: 700; font-size: 13px;")
        left_layout.addWidget(lbl_input)

        self._txt_angle = QLineEdit()
        self._txt_angle.setPlaceholderText("e.g. 30, 45, pi/6, pi/4")
        self._txt_angle.setStyleSheet(
            f"background: {THEME['C_SURFACE2']}; color: {THEME['C_WHITE']}; "
            f"font-size: 15px; padding: 6px; border: 1px solid {THEME['C_BORDER']}; border-radius: 4px;"
        )
        self._txt_angle.returnPressed.connect(self._on_calculate)
        left_layout.addWidget(self._txt_angle)

        exec_row = QHBoxLayout()
        exec_row.setSpacing(8)
        self._btn_calc = QPushButton("Execute CORDIC")
        self._btn_calc.setObjectName("primary")
        self._btn_calc.setMinimumHeight(36)
        self._btn_calc.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self._btn_calc.clicked.connect(self._on_calculate)
        exec_row.addWidget(self._btn_calc, 3)

        self._btn_clear_res = QPushButton("Clear")
        self._btn_clear_res.setObjectName("ghost_btn")
        self._btn_clear_res.setMinimumHeight(36)
        self._btn_clear_res.setToolTip("Reset all result boxes and the session log")
        self._btn_clear_res.clicked.connect(self._clear_results)
        exec_row.addWidget(self._btn_clear_res, 1)
        left_layout.addLayout(exec_row)

        lbl_presets = QLabel("Quick Presets")
        lbl_presets.setStyleSheet(f"color: {THEME['C_SUBTEXT']}; font-size: 11px; font-weight: 600;")
        left_layout.addWidget(lbl_presets)

        preset_grid = QGridLayout()
        preset_grid.setSpacing(6)
        presets = [
            ("30°",      "30",               True),
            ("45°",      "45",               True),
            ("60°",      "60",               True),
            ("90°",      "90",               True),
            ("π/6",      str(math.pi / 6),   False),
            ("π/4",      str(math.pi / 4),   False),
            ("π/3",      str(math.pi / 3),   False),
            ("π/2",      str(math.pi / 2),   False),
        ]
        for i, (name, val, is_deg) in enumerate(presets):
            btn = QPushButton(name)
            btn.setObjectName("preset_btn")
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
            btn.clicked.connect(lambda ch, v=val, d=is_deg: self._apply_preset(v, d))
            preset_grid.addWidget(btn, i // 4, i % 4)
        left_layout.addLayout(preset_grid)

        left_layout.addStretch(1)

        split.addWidget(left_panel)

        # Column 2: Verification Results
        mid_panel = QFrame()
        mid_panel.setObjectName("panel")
        mid_panel.setMinimumWidth(480)
        mid_layout = QVBoxLayout(mid_panel)
        mid_layout.setContentsMargins(14, 14, 14, 14)
        mid_layout.setSpacing(10)

        lbl_res = QLabel("Verification Results (CORDIC vs Expected)")
        lbl_res.setStyleSheet(f"color: {THEME['C_ACCENT']}; font-weight: 700; font-size: 13px;")
        lbl_res.setWordWrap(True)
        mid_layout.addWidget(lbl_res)

        res_grid = QGridLayout()
        res_grid.setSpacing(10)

        self._lbl_calc_sin = self._create_result_box("CORDIC SIN",    "—", THEME['C_CYAN'])
        self._lbl_calc_cos = self._create_result_box("CORDIC COS",    "—", THEME['C_CYAN'])
        self._lbl_calc_tan = self._create_result_box("CORDIC TAN",    "—", THEME['C_CYAN'])
        self._lbl_exp_sin  = self._create_result_box("Expected SIN",  "—", THEME['C_GREEN'])
        self._lbl_exp_cos  = self._create_result_box("Expected COS",  "—", THEME['C_GREEN'])
        self._lbl_exp_tan  = self._create_result_box("Expected TAN",  "—", THEME['C_GREEN'])
        self._lbl_err_sin  = self._create_result_box("Δ SIN (Error)", "—", THEME['C_ORANGE'])
        self._lbl_err_cos  = self._create_result_box("Δ COS (Error)", "—", THEME['C_ORANGE'])
        self._lbl_err_tan  = self._create_result_box("Δ TAN (Error)", "—", THEME['C_ORANGE'])

        res_grid.addWidget(self._lbl_calc_sin, 0, 0)
        res_grid.addWidget(self._lbl_calc_cos, 0, 1)
        res_grid.addWidget(self._lbl_calc_tan, 0, 2)
        res_grid.addWidget(self._lbl_exp_sin,  1, 0)
        res_grid.addWidget(self._lbl_exp_cos,  1, 1)
        res_grid.addWidget(self._lbl_exp_tan,  1, 2)
        res_grid.addWidget(self._lbl_err_sin,  2, 0)
        res_grid.addWidget(self._lbl_err_cos,  2, 1)
        res_grid.addWidget(self._lbl_err_tan,  2, 2)
        mid_layout.addLayout(res_grid)
        mid_layout.addStretch(1)

        self._btn_history = QPushButton("📜  History (Session Log)")
        self._btn_history.setMinimumHeight(38)
        self._btn_history.setStyleSheet(
            f"background: {THEME['C_SURFACE2']}; color: {THEME['C_WHITE']}; font-weight: 700; border: 1px solid {THEME['C_BORDER']}; border-radius: 6px;"
        )
        self._btn_history.setCursor(Qt.CursorShape.PointingHandCursor)
        self._btn_history.clicked.connect(self._show_history_dialog)
        mid_layout.addWidget(self._btn_history)

        split.addWidget(mid_panel)
        split.setStretchFactor(0, 1)
        split.setStretchFactor(1, 1)
        layout.addWidget(split, 1)

    def _create_result_box(self, title: str, val: str, color: str) -> QFrame:
        box = QFrame()
        box.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        box.setStyleSheet(
            f"background: {THEME['C_BG']}; border: 1px solid {THEME['C_BORDER']}; "
            f"border-radius: 6px; padding: 8px;"
        )
        lay = QVBoxLayout(box)
        lay.setContentsMargins(6, 6, 6, 6)
        t = QLabel(title)
        t.setStyleSheet(
            f"color: {THEME['C_SUBTEXT']}; font-size: 10px; font-weight: 600; text-transform: uppercase;"
        )
        v = QLabel(val)
        v.setObjectName("val")
        v.setWordWrap(True)
        v.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        v.setStyleSheet(f"color: {color}; font-size: 16px; font-weight: 800; font-family: 'Cascadia Mono', monospace;")
        lay.addWidget(t)
        lay.addWidget(v)
        return box

    def _set_box_value(self, box: QFrame, text: str):
        lbl = box.findChild(QLabel, "val")
        if lbl:
            lbl.setText(text)

    def _toggle_fullscreen(self):
        if not self.in_dialog:
            return
        win = self.window()
        if win.isMaximized():
            win.showNormal()
            self._btn_full.setText("⧦ Fullscreen")
        else:
            win.showMaximized()
            self._btn_full.setText("✕ Exit Fullscreen")

    def update_connection_status(self, is_connected: bool, port: str = "", fw_ver: str = ""):
        pass

    def _apply_preset(self, val_str: str, is_deg: bool):
        self._rb_deg.setChecked(is_deg)
        self._rb_rad.setChecked(not is_deg)
        try:
            self._txt_angle.setText(f"{float(val_str):.4f}")
        except ValueError:
            self._txt_angle.setText(val_str)

    def _on_calculate(self):
        if self._calculating:
            return

        raw = self._txt_angle.text().strip().lower()

        if not raw:
            msg = "Please enter an angle value before executing CORDIC calculation."
            self.notification_triggered.emit(f"⚠️ {msg}", "warning")
            if self.in_dialog:
                QMessageBox.warning(self, "Angle Not Entered", msg)
            self._txt_angle.setFocus()
            return

        if raw in ("e", "exit"):
            if self.in_dialog:
                self.window().close()
            return
        if raw in ("d", "deg", "degree", "degrees"):
            self._rb_deg.setChecked(True)
            self._txt_angle.clear()
            return
        if raw in ("r", "rad", "radian", "radians"):
            self._rb_rad.setChecked(True)
            self._txt_angle.clear()
            return

        try:
            if "pi" in raw:
                raw = raw.replace("pi", str(math.pi))
            val = float(eval(raw, {"__builtins__": {}}, {"pi": math.pi}))
        except Exception:
            msg = "Please enter a valid numeric angle or expression (e.g. 30, 45.5, pi/4)."
            self.notification_triggered.emit(f"⚠️ {msg}", "error")
            if self.in_dialog:
                QMessageBox.warning(self, "Invalid Angle", msg)
            return

        is_deg = self._rb_deg.isChecked()
        if is_deg:
            angle_deg = val % 360.0
            angle_rad = math.radians(angle_deg)
            disp_ang  = f"{val:.4f}°"
            mode_str  = "Degree"
        else:
            angle_rad = val % (2 * math.pi)
            angle_deg = math.degrees(angle_rad)
            disp_ang  = f"{val:.6f} rad"
            mode_str  = "Radian"

        exp_sin = math.sin(angle_rad)
        exp_cos = math.cos(angle_rad)
        exp_tan = math.tan(angle_rad)
        if abs(exp_sin) < 1e-9: exp_sin = 0.0
        if abs(exp_cos) < 1e-9: exp_cos = 0.0
        if abs(exp_tan) < 1e-9: exp_tan = 0.0

        if not self.fpga_manager or not getattr(self.fpga_manager, "is_ready", False):
            msg = "Board not connected! CORDIC calculator requires an active hardware FPGA connection."
            self.notification_triggered.emit(f"⚠️ {msg}", "error")
            if self.in_dialog:
                QMessageBox.critical(self, "Board Not Connected", msg)
            return

        self._pending_angle_rad = angle_rad
        self._pending_exp_sin   = exp_sin
        self._pending_exp_cos   = exp_cos
        self._pending_exp_tan   = exp_tan
        self._pending_disp_ang  = disp_ang
        self._pending_mode_str  = mode_str

        self._calculating = True
        self._btn_calc.setText("Computing…")
        self._btn_calc.setEnabled(False)
        self._btn_clear_res.setEnabled(False)

        self.notification_triggered.emit(f"⚡ Executing hardware CORDIC calculation for {disp_ang}...", "busy")
        self.fpga_manager.compute_angle_async(angle_rad, timeout=4.0)

    def _on_ang_result(self, sin_f: float, cos_f: float, is_hw: bool, err_msg: str):
        self._calculating = False
        self._btn_calc.setText("Execute CORDIC")
        self._btn_calc.setEnabled(True)
        self._btn_clear_res.setEnabled(True)

        if not is_hw:
            msg = f"CORDIC Hardware Error: Could not retrieve values from FPGA ({err_msg or 'Timeout/busy'})."
            self.notification_triggered.emit(f"❌ {msg}", "error")
            if self.in_dialog:
                QMessageBox.critical(self, "FPGA Hardware Error", msg)
            return

        exp_sin    = self._pending_exp_sin
        exp_cos    = self._pending_exp_cos
        exp_tan    = getattr(self, "_pending_exp_tan", 0.0)
        disp_ang   = self._pending_disp_ang
        mode_str   = self._pending_mode_str

        tan_f = sin_f / cos_f if abs(cos_f) > 1e-9 else 0.0

        err_sin = abs(sin_f - exp_sin)
        err_cos = abs(cos_f - exp_cos)
        err_tan = abs(tan_f - exp_tan)

        self._set_box_value(self._lbl_calc_sin, f"{sin_f:.8f}")
        self._set_box_value(self._lbl_calc_cos, f"{cos_f:.8f}")
        self._set_box_value(self._lbl_calc_tan, f"{tan_f:.8f}")
        self._set_box_value(self._lbl_exp_sin,  f"{exp_sin:.8f}")
        self._set_box_value(self._lbl_exp_cos,  f"{exp_cos:.8f}")
        self._set_box_value(self._lbl_exp_tan,  f"{exp_tan:.8f}")
        self._set_box_value(self._lbl_err_sin,  f"{err_sin:.2e}")
        self._set_box_value(self._lbl_err_cos,  f"{err_cos:.2e}")
        self._set_box_value(self._lbl_err_tan,  f"{err_tan:.2e}")

        row_data = [
            mode_str, disp_ang,
            f"{sin_f:.8f}", f"{exp_sin:.8f}",
            f"{cos_f:.8f}", f"{exp_cos:.8f}",
            f"{tan_f:.8f}", f"{exp_tan:.8f}",
        ]
        self._history.append(row_data)

        self.notification_triggered.emit(
            f"✅ CORDIC calculation complete for {disp_ang}: SIN={sin_f:.4f}, COS={cos_f:.4f}, TAN={tan_f:.4f}.",
            "success"
        )

    def _clear_results(self):
        for box in (self._lbl_calc_sin, self._lbl_calc_cos, self._lbl_calc_tan,
                    self._lbl_exp_sin,  self._lbl_exp_cos,  self._lbl_exp_tan,
                    self._lbl_err_sin,  self._lbl_err_cos,  self._lbl_err_tan):
            self._set_box_value(box, "—")
        self._clear_log()
        self.notification_triggered.emit("ℹ️ CORDIC calculator results and session log cleared.", "info")

    def _clear_log(self):
        self._history.clear()

    def _show_history_dialog(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("CORDIC Calculation Session History")
        dlg.resize(850, 450)
        dlg.setStyleSheet(self.styleSheet())
        lay = QVBoxLayout(dlg)
        lay.setContentsMargins(14, 14, 14, 14)
        lay.setSpacing(10)
        
        top = QHBoxLayout()
        lbl = QLabel("Calculation Session Log")
        lbl.setStyleSheet(f"color: {THEME['C_WHITE']}; font-weight: 700; font-size: 14px;")
        top.addWidget(lbl)
        top.addStretch(1)
        
        btn_clear = QPushButton("Clear Log")
        btn_export = QPushButton("Export CSV")
        top.addWidget(btn_clear)
        top.addWidget(btn_export)
        lay.addLayout(top)
        
        table = QTableWidget(len(self._history), 8)
        table.setHorizontalHeaderLabels(
            ["Mode", "Angle", "CORDIC SIN", "Expected SIN", "CORDIC COS", "Expected COS", "CORDIC TAN", "Expected TAN"]
        )
        table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.ResizeToContents)
        table.horizontalHeader().setSectionResizeMode(7, QHeaderView.ResizeMode.Stretch)
        table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        table.setAlternatingRowColors(True)
        table.verticalHeader().setVisible(False)
        
        def populate_table():
            table.setRowCount(len(self._history))
            for r, row_data in enumerate(self._history):
                for c, text in enumerate(row_data[:8]):
                    it = QTableWidgetItem(text)
                    it.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
                    it.setForeground(QColor(THEME['C_TEXT']))
                    table.setItem(r, c, it)
            table.scrollToBottom()
            
        populate_table()
        
        def clear_history():
            self._clear_log()
            populate_table()
            
        btn_clear.clicked.connect(clear_history)
        btn_export.clicked.connect(self._export_log)
        
        lay.addWidget(table)
        dlg.exec()

    def _export_log(self):
        if not self._history:
            self.notification_triggered.emit("ℹ️ Nothing to export: session log is empty.", "info")
            if self.in_dialog:
                QMessageBox.information(self, "Nothing to Export", "The session log is empty.")
            return
        path, _ = QFileDialog.getSaveFileName(
            self, "Export CORDIC Log", "cordic_calculator_log.csv", "CSV Files (*.csv)"
        )
        if path:
            with open(path, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(["Mode", "Angle", "CORDIC SIN", "Expected SIN",
                             "CORDIC COS", "Expected COS", "CORDIC TAN", "Expected TAN"])
                w.writerows([r[:8] for r in self._history])
            self.notification_triggered.emit(f"✅ Saved {len(self._history)} CORDIC log entries to {path}.", "success")
            if self.in_dialog:
                QMessageBox.information(self, "Export Complete", f"Saved {len(self._history)} entries to {path}")

    def _apply_styles(self):
        c = THEME
        self.setStyleSheet(f"""
            QFrame#panel {{
                background-color: {c['C_SURFACE']};
                border: 1px solid {c['C_BORDER']};
                border-radius: 8px;
            }}
            QRadioButton {{
                color: {c['C_WHITE']};
                font-size: 13px;
                font-weight: 600;
            }}
            QRadioButton::indicator {{
                width: 14px; height: 14px;
                border-radius: 7px;
                border: 2px solid {c['C_BORDER']};
                background: {c['C_BG']};
            }}
            QRadioButton::indicator:checked {{
                border-color: {c['C_ACCENT']};
                background: {c['C_ACCENT']};
            }}
            QPushButton#preset_btn {{
                background: {c['C_BG']};
                color: {c['C_WHITE']};
                border: 1px solid {c['C_BORDER']};
                border-radius: 4px;
                padding: 4px;
                font-size: 11px;
                font-weight: 600;
            }}
            QPushButton#preset_btn:hover {{
                background: {c['C_CYAN']};
                border-color: {c['C_ACCENT']};
                color: {c['C_BG']};
            }}
            QPushButton#primary {{
                background: {c['C_ACCENT']};
                color: {c['C_WHITE']};
                border: none;
                border-radius: 6px;
                font-weight: 700;
                font-size: 13px;
            }}
            QPushButton#primary:hover {{
                background: {c['C_CYAN']};
                color: {c['C_BG']};
            }}
            QPushButton#ghost_btn {{
                background: transparent;
                color: {c['C_SUBTEXT']};
                border: 1px solid {c['C_BORDER']};
                border-radius: 4px;
                padding: 4px 10px;
                font-size: 12px;
                font-weight: 600;
            }}
            QPushButton#ghost_btn:hover {{
                color: {c['C_WHITE']};
                border-color: {c['C_ACCENT']};
            }}
            QTableWidget {{
                background: {c['C_BG']};
                color: {c['C_TEXT']};
                gridline-color: {c['C_BORDER']};
                border: 1px solid {c['C_BORDER']};
                border-radius: 4px;
                font-size: 11px;
            }}
            QTableWidget::item {{
                color: {c['C_TEXT']};
                padding: 4px;
            }}
            QTableWidget::item:alternate {{
                background: {c['C_SURFACE']};
            }}
            QHeaderView::section {{
                background: {c['C_SURFACE']};
                color: {c['C_WHITE']};
                font-weight: 700;
                border: none;
                border-bottom: 1px solid {c['C_BORDER']};
                padding: 6px;
            }}
            QLabel {{
                color: {c['C_TEXT']};
            }}
        """)


class CordicCalculatorDialog(QDialog):
    """
    Wrapper dialog for backward compatibility or popup usage.
    Wraps CordicCalculatorWidget inside a standard QDialog.
    """
    def __init__(self, parent=None, fpga_manager=None):
        super().__init__(parent)
        self.setWindowTitle("Circular CORDIC Calculator")
        self.setWindowFlags(self.windowFlags() & ~Qt.WindowType.WindowMaximizeButtonHint)
        self.resize(650, 580)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.widget = CordicCalculatorWidget(self, fpga_manager=fpga_manager, in_dialog=True)
        layout.addWidget(self.widget)
