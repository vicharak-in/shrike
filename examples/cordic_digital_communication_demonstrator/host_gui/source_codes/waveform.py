
import numpy as np
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg, NavigationToolbar2QT
from matplotlib.figure import Figure
import matplotlib.patheffects as pe
from matplotlib.lines import Line2D
from PyQt6.QtWidgets import QVBoxLayout, QWidget, QHBoxLayout, QPushButton, QLabel
from PyQt6.QtCore import Qt, QTimer

from styles import THEME, apply_mpl_style
import modulation as mod

class WaveformCanvas(QWidget):
    def __init__(self, parent=None, show_toolbar=False):
        super().__init__(parent)
        apply_mpl_style()
        self.fig = Figure(figsize=(8, 6), dpi=100)
        self.fig.subplots_adjust(left=0.20, right=0.95, top=0.95, bottom=0.08, hspace=0.3)
        self.canvas = FigureCanvasQTAgg(self.fig)
        
        self.toolbar = NavigationToolbar2QT(self.canvas, self)
        self.toolbar.setStyleSheet(f"background-color: {THEME['C_SURFACE2']}; color: {THEME['C_TEXT']}; border: none; border-radius: 4px;")
        if not show_toolbar:
            self.toolbar.hide()
        
        # Top selection overlay bar (always available even when toolbar is hidden)
        self.top_bar = QWidget()
        tb_layout = QHBoxLayout(self.top_bar)
        tb_layout.setContentsMargins(12, 6, 12, 2)
        
        self.lbl_selected_title = QLabel("")
        self.lbl_selected_title.setStyleSheet(f"color: {THEME['C_WHITE']}; font-size: 13px; font-weight: 700;")
        
        self.btn_clear_sel = QPushButton("⬅ Return to All Waveforms (Esc)")
        self.btn_clear_sel.setObjectName("primary")
        self.btn_clear_sel.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_clear_sel.clicked.connect(self._clear_selection)
        
        tb_layout.addWidget(self.lbl_selected_title)
        tb_layout.addStretch()
        tb_layout.addWidget(self.btn_clear_sel)
        self.top_bar.hide()

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)
        if show_toolbar:
            layout.addWidget(self.toolbar)
        layout.addWidget(self.top_bar)
        layout.addWidget(self.canvas)

        self._ax_bits = self.fig.add_subplot(3, 1, 1)
        self._ax_carrier = self.fig.add_subplot(3, 1, 2, sharex=self._ax_bits)
        self._ax_mod = self.fig.add_subplot(3, 1, 3, sharex=self._ax_bits)
        
        self.axes = [self._ax_bits, self._ax_carrier, self._ax_mod]
        self.fig.subplots_adjust(bottom=0.28, top=0.94, hspace=0.45, left=0.12, right=0.96)
        self._orig_positions = [ax.get_position() for ax in self.axes]
        self._active_ax = None
        self._mode = "BPSK"

        self._style_axes()
        self.reset()
        
        # Interactions
        self.canvas.mpl_connect("button_press_event", self._on_click)
        self.canvas.mpl_connect("motion_notify_event", self._on_hover)
        self.canvas.mpl_connect("key_press_event", self._on_key)
        self.canvas.mpl_connect("scroll_event", self._on_scroll)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        
        # Annotations for hover
        # Annotations for hover
        self._annots = {}
        for ax in self.axes:
            annot = ax.annotate("", xy=(0,0), xytext=(20,-30), textcoords="offset points",
                bbox=dict(boxstyle="round,pad=0.6", fc=THEME["C_SURFACE2"], ec=THEME["C_ACCENT"], lw=1.5, alpha=0.96),
                arrowprops=dict(arrowstyle="->", connectionstyle="arc3,rad=0", color=THEME["C_ACCENT"], lw=1.5),
                color=THEME["C_WHITE"], fontsize=9, fontweight="bold", zorder=30
            )
            annot.set_visible(False)
            self._annots[ax] = annot
        
        # Data cache
        self.t_sym = np.array([])
        self.mod_wave = np.array([])
        self.bit_wave = np.array([])
        self.car_wave = np.array([])

        # Animated status overlay ("Plotting the waveforms...")
        self.lbl_status_overlay = QLabel("", self)
        self.lbl_status_overlay.setStyleSheet(
            f"background-color: {THEME['C_SURFACE3']}; color: {THEME['C_ACCENT']}; "
            f"border: 2px solid {THEME['C_ACCENT']}; border-radius: 8px;"
        )
        self.lbl_status_overlay.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_status_overlay.hide()

    def show_plotting_status(self, text="⚡ Plotting the waveforms..."):
        # Status notifications moved to bottom status bar per user request
        pass

    def hide_plotting_status(self):
        if hasattr(self, 'lbl_status_overlay') and self.lbl_status_overlay:
            self.lbl_status_overlay.hide()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if self.lbl_status_overlay.isVisible():
            x = max(0, (self.width() - self.lbl_status_overlay.width()) // 2)
            y = max(0, (self.height() - self.lbl_status_overlay.height()) // 2)
            self.lbl_status_overlay.move(x, y)

    def _style_axes(self):
        titles = ["Baseband (Bits)", "Carrier Signal", "Modulated RF Signal"]
        colors = [THEME["C_ORANGE"], THEME["C_ACCENT"], THEME["C_GREEN"]]
        
        for i, ax in enumerate(self.axes):
            ax.set_ylabel(titles[i], color=colors[i], fontsize=10, fontweight="bold", labelpad=10)
            ax.grid(True, linestyle="--", alpha=0.5, color=THEME["C_BORDER"])
            for spine in ax.spines.values():
                spine.set_color(THEME["C_BORDER"])

    def _focus_layout(self, target_ax):
        if not hasattr(self, '_orig_positions') or len(self._orig_positions) != 3:
            return
        p_top = self._orig_positions[0]
        p_bot = self._orig_positions[2]
        full_pos = [p_top.x0, p_bot.y0, p_top.width, p_top.y1 - p_bot.y0]
        for ax in self.axes:
            if ax == target_ax:
                ax.set_visible(True)
                ax.set_position(full_pos)
            else:
                ax.set_visible(False)

    def _restore_layout(self):
        for i, ax in enumerate(self.axes):
            ax.set_visible(True)
            if hasattr(self, '_orig_positions') and i < len(self._orig_positions):
                ax.set_position(self._orig_positions[i])

    def _clear_selection(self):
        self._active_ax = None
        self.top_bar.hide()
        self._restore_layout()
        for ax in self.axes:
            ax.set_alpha(1.0)
            for line in ax.get_lines(): line.set_alpha(1.0); line.set_linewidth(1.8)
            for coll in ax.collections: coll.set_alpha(0.15)
        self.canvas.draw_idle()

    def _on_click(self, event):
        if event.inaxes in self.axes:
            if event.dblclick and self._active_ax is not None:
                self._clear_selection()
                return
            if self._active_ax == event.inaxes:
                return
                
            self._active_ax = event.inaxes
            if self._active_ax == self._ax_bits:
                title_text = "Focused View: Baseband (Bits)"
            elif self._active_ax == self._ax_carrier:
                title_text = "Focused View: Carrier Signal"
            else:
                title_text = "Focused View: Modulated RF Signal"
            self.lbl_selected_title.setText(title_text)
            self.top_bar.show()
            
            self._focus_layout(self._active_ax)
            for ax in self.axes:
                if ax == self._active_ax:
                    ax.set_alpha(1.0)
                    for line in ax.get_lines(): line.set_alpha(1.0); line.set_linewidth(2.5)
                    for coll in ax.collections: coll.set_alpha(0.3)
            self.canvas.draw_idle()
            
    def _on_key(self, event):
        if event.key == "escape":
            self._clear_selection()
        elif event.key in ["left", "right"]:
            self.pan_waveforms(direction=event.key)

    def _on_scroll(self, event):
        if event.inaxes:
            if self._active_ax and event.inaxes != self._active_ax:
                return
            ax = event.inaxes
            cur_xlim = ax.get_xlim()
            xdata = event.xdata
            scale_factor = 0.8 if event.button == 'up' else 1.2
            new_width = (cur_xlim[1] - cur_xlim[0]) * scale_factor
            
            relx = (cur_xlim[1] - xdata) / (cur_xlim[1] - cur_xlim[0])
            ax.set_xlim([xdata - new_width * (1-relx), xdata + new_width * relx])
            self.canvas.draw_idle()

    def _on_hover(self, event):
        # Hide all first
        for annot in self._annots.values():
            annot.set_visible(False)

        if event.inaxes and (not self._active_ax or event.inaxes == self._active_ax):
            x, y = event.xdata, event.ydata
            if len(self.t_sym) > 0 and hasattr(self, '_symbols_cache') and self._symbols_cache:
                idx = int(np.clip(np.searchsorted(self.t_sym, x), 0, len(self.t_sym)-1))
                real_x = self.t_sym[idx]
                
                if event.inaxes == self._ax_bits: real_y = self.bit_wave[idx]
                elif event.inaxes == self._ax_carrier: real_y = self.car_wave[idx]
                else: real_y = self.mod_wave[idx]
                
                sym_idx = min(idx // 100, len(self._symbols_cache) - 1)
                sym = self._symbols_cache[sym_idx]
                mode = getattr(self, '_mode_cache', "BPSK")
                
                if mode == "QPSK":
                    byte_idx = sym_idx // 4
                    if len(self._symbols_cache) >= 4 * byte_idx + 4:
                        s0, s1, s2, s3 = self._symbols_cache[4*byte_idx : 4*byte_idx + 4]
                        byte_val = (s0 << 6) | (s1 << 4) | (s2 << 2) | s3
                        bin_str = f"{byte_val:08b}"
                        ascii_str = chr(byte_val) if 32 <= byte_val <= 126 else f"0x{byte_val:02X}"
                    else:
                        bin_str = "N/A"
                        ascii_str = "N/A"
                else: # BPSK
                    byte_idx = sym_idx // 8
                    if len(self._symbols_cache) >= 8 * byte_idx + 8:
                        byte_val = sum((self._symbols_cache[8*byte_idx + k] & 1) << (7 - k) for k in range(8))
                        bin_str = f"{byte_val:08b}"
                        ascii_str = chr(byte_val) if 32 <= byte_val <= 126 else f"0x{byte_val:02X}"
                    else:
                        bin_str = "N/A"
                        ascii_str = "N/A"
                        
                grp_bits = mod.symbol_to_bit_string(sym, mode)
                phase_deg = mod.expected_phase_deg(sym, mode)
                angle_rad = np.radians(phase_deg)
                q14_val = int(round(angle_rad * 16384.0))
                
                if phase_deg <= 90: quad_str, red_deg = "I", phase_deg
                elif phase_deg <= 180: quad_str, red_deg = "II", 180.0 - phase_deg
                elif phase_deg <= 270: quad_str, red_deg = "III", phase_deg - 180.0
                else: quad_str, red_deg = "IV", 360.0 - phase_deg
                
                if getattr(self, '_iq_history_cache', None) and len(self._iq_history_cache) > sym_idx:
                    i_val, q_val = self._iq_history_cache[sym_idx]
                    sin_val, cos_val = q_val, i_val
                else:
                    sin_val, cos_val = np.sin(angle_rad), np.cos(angle_rad)
                    
                tan_val = sin_val / cos_val if abs(cos_val) > 1e-6 else float('inf')
                tan_str = f"{tan_val:+.4f}" if abs(cos_val) > 1e-6 else "∞"
                
                tooltip_text = (
                    f"ASCII : {ascii_str}\n"
                    f"Binary : {bin_str}\n"
                    f"Grouped Bits : {grp_bits}\n"
                    f"Phase : {int(round(phase_deg))}°\n"
                    f"Radians : {angle_rad:.6f}\n"
                    f"Q2.14 : {q14_val}\n"
                    f"Quadrant : {quad_str}\n"
                    f"Reduced Angle : {int(round(red_deg))}°\n"
                    f"── CORDIC ──\n"
                    f"SIN : {sin_val:+.4f}\n"
                    f"  ↓\n"
                    f"COS : {cos_val:+.4f}\n"
                    f"  ↓\n"
                    f"TAN : {tan_str}"
                )
                
                annot = self._annots[event.inaxes]
                cur_xlim = event.inaxes.get_xlim()
                if x > cur_xlim[0] + 0.6 * (cur_xlim[1] - cur_xlim[0]):
                    annot.xytext = (-150, -30)
                else:
                    annot.xytext = (20, -30)
                annot.xy = (real_x, real_y)
                annot.set_text(tooltip_text)
                annot.set_visible(True)
                
        self.canvas.draw_idle()

    def plot(self, symbols, mode="BPSK", iq_history=None, table_symbols=None, animate=False):
        if not symbols: return
        if table_symbols is not None and list(symbols) != list(table_symbols):
            raise ValueError("Debug Assertion Error: Waveform symbol sequence and data table symbol sequence differ! Refusing to plot incorrect data.")
        self._mode = mode
        self._mode_cache = mode
        self._symbols_cache = list(symbols)
        self._iq_history_cache = iq_history if (iq_history is not None and len(iq_history) == len(symbols)) else None
        n = len(symbols)
        t_base = np.linspace(0, 1, 100, endpoint=False)
        self.t_sym = np.concatenate([t_base + i for i in range(n)])
        
        # Requirement 4 & 9: Debug verification mode output
        print(f"Mode = {mode}")
        print(f"Symbols = {symbols[:20] if len(symbols) > 20 else symbols}")
        print("=== DEVELOPER VERIFICATION TABLE ===")
        print(f"{'Index':<8} {'Symbol':<8} {'Phase':<8} {'Waveform start sample':<22}")
        
        bits_list = []
        mod_wave_list = []
        car_wave_list = []
        fc = 2

        use_fpga_iq = (iq_history is not None and len(iq_history) == n)

        for i, sym in enumerate(symbols):
            # Requirement 3: Use modulation.py as ONE source of truth for symbol -> phase
            phase_deg = mod.expected_phase_deg(sym, mode)
            sym_str = mod.symbol_to_bit_string(sym, mode)
            if i < 20: # print verification for first 20 symbol intervals
                start_sample = i * 100
                print(f"{i:<8} {sym_str:<8} {phase_deg:<8.1f}° {start_sample:<22}")

            # Requirement 5: Baseband plot matches modulation mode
            if mode == "BPSK":
                b_val = 1 if sym == 1 else -1
                bits_list.append(np.full(100, b_val))
            else: # QPSK dibit values (0, 1, 2, 3)
                bits_list.append(np.full(100, sym))

            # Carrier: always pure reference sine
            carrier = np.sin(2 * np.pi * fc * t_base)
            car_wave_list.append(carrier)

            # Modulated waveform:
            # - For BPSK: use I·sin + Q·cos so symbol boundaries (at t=integer where sin=0)
            #   continue naturally through zero with only a phase reversal (\).
            # - For QPSK: model a real continuous RF oscillator by smoothly transitioning
            #   the carrier phase across symbol boundaries without vertical step jumps (|).
            if use_fpga_iq:
                I_val, Q_val = iq_history[i]
                curr_rad = np.arctan2(Q_val, I_val)
                mag = np.hypot(I_val, Q_val)
            else:
                curr_rad = np.radians(phase_deg)
                mag = 1.0
                I_val = np.cos(curr_rad)
                Q_val = np.sin(curr_rad)

            if mode == "QPSK" and i > 0:
                if use_fpga_iq:
                    prev_I, prev_Q = iq_history[i - 1]
                    prev_rad = np.arctan2(prev_Q, prev_I)
                else:
                    prev_rad = np.radians(mod.expected_phase_deg(symbols[i - 1], mode))
                
                delta_rad = (curr_rad - prev_rad + np.pi) % (2 * np.pi) - np.pi
                if abs(delta_rad) > 1e-4:
                    # Smooth raised-cosine phase transition over first 20 samples (20% of symbol)
                    W = 20
                    k = np.arange(100)
                    alpha = np.where(k < W, 0.5 - 0.5 * np.cos(np.pi * k / W), 1.0)
                    phi_t = prev_rad + alpha * delta_rad
                    I_t = mag * np.cos(phi_t)
                    Q_t = mag * np.sin(phi_t)
                    modulated = I_t * np.sin(2 * np.pi * fc * t_base) + Q_t * np.cos(2 * np.pi * fc * t_base)
                else:
                    modulated = I_val * np.sin(2 * np.pi * fc * t_base) + Q_val * np.cos(2 * np.pi * fc * t_base)
            else:
                modulated = I_val * np.sin(2 * np.pi * fc * t_base) + Q_val * np.cos(2 * np.pi * fc * t_base)

            mod_wave_list.append(modulated)
            
        self.bit_wave = np.concatenate(bits_list)
        self.car_wave = np.concatenate(car_wave_list)
        self.mod_wave = np.concatenate(mod_wave_list)

        for ax in self.axes: ax.clear()
        self._style_axes()
        
        quad_colors_qpsk = {0: THEME["C_CYAN"], 1: THEME["C_PURPLE"], 2: THEME["C_ORANGE"], 3: THEME["C_GREEN"]}
        quad_colors_bpsk = {0: THEME["C_CYAN"], 1: THEME["C_ORANGE"]}
        
        # Plot Baseband & Modulated RF Signal segment by segment (color-coded by phase state)
        for i, sym in enumerate(symbols):
            col = quad_colors_qpsk.get(sym, THEME["C_CYAN"]) if mode == "QPSK" else quad_colors_bpsk.get(sym, THEME["C_CYAN"])
            idx_start = i * 100
            idx_end = min((i + 1) * 100 + 1, len(self.t_sym))
            
            # Baseband segment
            line_b, = self._ax_bits.step(self.t_sym[idx_start:idx_end], self.bit_wave[idx_start:idx_end], where='post', color=col, linewidth=2.0)
            self._ax_bits.fill_between(self.t_sym[idx_start:idx_end], 0, self.bit_wave[idx_start:idx_end], step="post", color=col, alpha=0.15)
            if i == 0: self.bit_line = line_b
            
            # Modulated RF segment
            line_m, = self._ax_mod.plot(self.t_sym[idx_start:idx_end], self.mod_wave[idx_start:idx_end], color=col, linewidth=1.8)
            self._ax_mod.fill_between(self.t_sym[idx_start:idx_end], 0, self.mod_wave[idx_start:idx_end], alpha=0.18, color=col)
            if i == 0: self.mod_line = line_m

            # Symbol boundary divider (Static text annotations removed to prevent overflow when panning/zooming)
            if i > 0:
                for ax in self.axes:
                    ax.axvline(x=i, color=THEME["C_BORDER"], linestyle="--", linewidth=1.0, alpha=0.6)

        if mode == "QPSK":
            self._ax_bits.set_ylim(-0.5, 3.5)
            self._ax_bits.set_yticks([0, 1, 2, 3])
            self._ax_bits.set_yticklabels(["00 (45°)", "01 (135°)", "10 (225°)", "11 (315°)"], fontsize=8)
            for tick_label, col in zip(self._ax_bits.get_yticklabels(), [THEME["C_CYAN"], THEME["C_PURPLE"], THEME["C_ORANGE"], THEME["C_GREEN"]]):
                tick_label.set_color(col)
                tick_label.set_fontweight("bold")
            for y_val, col in zip([0, 1, 2, 3], [THEME["C_CYAN"], THEME["C_PURPLE"], THEME["C_ORANGE"], THEME["C_GREEN"]]):
                self._ax_bits.axhspan(y_val - 0.4, y_val + 0.4, color=col, alpha=0.04, zorder=0)
            self._ax_bits.set_ylabel("Baseband (Dibits)", color=THEME["C_ORANGE"], fontsize=10, fontweight="bold", labelpad=10)
        else:
            self._ax_bits.set_ylim(-1.5, 1.5)
            self._ax_bits.set_yticks([-1, 1])
            self._ax_bits.set_yticklabels(["0 (0°)", "1 (180°)"], fontsize=8)
            for tick_label, col in zip(self._ax_bits.get_yticklabels(), [THEME["C_CYAN"], THEME["C_ORANGE"]]):
                tick_label.set_color(col)
                tick_label.set_fontweight("bold")
            for y_val, col in zip([-1, 1], [THEME["C_CYAN"], THEME["C_ORANGE"]]):
                self._ax_bits.axhspan(y_val - 0.4, y_val + 0.4, color=col, alpha=0.04, zorder=0)
            self._ax_bits.set_ylabel("Baseband (Bits)", color=THEME["C_ORANGE"], fontsize=10, fontweight="bold", labelpad=10)
        
        # Plot carrier (Yellow for maximum visibility)
        yellow_col = "#FFD700"
        self.car_line, = self._ax_carrier.plot(self.t_sym, self.car_wave, color=yellow_col, linewidth=1.8, alpha=0.95)
        self._ax_carrier.fill_between(self.t_sym, 0, self.car_wave, alpha=0.18, color=yellow_col)
        self._ax_carrier.set_ylim(-1.5, 1.5)
        self._ax_carrier.set_ylabel("Carrier Signal", color=yellow_col, fontsize=10, fontweight="bold", labelpad=10)
        self._ax_mod.set_ylim(-1.5, 1.5)

        # Dynamic Color Legend
        if mode == "QPSK":
            legend_elements = [
                Line2D([0], [0], color=THEME["C_CYAN"], lw=3, label="00 (45° - Quad I)"),
                Line2D([0], [0], color=THEME["C_PURPLE"], lw=3, label="01 (135° - Quad II)"),
                Line2D([0], [0], color=THEME["C_ORANGE"], lw=3, label="10 (225° - Quad III)"),
                Line2D([0], [0], color=THEME["C_GREEN"], lw=3, label="11 (315° - Quad IV)"),
            ]
            ncol_val = 4
        else:
            legend_elements = [
                Line2D([0], [0], color=THEME["C_CYAN"], lw=3, label="0 (0° - Phase 0)"),
                Line2D([0], [0], color=THEME["C_ORANGE"], lw=3, label="1 (180° - Phase π)"),
            ]
            ncol_val = 2
        
        self._ax_mod.set_xlabel("Time (Symbols)", color=THEME["C_SUBTEXT"], labelpad=4)
        self._ax_mod.legend(handles=legend_elements, loc="upper center",
                            bbox_to_anchor=(0.5, -0.65), borderaxespad=0.0,
                            facecolor=THEME["C_SURFACE2"], edgecolor=THEME["C_BORDER"],
                            labelcolor=THEME["C_WHITE"], fontsize=8, framealpha=0.9, ncol=ncol_val)

        x_max = max(10, n)
        self._ax_bits.set_xlim(max(0, n - 10), x_max)
        
        if self._active_ax:
            # Maintain active styling logic on redraw
            self._focus_layout(self._active_ax)
            for ax in self.axes:
                if ax == self._active_ax:
                    ax.set_alpha(1.0)
                    for line in ax.get_lines(): line.set_alpha(1.0); line.set_linewidth(2.5)
                    for coll in ax.collections: coll.set_alpha(0.3)
        else:
            self._restore_layout()

        self.hide_plotting_status()
        self.canvas.draw_idle()

    def reset_zoom(self):
        self._clear_selection()
        if hasattr(self, 'toolbar') and self.toolbar:
            self.toolbar.home()
        if len(self.t_sym) > 0:
            n = int(np.ceil(self.t_sym[-1]))
            x_max = max(10, n)
            self._ax_bits.set_xlim(0, x_max)
            if hasattr(self, '_mode') and self._mode == "QPSK":
                self._ax_bits.set_ylim(-0.5, 3.5)
            else:
                self._ax_bits.set_ylim(-1.5, 1.5)
            self._ax_carrier.set_ylim(-1.5, 1.5)
            self._ax_mod.set_ylim(-1.5, 1.5)
        else:
            self.reset()
        self.canvas.draw_idle()

    def pan_waveforms(self, direction="right", step_pct=0.15):
        if len(self.t_sym) == 0:
            return
        cur_xlim = self._ax_bits.get_xlim()
        width = cur_xlim[1] - cur_xlim[0]
        shift = width * step_pct if direction == "right" else -width * step_pct
        
        new_left = cur_xlim[0] + shift
        new_right = cur_xlim[1] + shift
        
        # Don't pan past 0 on the left
        if new_left < 0:
            new_left = 0
            new_right = width
            
        max_time = max(10, self.t_sym[-1])
        if new_right > max_time and width < max_time:
            new_right = max_time
            new_left = max(0, max_time - width)
            
        for ax in self.axes:
            ax.set_xlim(new_left, new_right)
        self.canvas.draw_idle()

    def reset(self):
        self._active_ax = None
        if hasattr(self, 'top_bar'): self.top_bar.hide()
        for ax in self.axes:
            ax.clear()
        self._restore_layout()
        self._style_axes()
        self._ax_bits.set_xlim(0, 10); self._ax_bits.set_ylim(-1.5, 1.5)
        self._ax_carrier.set_xlim(0, 10); self._ax_carrier.set_ylim(-1.5, 1.5)
        self._ax_mod.set_xlim(0, 10); self._ax_mod.set_ylim(-1.5, 1.5)
        self.canvas.draw()