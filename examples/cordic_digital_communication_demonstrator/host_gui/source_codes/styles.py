import matplotlib as mpl

# Commercial RF Engineering Software Color Palette
THEME = {
    "C_BG": "#090909",           # Pure dark background
    "C_SURFACE": "#121212",      # Main card surface
    "C_SURFACE2": "#181818",     # Inner container / input surface
    "C_SURFACE3": "#1A1A1A",     # Slightly lighter for pressed states
    "C_BORDER": "#2E2E2E",       # Minimal border
    "C_BORDER2": "#3A3A3A",      # Focus border
    "C_TEXT": "#FFFFFF",         # White text
    "C_SUBTEXT": "#A0A0A0",      # Medium Grey text
    "C_DIM": "#606060",          # Muted text / gridlines
    "C_WHITE": "#FFFFFF",        # True white
    
    # 5 Accent Colors (Strict Requirement)
    "C_ACCENT": "#007ACC",       # Electric Blue (Primary)
    "C_CYAN": "#00D2FF",         # Cyan (Secondary highlights)
    "C_PURPLE": "#9D4EDD",       # Purple (Special metrics)
    "C_ORANGE": "#FF8A00",       # Orange (Warning / Active selection)
    "C_GREEN": "#00C853",        # Green (Status OK)
    
    # Aliases for compatibility/specific usage
    "C_RED": "#FF3333",          # Kept for explicit error/disconnect states
    "C_TEAL": "#00D2FF",         # Alias to Cyan
    "C_AMBER": "#FF8A00",        # Alias to Orange
    "C_I_COLOR": "#00D2FF",      # I-phase Cyan
    "C_Q_COLOR": "#9D4EDD",      # Q-phase Purple
}

def apply_mpl_style():
    """Configures matplotlib rcParams to match the premium dark design."""
    mpl.rcParams.update({
        "figure.facecolor": THEME["C_SURFACE"],
        "axes.facecolor": THEME["C_BG"],
        "axes.edgecolor": THEME["C_BORDER"],
        "axes.labelcolor": THEME["C_TEXT"],
        "xtick.color": THEME["C_SUBTEXT"], 
        "ytick.color": THEME["C_SUBTEXT"],
        "xtick.labelcolor": THEME["C_SUBTEXT"], 
        "ytick.labelcolor": THEME["C_SUBTEXT"],
        "grid.color": THEME["C_BORDER"], 
        "grid.linewidth": 0.5, 
        "grid.alpha": 0.8,
        "lines.linewidth": 1.5,
        "font.family": "sans-serif",
        "font.sans-serif": ["Segoe UI Variable", "Segoe UI", "Arial", "DejaVu Sans"],
        "font.size": 9,
    })

def build_stylesheet():
    """Generates the premium dark QSS stylesheet for PyQt6."""
    return f"""
    QMainWindow {{
        background-color: {THEME["C_BG"]};
    }}
    
    QWidget {{
        background-color: transparent;
        color: {THEME["C_TEXT"]};
        font-family: 'Segoe UI Variable', 'Inter', -apple-system, sans-serif;
        font-size: 10pt;
    }}
    
    QStatusBar {{
        background-color: {THEME["C_BG"]};
        color: {THEME["C_SUBTEXT"]};
        border-top: 1px solid {THEME["C_BORDER"]};
    }}
    
    /* Rounded Card Containers */
    QFrame#card {{
        background-color: {THEME["C_SURFACE"]};
        border: 1px solid {THEME["C_BORDER"]};
        border-radius: 12px;
    }}
    
    QLabel#card_title {{
        color: {THEME["C_WHITE"]};
        font-size: 13pt;
        font-weight: 700;
        background-color: transparent;
        border: none;
    }}
    
    QLabel#card_subtitle {{
        color: {THEME["C_SUBTEXT"]};
        font-size: 9pt;
        background-color: transparent;
        border: none;
    }}
    
    /* Text Inputs & Dropdowns */
    QComboBox, QLineEdit, QTextEdit, QSpinBox {{
        background-color: {THEME["C_SURFACE2"]};
        border: 1px solid {THEME["C_BORDER"]};
        border-radius: 6px;
        padding: 6px 12px;
        color: {THEME["C_TEXT"]};
        min-height: 22px;
    }}
    
    QComboBox:hover, QLineEdit:hover, QSpinBox:hover {{
        border: 1px solid {THEME["C_BORDER2"]};
    }}
    
    QComboBox:focus, QLineEdit:focus, QTextEdit:focus, QSpinBox:focus {{
        border: 1px solid {THEME["C_ACCENT"]};
    }}
    
    QComboBox::drop-down {{
        subcontrol-origin: padding;
        subcontrol-position: top right;
        width: 25px;
        border-left-width: 0px;
    }}
    
    QComboBox QAbstractItemView {{
        background-color: {THEME["C_SURFACE2"]};
        border: 1px solid {THEME["C_BORDER"]};
        selection-background-color: {THEME["C_ACCENT"]};
        selection-color: {THEME["C_WHITE"]};
        outline: 0px;
        border-radius: 6px;
    }}
    
    /* Interactive Buttons */
    QPushButton {{
        background-color: {THEME['C_SURFACE3']};
        color: {THEME['C_TEXT']};
        border: 1px solid {THEME['C_BORDER']};
        border-radius: 6px;
        padding: 8px 16px;
        font-weight: 600;
        min-width: 80px;
    }}
    QPushButton:hover {{
        background-color: {THEME['C_SURFACE2']};
        border: 1px solid {THEME['C_BORDER2']};
    }}
    QPushButton:pressed {{
        background-color: {THEME['C_SURFACE']};
    }}
    QPushButton:disabled {{
        background-color: {THEME['C_SURFACE']};
        color: {THEME['C_DIM']};
        border: 1px solid {THEME['C_SURFACE2']};
    }}
    QPushButton#primary {{
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #005A9E, stop:1 {THEME['C_ACCENT']});
        color: {THEME['C_WHITE']};
        border: 1px solid #005A9E;
        border-radius: 6px;
        font-weight: bold;
        min-width: 120px;
    }}
    QPushButton#primary:hover {{
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0078D7, stop:1 #0099FF);
        border: 1px solid #0078D7;
    }}
    QPushButton#primary:pressed {{
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #004A82, stop:1 #005A9E);
    }}
    QPushButton#primary:disabled {{
        background: {THEME['C_SURFACE2']};
        color: {THEME['C_DIM']};
        border: 1px solid {THEME['C_BORDER']};
    }}
    
    QPushButton#danger {{
        background-color: {THEME["C_RED"]};
        color: {THEME["C_WHITE"]};
        border: none;
    }}
    
    QPushButton#danger:hover {{
        background-color: #FF5555;
    }}
    
    QPushButton#danger:pressed {{
        background-color: #CC2222;
    }}
    
    QPushButton#ghost {{
        background-color: transparent;
        color: {THEME["C_SUBTEXT"]};
        border: none;
        padding: 4px;
    }}
    
    QPushButton#ghost:hover {{
        background-color: {THEME["C_SURFACE2"]};
        border-radius: 6px;
    }}
    
    /* Radio Buttons */
    QRadioButton {{
        spacing: 8px;
        color: {THEME["C_TEXT"]};
    }}
    
    QRadioButton::indicator {{
        width: 14px;
        height: 14px;
        border-radius: 7px;
        border: 2px solid {THEME["C_BORDER"]};
        background: {THEME["C_SURFACE2"]};
    }}
    
    QRadioButton::indicator:hover {{
        border-color: {THEME["C_ACCENT"]};
    }}
    
    QRadioButton::indicator:checked {{
        border-color: {THEME["C_ACCENT"]};
        background-color: {THEME["C_ACCENT"]};
    }}
    
    /* Custom QTabWidget */
    QTabWidget::pane {{
        border: 1px solid {THEME["C_BORDER"]};
        border-radius: 8px;
        background-color: {THEME["C_SURFACE"]};
        top: -1px;
    }}
    
    QTabBar::tab {{
        background-color: transparent;
        color: {THEME["C_SUBTEXT"]};
        padding: 8px 16px;
        margin-right: 4px;
        border-bottom: 2px solid transparent;
        font-weight: 600;
    }}
    
    QTabBar::tab:hover {{
        color: {THEME["C_TEXT"]};
    }}
    
    QTabBar::tab:selected {{
        color: {THEME["C_ACCENT"]};
        border-bottom: 2px solid {THEME["C_ACCENT"]};
    }}
    
    /* Scrollbars */
    QScrollBar:vertical, QScrollBar:horizontal {{
        border: none;
        background: {THEME["C_BG"]};
        width: 8px;
        height: 8px;
        margin: 0px;
    }}
    
    QScrollBar::handle:vertical, QScrollBar::handle:horizontal {{
        background: {THEME["C_BORDER"]};
        min-height: 20px;
        border-radius: 4px;
    }}
    
    QScrollBar::handle:vertical:hover, QScrollBar::handle:horizontal:hover {{
        background: {THEME["C_BORDER2"]};
    }}
    
    QScrollBar::add-line, QScrollBar::sub-line {{
        height: 0px; width: 0px;
    }}
    """

APP_STYLE = build_stylesheet()