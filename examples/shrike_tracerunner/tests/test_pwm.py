"""
Unit test for FPGA Hardware PWM Generator and Safety Interlocks.
Simulates clock ticks, prescaler, duty comparison, enable/reset behavior, and motor mixer safety.
"""

from reference_model import PIDReferenceModel

def simulate_pwm(duty_val: int, prescaler: int = 10, total_periods: int = 2, enabled: bool = True):
    period_ticks = 256
    total_clocks = total_periods * period_ticks * prescaler

    pwm_cnt = 0
    prescaler_cnt = 0
    pwm_out = 0
    high_clocks = 0

    for _ in range(total_clocks):
        tick = (prescaler_cnt == (prescaler - 1))
        if tick:
            prescaler_cnt = 0
        else:
            prescaler_cnt += 1

        if not enabled:
            pwm_cnt = 0
            pwm_out = 0
        elif tick:
            pwm_cnt = (pwm_cnt + 1) & 0xFF
            pwm_out = 1 if (pwm_cnt < duty_val) else 0

        if pwm_out:
            high_clocks += 1

    duty_fraction = high_clocks / total_clocks
    return duty_fraction

def test_pwm_ratios():
    # Test 0% duty
    assert simulate_pwm(0) == 0.0, "Duty 0 must yield exactly 0%"

    # Test 50% duty (128 / 256 = 0.5)
    ratio_50 = simulate_pwm(128)
    assert abs(ratio_50 - 0.5) < 0.005, f"Duty 128 expected ~50%, got {ratio_50}"

    # Test 25% duty (64 / 256 = 0.25)
    ratio_25 = simulate_pwm(64)
    assert abs(ratio_25 - 0.25) < 0.005, f"Duty 64 expected ~25%, got {ratio_25}"

    # Test 75% duty (192 / 256 = 0.75)
    ratio_75 = simulate_pwm(192)
    assert abs(ratio_75 - 0.75) < 0.005, f"Duty 192 expected ~75%, got {ratio_75}"

    # Test ~99.6% duty (255 / 256 = 0.996)
    ratio_max = simulate_pwm(255)
    assert abs(ratio_max - (255/256)) < 0.005, f"Duty 255 expected ~99.6%, got {ratio_max}"

    # Test disabled state
    assert simulate_pwm(128, enabled=False) == 0.0, "Disabled PWM must yield 0%"

    print("[PASS] PWM duty ratios and disable assertions passed.")

def test_motor_mixer_zero_speed_safety():
    """Verify that when base_speed == 0, motors NEVER turn, even if line_lost is active."""
    model = PIDReferenceModel()
    
    # 1. Normal line following with zero speed
    pwm_l, pwm_r = model.mix_motors(base_speed=0, steer=20, line_lost=False)
    assert pwm_l == 0 and pwm_r == 0, f"Expected (0,0) when base_speed=0, got ({pwm_l},{pwm_r})"
    
    # 2. Line lost with zero speed: MUST NOT execute pivot search!
    model.last_dir = 1
    pwm_l, pwm_r = model.mix_motors(base_speed=0, steer=0, line_lost=True)
    assert pwm_l == 0 and pwm_r == 0, f"Expected (0,0) during line_lost when base_speed=0, got ({pwm_l},{pwm_r})"
    
    # 3. Line lost with active speed: Should pivot toward last_dir
    pwm_l, pwm_r = model.mix_motors(base_speed=100, steer=0, line_lost=True)
    assert pwm_l == 60 and pwm_r == 0, f"Expected (60,0) pivot right, got ({pwm_l},{pwm_r})"
    
    print("[PASS] Motor mixer zero-speed safety interlock assertions passed.")

def test_watchdog_timeout_model():
    """Verifies that an activity watchdog timeout forces motor enable low."""
    timeout_cycles = 2_500_000 # 50 ms at 50 MHz
    
    # Simulate packet arrival and timeout
    watchdog_cnt = 0
    watchdog_tripped = False
    is_armed = True
    
    # Simulate 60 ms without packet (3,000,000 cycles)
    for cycle in range(3_000_000):
        if not watchdog_tripped:
            if watchdog_cnt >= timeout_cycles:
                watchdog_tripped = True
                is_armed = False
            else:
                watchdog_cnt += 1
                
    assert watchdog_tripped is True, "Watchdog should have tripped after 50 ms"
    assert is_armed is False, "Robot must disarm when watchdog trips"
    print("[PASS] Hardware SPI watchdog simulation assertions passed.")

if __name__ == "__main__":
    test_pwm_ratios()
    test_motor_mixer_zero_speed_safety()
    test_watchdog_timeout_model()
    print("All PWM logic & safety simulation assertions PASSED!")
