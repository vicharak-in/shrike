"""
constellation.py
═══════════════════════════════════════════════════════════════
MATLAB-style Constellation (I/Q Vector) canvas.
"""
import numpy as np
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg, NavigationToolbar2QT
from matplotlib.figure import Figure
import matplotlib.patheffects as pe
from PyQt6.QtWidgets import QVBoxLayout, QWidget
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor

from styles import THEME, apply_mpl_style
import modulation as mod

class ConstellationCanvas(QWidget):
    def __init__(self, parent=None, show_toolbar=False):
        super().__init__(parent)
        apply_mpl_style()
        self.fig = Figure(figsize=(6, 6), dpi=100)
        self.fig.subplots_adjust(left=0.15, right=0.9, top=0.9, bottom=0.15)
        self.canvas = FigureCanvasQTAgg(self.fig)
        
        self.toolbar = NavigationToolbar2QT(self.canvas, self)
        self.toolbar.setStyleSheet(f"background-color: {THEME['C_SURFACE2']}; color: {THEME['C_TEXT']}; border: none; border-radius: 4px;")
        if not show_toolbar:
            self.toolbar.hide()

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)
        if show_toolbar:
            layout.addWidget(self.toolbar)
        layout.addWidget(self.canvas)

        self.ax = self.fig.add_subplot(111)
        self._style_ax()
        
        # Hover Annotation
        self._annot = self.ax.annotate("", xy=(0,0), xytext=(15,15), textcoords="offset points",
            bbox=dict(boxstyle="round,pad=0.5", fc=THEME["C_SURFACE3"], ec=THEME["C_BORDER2"], lw=1, alpha=0.9),
            arrowprops=dict(arrowstyle="->", connectionstyle="arc3,rad=0", color=THEME["C_ACCENT"]),
            color=THEME["C_WHITE"], fontsize=9, fontweight="600"
        )
        self._annot.set_visible(False)
        self.canvas.mpl_connect("motion_notify_event", self._on_hover)
        self.canvas.mpl_connect("scroll_event", self._on_scroll)
        self.canvas.mpl_connect("button_press_event", self._on_press)
        self.canvas.mpl_connect("button_release_event", self._on_release)
        
        self._panning = False
        self._pan_start = None

        self.reset()
        
        # Plot collections
        self.scatter_history = None
        self.scatter_current = None
        self.ideal_points = None
        self._current_iq = []
        self._current_symbols = []
        self._mode = "BPSK"

    def _style_ax(self):
        self.ax.set_aspect('equal')
        self.ax.set_xlim(-1.5, 1.5)
        self.ax.set_ylim(-1.5, 1.5)
        self.ax.set_xlabel("In-Phase (I)", color=THEME["C_SUBTEXT"], fontweight="600")
        self.ax.set_ylabel("Quadrature (Q)", color=THEME["C_SUBTEXT"], fontweight="600")
        self.ax.grid(True, linestyle="--", alpha=0.4, color=THEME["C_BORDER"])
        
        self.ax.axhline(0, color=THEME["C_DIM"], linewidth=1, alpha=0.6)
        self.ax.axvline(0, color=THEME["C_DIM"], linewidth=1, alpha=0.6)

    def _on_scroll(self, event):
        if event.inaxes == self.ax:
            cur_xlim = self.ax.get_xlim()
            cur_ylim = self.ax.get_ylim()
            scale_factor = 0.8 if event.button == 'up' else 1.2
            
            xdata, ydata = event.xdata, event.ydata
            if xdata is None or ydata is None: return
            
            new_width = (cur_xlim[1] - cur_xlim[0]) * scale_factor
            new_height = (cur_ylim[1] - cur_ylim[0]) * scale_factor
            
            relx = (cur_xlim[1] - xdata) / (cur_xlim[1] - cur_xlim[0])
            rely = (cur_ylim[1] - ydata) / (cur_ylim[1] - cur_ylim[0])
            
            self.ax.set_xlim([xdata - new_width * (1-relx), xdata + new_width * relx])
            self.ax.set_ylim([ydata - new_height * (1-rely), ydata + new_height * rely])
            self.canvas.draw_idle()

    def _on_press(self, event):
        if event.button == 1 and event.inaxes == self.ax:
            self._panning = True
            self._pan_start = (event.xdata, event.ydata)

    def _on_release(self, event):
        if event.button == 1:
            self._panning = False

    def _on_hover(self, event):
        if self._panning and self._pan_start and event.inaxes == self.ax:
            dx = event.xdata - self._pan_start[0]
            dy = event.ydata - self._pan_start[1]
            cur_xlim = self.ax.get_xlim()
            cur_ylim = self.ax.get_ylim()
            self.ax.set_xlim(cur_xlim[0] - dx, cur_xlim[1] - dx)
            self.ax.set_ylim(cur_ylim[0] - dy, cur_ylim[1] - dy)
            self.canvas.draw_idle()
            return
            
        if event.inaxes == self.ax and self.scatter_current:
            cont, ind = self.scatter_current.contains(event)
            if cont:
                idx = ind["ind"][0]
                if idx < len(self._current_iq):
                    I, Q = self._current_iq[idx]
                    amp = np.sqrt(I**2 + Q**2)
                    phase = np.degrees(np.arctan2(Q, I))
                    sym_str = mod.symbol_to_bit_string(self._current_symbols[-1], self._mode) if self._current_symbols else "?"
                    
                    self._annot.xy = (I, Q)
                    self._annot.set_text(f"Sym: {sym_str}\\nI: {I:.3f}\\nQ: {Q:.3f}\\nPh: {phase:.1f}°")
                    self._annot.set_visible(True)
                    self.canvas.draw_idle()
                    return
            
            if self.scatter_history:
                cont_hist, ind_hist = self.scatter_history.contains(event)
                if cont_hist:
                    idx = ind_hist["ind"][0]
                    hist_idx = len(self._current_symbols) - len(self.scatter_history.get_offsets()) + idx - 1
                    I, Q = self.scatter_history.get_offsets()[idx]
                    phase = np.degrees(np.arctan2(Q, I))
                    sym_str = mod.symbol_to_bit_string(self._current_symbols[hist_idx], self._mode) if hist_idx >= 0 and hist_idx < len(self._current_symbols) else "?"
                    
                    self._annot.xy = (I, Q)
                    self._annot.set_text(f"Sym: {sym_str}\\nI: {I:.3f}\\nQ: {Q:.3f}\\nPh: {phase:.1f}°")
                    self._annot.set_visible(True)
                    self.canvas.draw_idle()
                    return

        if self._annot.get_visible():
            self._annot.set_visible(False)
            self.canvas.draw_idle()

    def plot(self, mode, iq_history, symbols):
        self.ax.clear()
        self._style_ax()
        self._current_iq = [iq_history[-1]] if iq_history else []
        self._current_symbols = symbols
        self._mode = mode
        
        x = np.linspace(-1.5, 1.5, 100)
        y = np.linspace(-1.5, 1.5, 100)
        X, Y = np.meshgrid(x, y)
        if mode == "BPSK":
            Z = np.where(X > 0, 1, -1)
            self.ax.contourf(X, Y, Z, levels=[-2, 0, 2], colors=[THEME["C_PURPLE"], THEME["C_CYAN"]], alpha=0.03)
            
            ideals_i = [1.0, -1.0]; ideals_q = [0.0, 0.0]
            labels = ["0", "1"]
        else:
            Z = np.zeros_like(X)
            Z[(X > 0) & (Y > 0)] = 1
            Z[(X < 0) & (Y > 0)] = 2
            Z[(X < 0) & (Y < 0)] = 3
            Z[(X > 0) & (Y < 0)] = 4
            self.ax.contourf(X, Y, Z, levels=[0.5, 1.5, 2.5, 3.5, 4.5], colors=[THEME["C_CYAN"], THEME["C_PURPLE"], THEME["C_ORANGE"], THEME["C_GREEN"]], alpha=0.03)
            
            v = 0.7071
            ideals_i = [v, -v, -v, v]; ideals_q = [v, v, -v, -v]
            labels = ["00", "01", "10", "11"]
            
        # Draw ideal circles and labels
        theta = np.linspace(0, 2*np.pi, 100)
        for ix, iy, lab in zip(ideals_i, ideals_q, labels):
            self.ax.plot(ix + 0.15*np.cos(theta), iy + 0.15*np.sin(theta), color=THEME["C_SUBTEXT"], alpha=0.4, linestyle="--")
            self.ax.text(ix, iy + 0.22, lab, color=THEME["C_TEXT"], ha="center", va="center", fontsize=9, fontweight="bold")
            
        self.ideal_points = self.ax.scatter(ideals_i, ideals_q, c=THEME["C_DIM"], marker="+", s=200, linewidths=1.5, label="Ideal", zorder=2)

        if len(iq_history) > 1:
            N = min(20, len(iq_history) - 1)
            trail = np.array(iq_history[-(N+1):-1])
            alphas = np.linspace(0.1, 0.6, N)
            colors = np.zeros((N, 4))
            base_col = QColor(THEME["C_SUBTEXT"])
            colors[:, 0] = base_col.redF()
            colors[:, 1] = base_col.greenF()
            colors[:, 2] = base_col.blueF()
            colors[:, 3] = alphas
            self.scatter_history = self.ax.scatter(trail[:, 0], trail[:, 1], c=colors, s=30, edgecolors='none', zorder=3)

            # Draw trajectory arrows between recent constellation transitions
            recent_points = iq_history[-(min(10, len(iq_history))):]
            for idx in range(len(recent_points) - 1):
                p1 = recent_points[idx]
                p2 = recent_points[idx + 1]
                alpha_val = 0.25 + 0.6 * (idx / max(1, len(recent_points) - 1))
                self.ax.annotate("", xy=p2, xytext=p1,
                    arrowprops=dict(arrowstyle="->", color=THEME["C_CYAN"], lw=1.5, alpha=alpha_val,
                                    shrinkA=4, shrinkB=6, connectionstyle="arc3,rad=0.15"),
                    zorder=4)

        if iq_history:
            i_val, q_val = iq_history[-1]
            self.scatter_current = self.ax.scatter(
                [i_val], [q_val], c=THEME["C_ACCENT"], s=150,
                edgecolors=THEME["C_WHITE"], linewidths=2.0, zorder=5
            )
            curr_deg = np.degrees(np.arctan2(q_val, i_val)) % 360
            if len(iq_history) > 1:
                prev_i, prev_q = iq_history[-2]
                prev_deg = np.degrees(np.arctan2(prev_q, prev_i)) % 360
                delta_deg = (curr_deg - prev_deg + 180) % 360 - 180
                callout_text = f"Current: {int(round(curr_deg))}°\n(Δ {int(round(delta_deg)):+d}°)"
            else:
                callout_text = f"Current: {int(round(curr_deg))}°"
            
            ha_align = "right" if i_val > 0 else "left"
            va_align = "top" if q_val > 0 else "bottom"
            offset_x = -0.12 if i_val > 0 else 0.12
            offset_y = -0.12 if q_val > 0 else 0.12
            self.ax.text(i_val + offset_x, q_val + offset_y, callout_text,
                         color=THEME["C_WHITE"], fontsize=9, fontweight="bold",
                         ha=ha_align, va=va_align,
                         bbox=dict(boxstyle="round,pad=0.35", fc=THEME["C_SURFACE3"], ec=THEME["C_ACCENT"], lw=1.5, alpha=0.95),
                         zorder=10)
            
        self.canvas.draw()

    def reset_zoom(self):
        if hasattr(self, 'toolbar') and self.toolbar:
            self.toolbar.home()
        self.ax.set_xlim(-1.6, 1.6)
        self.ax.set_ylim(-1.6, 1.6)
        self.canvas.draw_idle()

    def reset(self):
        self.ax.clear()
        self._style_ax()
        self.canvas.draw()