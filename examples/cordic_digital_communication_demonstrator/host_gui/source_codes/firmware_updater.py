"""
firmware_updater.py
═══════════════════════════════════════════════════════════════
Automated firmware flasher for RP2040 CORDIC Demonstrator.
Copies local dcd.py to the RP2040 device as main.py and reboots it.
"""
import subprocess
import sys
import os
import time

def update_board_firmware(port_name: str, file_path: str = "dcd.py") -> tuple[bool, str]:
    """
    Connects to the RP2040 on `port_name`, stops running script,
    uploads `file_path` as `main.py`, and resets the board.
    """
    if not os.path.exists(file_path):
        # Look in directory of this file
        base_dir = os.path.dirname(os.path.abspath(__file__))
        file_path = os.path.join(base_dir, "dcd.py")
        if not os.path.exists(file_path):
            return False, f"Firmware file not found: {file_path}"

    python_exe = sys.executable

    # 1. First interrupt any running script
    try:
        import serial
        ser = serial.Serial(port_name, 115200, timeout=0.5)
        ser.write(b"\r\x03\x03\x03")
        time.sleep(0.3)
        ser.close()
    except Exception:
        pass

    # 2. Copy file using mpremote
    cmd_cp = [python_exe, "-m", "mpremote", "connect", port_name, "fs", "cp", file_path, ":main.py"]
    res = subprocess.run(cmd_cp, capture_output=True, text=True)
    if res.returncode != 0:
        # Try once more after another ctrl+C
        time.sleep(0.5)
        res = subprocess.run(cmd_cp, capture_output=True, text=True)
        if res.returncode != 0:
            err_str = res.stderr.strip() or res.stdout.strip() or "Unknown serial access error"
            return False, f"Upload failed: {err_str}\n(Make sure Thonny or other terminals are closed)"

    # 3. Reset board
    cmd_reset = [python_exe, "-m", "mpremote", "connect", port_name, "reset"]
    subprocess.run(cmd_reset, capture_output=True, text=True)
    time.sleep(0.5)

    return True, "Successfully flashed firmware v1.1 (CORDIC ANG: enabled) to RP2040!"

if __name__ == "__main__":
    print("════════════════════════════════════════════════════════")
    print(" RP2040 CORDIC Firmware Updater (v1.1)")
    print("════════════════════════════════════════════════════════")
    port = sys.argv[1] if len(sys.argv) > 1 else "COM5"
    print(f"Flashing dcd.py -> {port}:main.py ...")
    success, message = update_board_firmware(port)
    if success:
        print(f"\n[SUCCESS] {message}\n")
    else:
        print(f"\n[ERROR] {message}\n")
