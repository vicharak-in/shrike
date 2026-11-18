"""
Bit-Accurate Python Reference Model for ForgeFPGA PID Line Follower.
Matches the exact register widths, signedness, arithmetic shifts, and saturation bounds of the Verilog RTL.
Supports both legacy DC Motor PWM and 360-Degree Continuous Rotation RC Servos.
"""

class PIDReferenceModel:
    def __init__(self, scale_shift=4, imax=63, search_speed=60):
        self.scale_shift = scale_shift
        self.imax = imax
        self.search_speed = search_speed
        self.reset()

    def reset(self):
        self.error_prev = 0
        self.integral_acc = 0
        self.steer_out = 0
        self.inter_sat = False
        self.steer_sat = False
        self.last_dir = 0 # 0=Left, 1=Right

    @staticmethod
    def encode_line_position(sensors: int) -> tuple[int, bool]:
        """
        Calculates line position error (-7 to +7) from 8-bit sensor bitmask.
        Returns (error, line_lost).
        """
        sensors &= 0xFF
        if sensors == 0x00:
            return 0, True

        lookup = {
            0b00000001:  7,
            0b00000010:  5,
            0b00000100:  3,
            0b00001000:  1,
            0b00010000: -1,
            0b00100000: -3,
            0b01000000: -5,
            0b10000000: -7,
            # Dual hits (interpolated centers)
            0b00011000:  0,
            0b00001100:  2,
            0b00000110:  4,
            0b00000011:  6,
            0b00110000: -2,
            0b01100000: -4,
            0b11000000: -6,
            # Triple hits
            0b00111000: -1,
            0b00011100:  1,
            0b01110000: -3,
            0b00001110:  3,
            0b11100000: -5,
            0b00000111:  5,
        }

        if sensors in lookup:
            return lookup[sensors], False

        # Fallback weighted centroid approximation
        if (sensors & 0b11000000) != 0:
            return -6, False
        if (sensors & 0b00000011) != 0:
            return 6, False
        if (sensors & 0b00110000) != 0:
            return -2, False
        return 2, False

    def pid_step(self, error: int, line_lost: bool, kp: int, ki: int, kd: int) -> int:
        """
        Executes one discrete PID cycle with exact fixed-point arithmetic.
        Matches the 2-stage pipelined Verilog RTL.
        """
        # Update last known direction
        if not line_lost:
            if error > 0:
                self.last_dir = 1
            elif error < 0:
                self.last_dir = 0

        # P Term: signed
        p_term = error * kp

        # D Term: signed
        delta_e = error - self.error_prev
        d_term = delta_e * kd
        self.error_prev = error

        # Integral accumulation with anti-windup clamping [-63, +63]
        if line_lost:
            self.inter_sat = False
        else:
            acc_next = self.integral_acc + error
            if acc_next > self.imax:
                self.integral_acc = self.imax
                self.inter_sat = True
            elif acc_next < -self.imax:
                self.integral_acc = -self.imax
                self.inter_sat = True
            else:
                self.integral_acc = acc_next
                self.inter_sat = False

        # I Term: (acc * ki) >> 2
        i_term = (self.integral_acc * ki) >> 2

        # Total PID sum
        pid_sum = p_term + i_term + d_term

        # Scale shift
        pid_scaled = pid_sum >> self.scale_shift

        # Output saturation to [-100, +100]
        if pid_scaled > 100:
            self.steer_out = 100
            self.steer_sat = True
        elif pid_scaled < -100:
            self.steer_out = -100
            self.steer_sat = True
        else:
            self.steer_out = pid_scaled
            self.steer_sat = False

        return self.steer_out

    def mix_motors(self, base_speed: int, steer: int, line_lost: bool) -> tuple[int, int]:
        """
        Differential drive mixer with line-loss pivot recovery.
        Returns intermediate (duty_l, duty_r) clamped to [0..255].
        """
        base_speed = max(0, min(255, base_speed))
        if base_speed == 0:
            return 0, 0
        if line_lost:
            if self.last_dir == 0:
                # Pivot Left
                return 0, self.search_speed
            else:
                # Pivot Right
                return self.search_speed, 0

        mix_left = base_speed - steer
        mix_right = base_speed + steer

        pwm_left = max(0, min(255, mix_left))
        pwm_right = max(0, min(255, mix_right))

        return pwm_left, pwm_right

    def mix_servos(self, base_speed: int, steer: int, line_lost: bool, is_armed: bool = True) -> tuple[int, int]:
        """
        360-Degree Continuous Rotation RC Servo Mixer.
        Returns target pulse widths in microseconds [1000..2000].
        Neutral stop: 1500 us.
        Left Servo:  1500 + 2*duty_l (Forward > 1500 us)
        Right Servo: 1500 - 2*duty_r (Forward < 1500 us, mirrored mount)
        Disarmed or speed 0: Returns (0, 0) for True Silence 0V mode.
        """
        if not is_armed or base_speed == 0:
            return 0, 0

        if line_lost:
            if self.last_dir == 0:
                # Pivot Left: Left stopped (1500 us), Right drives forward (1500 - 120 = 1380 us)
                return 1500, 1500 - (self.search_speed * 2)
            else:
                # Pivot Right: Left drives forward (1500 + 120 = 1620 us), Right stopped (1500 us)
                return 1500 + (self.search_speed * 2), 1500

        duty_l, duty_r = self.mix_motors(base_speed, steer, line_lost=False)
        pulse_l = max(1000, min(2000, 1500 + (duty_l * 2)))
        pulse_r = max(1000, min(2000, 1500 - (duty_r * 2)))
        return pulse_l, pulse_r

    def process_frame(self, sensor_byte: int, base_speed: int, kp=32, ki=2, kd=48, is_armed: bool = True) -> dict:
        """
        Executes complete sensor-to-motor/servo pipeline for one frame.
        """
        error, line_lost = self.encode_line_position(sensor_byte)
        steer = self.pid_step(error, line_lost, kp, ki, kd)
        pwm_l, pwm_r = self.mix_motors(base_speed, steer, line_lost)
        pulse_l, pulse_r = self.mix_servos(base_speed, steer, line_lost, is_armed)

        return {
            "error": error,
            "line_lost": line_lost,
            "steer": steer,
            "pwm_left": pwm_l,
            "pwm_right": pwm_r,
            "pulse_left_us": pulse_l,
            "pulse_right_us": pulse_r,
            "inter_sat": self.inter_sat,
            "steer_sat": self.steer_sat,
            "last_dir": self.last_dir
        }
