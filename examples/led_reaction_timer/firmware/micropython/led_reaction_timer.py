import shrike 
shrike.flash("led_reaction_timer.bin")

import sys 
from machine import Pin
import time 
time.sleep(1)  

TRIGGER = Pin(1, Pin.OUT)  
LED_SIG = Pin(3, Pin.IN)   

def run_round():
    TRIGGER.low()
    time.sleep_ms(50)

    TRIGGER.high()
    time.sleep_ms(10)
    TRIGGER.low()

    print("Get ready...")

    # wait for FPGA to fire LED
    while LED_SIG.value() == 0:
        pass

    t_start = time.ticks_ms()
    input(">>> Press Enter to REACT: ")
    t_end = time.ticks_ms()

    print(f"Reaction time: {time.ticks_diff(t_end, t_start)} ms\n")
    time.sleep_ms(2500)

while True:
    run_round()