"""
Golden Test Suite for ForgeFPGA PID Line Follower.
Tests line position encoding, PID mathematical correctness, anti-windup clamping, and differential motor mixing.
"""
import sys
import os
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from reference_model import PIDReferenceModel

class TestPIDLineFollower(unittest.TestCase):
    def setUp(self):
        self.model = PIDReferenceModel()

    def test_line_position_encoding_symmetry(self):
        """Verify left-right error symmetry across all sensor channels."""
        cases = [
            (0b00011000, 0),   # Center
            (0b00010000, -1),  # Center Left
            (0b00001000, 1),   # Center Right
            (0b00100000, -3),  # Mid Left
            (0b00000100, 3),   # Mid Right
            (0b01000000, -5),  # Outer Left
            (0b00000010, 5),   # Outer Right
            (0b10000000, -7),  # Far Left
            (0b00000001, 7),   # Far Right
        ]
        for sensor_byte, expected_err in cases:
            err, lost = self.model.encode_line_position(sensor_byte)
            self.assertFalse(lost, f"Sensor byte {bin(sensor_byte)} falsely marked lost")
            self.assertEqual(err, expected_err, f"Mismatch on {bin(sensor_byte)}: got {err}, expected {expected_err}")

    def test_center_tracking_steady_state(self):
        """When centered on the line, both motors must run at identical base speed."""
        res = self.model.process_frame(0b00011000, base_speed=120)
        self.assertEqual(res["error"], 0)
        self.assertEqual(res["steer"], 0)
        self.assertEqual(res["pwm_left"], 120)
        self.assertEqual(res["pwm_right"], 120)

    def test_differential_steering_direction(self):
        """
        When line deviates to left (error = -7):
        Robot must turn right -> Left motor speeds up, Right motor slows down.
        """
        res_left = self.model.process_frame(0b10000000, base_speed=100)
        self.assertEqual(res_left["error"], -7)
        self.assertTrue(res_left["steer"] < 0, f"Expected negative steer, got {res_left['steer']}")
        self.assertTrue(res_left["pwm_left"] > res_left["pwm_right"],
                        f"Left duty ({res_left['pwm_left']}) must exceed right ({res_left['pwm_right']})")

        # Reset model and test right deviation
        self.model.reset()
        res_right = self.model.process_frame(0b00000001, base_speed=100)
        self.assertEqual(res_right["error"], 7)
        self.assertTrue(res_right["steer"] > 0, f"Expected positive steer, got {res_right['steer']}")
        self.assertTrue(res_right["pwm_right"] > res_right["pwm_left"],
                        f"Right duty ({res_right['pwm_right']}) must exceed left ({res_right['pwm_left']})")

    def test_integral_anti_windup(self):
        """Integral term must clamp at IMAX to prevent integral windup on prolonged saturation."""
        # Feed sustained error of +7 for 200 cycles
        for _ in range(200):
            res = self.model.process_frame(0b00000001, base_speed=100)

        self.assertEqual(self.model.integral_acc, self.model.imax)
        self.assertTrue(res["inter_sat"])

    def test_line_loss_pivot_recovery(self):
        """When line is lost, robot must execute spin turn toward last seen direction."""
        # First turn right (line is to the right)
        self.model.process_frame(0b00000001, base_speed=100)
        self.assertEqual(self.model.last_dir, 1) # Remembered right

        # Now lose line completely
        res = self.model.process_frame(0b00000000, base_speed=100)
        self.assertTrue(res["line_lost"])
        # Should pivot right: Left motor active, Right motor stopped
        self.assertEqual(res["pwm_left"], 60)
        self.assertEqual(res["pwm_right"], 0)

        # Now turn left and lose line
        self.model.reset()
        self.model.process_frame(0b10000000, base_speed=100)
        self.assertEqual(self.model.last_dir, 0) # Remembered left
        res = self.model.process_frame(0b00000000, base_speed=100)
        self.assertTrue(res["line_lost"])
        # Should pivot left: Left motor stopped, Right motor active
        self.assertEqual(res["pwm_left"], 0)
        self.assertEqual(res["pwm_right"], 60)

if __name__ == "__main__":
    unittest.main()
