"""
port_scanner.py
═══════════════════════════════════════════════════════════════
Tiny helper around pyserial's list_ports so the rest of the app
never has to import serial.tools directly.
"""
from typing import List, Tuple

try:
    from serial.tools import list_ports
    HAS_PYSERIAL = True
except ImportError:
    HAS_PYSERIAL = False


def get_available_ports() -> List[str]:
    """Return a list of available COM/tty device names."""
    if not HAS_PYSERIAL:
        return []
    return sorted(p.device for p in list_ports.comports())


def get_available_ports_detailed() -> List[Tuple[str, str]]:
    """Return [(device, description), ...] for richer UI display."""
    if not HAS_PYSERIAL:
        return []
    ports = list_ports.comports()
    return sorted(((p.device, p.description or p.device) for p in ports), key=lambda x: x[0])