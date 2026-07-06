
import os
import csv
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QPushButton, QLabel, QFileDialog
)
from PyQt6.QtCore import Qt

from waveform import WaveformCanvas
from constellation import ConstellationCanvas
from styles import THEME, build_stylesheet
import modulation as mod

class DetailPlotWindow(QMainWindow):
    def __init__(self, plot_type, mode, symbols, iq_history, parent=None):
        super().__init__(parent)
        self.plot_type = plot_type
        self.mode = mode
        self.symbols = symbols
        self.iq_history = iq_history
        
        self.setWindowTitle(f"Waveform Analysis Studio - {plot_type}")
        self.resize(1200, 800)
        self.setStyleSheet(build_stylesheet())
        
        self._build_ui()
        self._populate_data()

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(16, 16, 16, 16)
        root.setSpacing(12)
        
        # Professional Top Toolbar
        tb_layout = QHBoxLayout()
        
        title = QLabel(f"{self.plot_type} Analysis Studio")
        title.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 16px; font-weight: 700;")
        
        btn_export_png = QPushButton("Export PNG")
        btn_export_png.clicked.connect(self._export_png)
        
        btn_export_csv = QPushButton("Export CSV")
        btn_export_csv.clicked.connect(self._export_csv)
        
        btn_close = QPushButton("Return to Dashboard")
        btn_close.setObjectName("primary")
        btn_close.clicked.connect(self.close)
        
        tb_layout.addWidget(title)
        tb_layout.addStretch(1)
        
        # The Plot Canvas
        if self.plot_type == "Waveform":
            self.canvas = WaveformCanvas(self, show_toolbar=True)
            btn_pan_left = QPushButton("◀")
            btn_pan_left.setToolTip("Pan Left (Left Arrow Key)")
            btn_pan_left.setFixedWidth(36)
            btn_pan_left.clicked.connect(lambda: self.canvas.pan_waveforms("left"))
            
            btn_pan_right = QPushButton("▶")
            btn_pan_right.setToolTip("Pan Right (Right Arrow Key)")
            btn_pan_right.setFixedWidth(36)
            btn_pan_right.clicked.connect(lambda: self.canvas.pan_waveforms("right"))
            
            tb_layout.addWidget(btn_pan_left)
            tb_layout.addWidget(btn_pan_right)
        else:
            self.canvas = ConstellationCanvas(self, show_toolbar=True)
            
        tb_layout.addWidget(btn_export_png)
        tb_layout.addWidget(btn_export_csv)
        tb_layout.addWidget(btn_close)
        
        root.addLayout(tb_layout)
        root.addWidget(self.canvas, 1)

    def _populate_data(self):
        if self.plot_type == "Waveform":
            self.canvas.plot(self.symbols, self.mode, self.iq_history, table_symbols=self.symbols)
        else:
            self.canvas.plot(self.mode, self.iq_history, self.symbols)

    def _export_png(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export PNG", "", "PNG Image (*.png)")
        if path:
            self.canvas.fig.savefig(path, dpi=300, bbox_inches='tight', facecolor=self.canvas.fig.get_facecolor())

    def _export_csv(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export CSV", "", "CSV Files (*.csv)")
        if not path or not self.symbols: return
        with open(path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["idx", "bits", "phase", "I", "Q"])
            for i, (sym, (I, Q)) in enumerate(zip(self.symbols, self.iq_history)):
                w.writerow([i, mod.symbol_to_bit_string(sym, self.mode), mod.expected_phase_deg(sym, self.mode), I, Q])
