"""
Regression test for utils/shrike-ctl/shrike-ctl.py.

The repo has no existing Python test framework (test/blink_test.py and friends
are MicroPython scripts meant to run on real hardware, not assertion-based
unit tests), so this uses the standard-library `unittest` module and avoids
any hardware or third-party (pyserial) dependency by stubbing out the
`serial` module before the script is executed.

Behavior under test: when shrike-ctl.py is given multiple bitstream files on
the command line, every file must be sent over the serial port -- not just
the last one.
"""
import os
import runpy
import sys
import tempfile
import types
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT_PATH = os.path.join(REPO_ROOT, "utils", "shrike-ctl", "shrike-ctl.py")


class FakeSerial:
    """Stand-in for serial.Serial that records every write() call."""

    def __init__(self, port, baudrate, timeout=1, rtscts=False, dsrdtr=False):
        self.port = port
        self.baudrate = baudrate

    def write(self, data):
        FakeSerial.writes.append(bytes(data))
        return len(data)

    def close(self):
        pass


class ShrikeCtlMultiFileTest(unittest.TestCase):
    def setUp(self):
        # Stub the `serial` module so the script can run without pyserial
        # or a real device attached.
        FakeSerial.writes = []
        self._real_serial_module = sys.modules.get("serial")
        fake_serial_module = types.ModuleType("serial")
        fake_serial_module.Serial = FakeSerial
        sys.modules["serial"] = fake_serial_module

        self._real_argv = sys.argv
        self.tmpdir = tempfile.TemporaryDirectory()

    def tearDown(self):
        if self._real_serial_module is not None:
            sys.modules["serial"] = self._real_serial_module
        else:
            sys.modules.pop("serial", None)
        sys.argv = self._real_argv
        self.tmpdir.cleanup()

    def test_all_files_are_uploaded_not_just_the_last(self):
        first_path = os.path.join(self.tmpdir.name, "first.bin")
        second_path = os.path.join(self.tmpdir.name, "second.bin")
        with open(first_path, "wb") as f:
            f.write(b"AAAA")
        with open(second_path, "wb") as f:
            f.write(b"BBBB")

        sys.argv = ["shrike-ctl.py", "/dev/ttyFAKE", first_path, second_path]

        runpy.run_path(SCRIPT_PATH, run_name="__main__")

        sent_data = b"".join(FakeSerial.writes)
        self.assertIn(b"AAAA", sent_data, "first file was never sent")
        self.assertIn(b"BBBB", sent_data, "second file was never sent")


if __name__ == "__main__":
    unittest.main()
