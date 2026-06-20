"""
Regression test for shrike-ctl.py.

shrike-ctl.py accepts one or more firmware/bitstream paths on the command
line (`sys.argv[2:]`) and validates each one inside a loop. The upload
itself must happen for every validated path, not just the last one.

This test stubs out `serial.Serial` so no hardware is required, runs the
real script with two fake bitstream files on argv, and checks that the
bytes of *both* files were written to the serial port.
"""

import os
import runpy
import sys
import types

SCRIPT_PATH = os.path.join(os.path.dirname(__file__), "shrike-ctl.py")


class FakeSerial:
    """Stand-in for serial.Serial that records every write() call."""

    instances = []

    def __init__(self, port, baudrate, timeout=1, rtscts=False, dsrdtr=False):
        self.port = port
        self.writes = []
        FakeSerial.instances.append(self)

    def write(self, data):
        self.writes.append(bytes(data))

    def close(self):
        pass


def run_script_with_files(file_paths, monkeypatch):
    """Run shrike-ctl.py as if invoked from the CLI with file_paths,
    capturing everything written to the fake serial port."""
    FakeSerial.instances.clear()

    fake_serial_module = types.ModuleType("serial")
    fake_serial_module.Serial = FakeSerial
    monkeypatch.setitem(sys.modules, "serial", fake_serial_module)
    monkeypatch.setattr(sys, "argv", ["shrike-ctl.py", "/dev/ttyFAKE", *file_paths])

    runpy.run_path(SCRIPT_PATH, run_name="__main__")

    assert FakeSerial.instances, "script never opened the serial port"
    return b"".join(b"".join(inst.writes) for inst in FakeSerial.instances)


def test_uploads_every_file_passed_on_the_command_line(monkeypatch, tmp_path):
    first = tmp_path / "first.bin"
    second = tmp_path / "second.bin"
    first.write_bytes(b"A" * 10)
    second.write_bytes(b"B" * 10)

    written = run_script_with_files([str(first), str(second)], monkeypatch)

    assert b"A" * 10 in written, "bytes of the first firmware file were never sent over serial"
    assert b"B" * 10 in written, "bytes of the second firmware file were never sent over serial"
