"""
Unit tests for 360-Degree Continuous Rotation Servo Engine and Pulse Generation.
Validates 50 Hz frame timing (20 ms period), microsecond pulse widths, differential steering,
chassis mirroring, line loss recovery, and zero-creep silence mode.
"""

import sys
import os
import unittest

sys.path.insert(0, os.path.dirname(__file__))
from reference_model import PIDReferenceModel

def simulate_servo_pulse(target_pulse_us: int, clock_freq_hz: int = 50_000_000,
                          frame_period_us: int = 20_000, is_armed: bool = True) -> tuple[float, float]:
    """
    Simulates cycle-by-cycle behavior of the 50 Hz RC servo pulse generator.
    Returns (measured_high_time_us, frame_period_ms).
    """
    cycles_per_us = clock_freq_hz // 1_000_000  # 50 cycles at 50 MHz
    total_frame_cycles = frame_period_us * cycles_per_us

    us_div = 0
    frame_cnt = 0
    high_cycles = 0

    for _ in range(total_frame_cycles):
        tick_us = (us_div == (cycles_per_us - 1))
        if tick_us:
            us_div = 0
            if frame_cnt == (frame_period_us - 1):
                frame_cnt = 0
            else:
                frame_cnt += 1
        else:
            us_div += 1

        pulse_out = 1 if (is_armed and (target_pulse_us > 0) and (frame_cnt < target_pulse_us)) else 0
        if pulse_out:
            high_cycles += 1

    high_time_us = high_cycles / cycles_per_us
    frame_period_ms = total_frame_cycles / (clock_freq_hz / 1000)
    return high_time_us, frame_period_ms

class TestServoEngine(unittest.TestCase):
    def setUp(self):
        self.model = PIDReferenceModel()

    def test_50hz_frame_period(self):
        """Verify the servo pulse repeats at exactly 50 Hz (20.0 ms period)."""
        _, period_ms = simulate_servo_pulse(1500)
        self.assertAlmostEqual(period_ms, 20.0, places=2, msg="Servo frame period must be exactly 20.0 ms (50 Hz)")

    def test_center_tracking_neutral_forward(self):
        """When centered on line at speed 100, both servos drive forward symmetrically."""
        res = self.model.process_frame(0b00011000, base_speed=100)
        self.assertEqual(res["error"], 0)
        self.assertEqual(res["steer"], 0)
        # Left forward: 1500 + 2*100 = 1700 us
        # Right forward (mirrored): 1500 - 2*100 = 1300 us
        self.assertEqual(res["pulse_left_us"], 1700)
        self.assertEqual(res["pulse_right_us"], 1300)

        # Measure simulated pulse width in us
        measured_l, _ = simulate_servo_pulse(res["pulse_left_us"])
        measured_r, _ = simulate_servo_pulse(res["pulse_right_us"])
        self.assertAlmostEqual(measured_l, 1700.0, places=1)
        self.assertAlmostEqual(measured_r, 1300.0, places=1)

    def test_differential_steering_mirroring(self):
        """
        When line deviates to left (error = -7):
        Robot must turn right -> Left wheel speeds up (> 1700 us), Right wheel slows down / reverses (> 1300 us).
        """
        res_left_err = self.model.process_frame(0b10000000, base_speed=100)
        self.assertEqual(res_left_err["error"], -7)
        self.assertTrue(res_left_err["steer"] < 0)
        # Left servo should be faster forward (> 1700 us)
        self.assertTrue(res_left_err["pulse_left_us"] > 1700,
                        f"Left pulse ({res_left_err['pulse_left_us']}) should exceed 1700 us")
        # Right servo should slow down (closer to 1500 us neutral or reverse > 1500 us)
        self.assertTrue(res_left_err["pulse_right_us"] > 1300,
                        f"Right pulse ({res_left_err['pulse_right_us']}) should be closer to neutral than 1300 us")

        # Now test right deviation (error = +7)
        self.model.reset()
        res_right_err = self.model.process_frame(0b00000001, base_speed=100)
        self.assertEqual(res_right_err["error"], 7)
        self.assertTrue(res_right_err["steer"] > 0)
        # Right servo speeds up forward (< 1300 us)
        self.assertTrue(res_right_err["pulse_right_us"] < 1300)
        # Left servo slows down (< 1700 us)
        self.assertTrue(res_right_err["pulse_left_us"] < 1700)

    def test_line_lost_pivot_spin_turn(self):
        """When line is lost, robot executes in-place pivot toward last seen line direction."""
        # Previous turn was right
        self.model.process_frame(0b00000001, base_speed=100)
        self.assertEqual(self.model.last_dir, 1)

        # Line lost: Should pivot right (Left drives forward 1620 us, Right stopped at neutral 1500 us)
        res = self.model.process_frame(0b00000000, base_speed=100)
        self.assertTrue(res["line_lost"])
        self.assertEqual(res["pulse_left_us"], 1620)
        self.assertEqual(res["pulse_right_us"], 1500)

        # Previous turn was left
        self.model.reset()
        self.model.process_frame(0b10000000, base_speed=100)
        self.assertEqual(self.model.last_dir, 0)

        # Line lost: Should pivot left (Left stopped at 1500 us, Right drives forward at 1380 us)
        res = self.model.process_frame(0b00000000, base_speed=100)
        self.assertTrue(res["line_lost"])
        self.assertEqual(res["pulse_left_us"], 1500)
        self.assertEqual(res["pulse_right_us"], 1380)

    def test_zero_creep_silence_mode(self):
        """When disarmed or base_speed == 0, output must be exactly 0 us (0V silence) to prevent servo creep."""
        # Disarmed
        res_disarmed = self.model.process_frame(0b00011000, base_speed=100, is_armed=False)
        self.assertEqual(res_disarmed["pulse_left_us"], 0)
        self.assertEqual(res_disarmed["pulse_right_us"], 0)
        measured_l, _ = simulate_servo_pulse(res_disarmed["pulse_left_us"], is_armed=False)
        self.assertEqual(measured_l, 0.0, "Disarmed output must be flat 0V (no pulses)")

        # Speed == 0
        res_zero_speed = self.model.process_frame(0b00011000, base_speed=0, is_armed=True)
        self.assertEqual(res_zero_speed["pulse_left_us"], 0)
        self.assertEqual(res_zero_speed["pulse_right_us"], 0)
        measured_zero, _ = simulate_servo_pulse(res_zero_speed["pulse_left_us"])
        self.assertEqual(measured_zero, 0.0, "Zero speed output must be flat 0V (no pulses)")

if __name__ == "__main__":
    unittest.main()
