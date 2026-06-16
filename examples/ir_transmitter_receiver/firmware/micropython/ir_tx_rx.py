import shrike, time
from machine import Pin

print("=" * 56)
print("   IR NEC PROJECT - Vicharak Shrike (RP2040 + eFPGA)")
print("=" * 56)
print("\nFlashing FPGA bitstream...")
shrike.flash("ir_tx_rx.bin")
time.sleep(1)
print("FPGA programmed OK.\n")

data = Pin(5, Pin.OUT, value=0)
clk  = Pin(6, Pin.OUT, value=0)
dout = Pin(7, Pin.IN, Pin.PULL_DOWN)

def send_word(b0, b1, b2):
    word = (b0 << 16) | (b1 << 8) | b2
    for i in range(23, -1, -1):
        data.value((word >> i) & 1)
        time.sleep_us(20)
        clk.value(1); time.sleep_us(20)
        clk.value(0); time.sleep_us(20)
    data.value(0)

def read_word():
    w = 0
    for i in range(24):
        bit = dout.value()
        w = (w << 1) | bit
        clk.value(1); time.sleep_us(30)
        clk.value(0); time.sleep_us(60)
    return w

def _one_shot(addr, cmd):
    send_word(0x01, addr, cmd)  
    time.sleep_ms(150)     
    if not dout.value():
        return None
    w = read_word()
    status = (w >> 16) & 0xFF
    raddr = (w >> 8) & 0xFF
    rcmd = w & 0xFF
    if status == 0x81:
        return (raddr, rcmd)
    if status == 0x82:
        return "REPEAT"
    return None

def transmit_and_decode(addr, cmd, tries=5):
    for n in range(1, tries + 1):
        r = _one_shot(addr, cmd)
        if isinstance(r, tuple) and r == (addr, cmd):
            return r, n
        time.sleep_ms(120)
    return r, tries

print("NEC protocol frame structure transmitted on IR:")
print("    +--------+-----------+-----------+------------+------+")
print("    | 9ms ON | 4.5ms OFF | 32 bits   | addr/cmd   | stop |")
print("    +--------+-----------+-----------+------------+------+")
print("    32 bits = addr, ~addr, cmd, ~cmd  (each bit = 38kHz burst)")
print("    Logic 0 = 562us burst + 562us gap")
print("    Logic 1 = 562us burst + 1687us gap\n")

test_set = [
    (0x12, 0x34),
    (0x00, 0x20),
    (0x00, 0x21),
    (0xA5, 0x5A),
    (0xFF, 0x0F),
]

print("Live transmit + decode round-trips:")
print("    {:>4} {:>4}   {:<10} {:>5}  {}".format(
      "Addr", "Cmd", "Decoded", "Tries", "Status"))
print("    " + "-" * 40)

passed = 0
for addr, cmd in test_set:
    result, tries = transmit_and_decode(addr, cmd)
    if isinstance(result, tuple) and result == (addr, cmd):
        decoded = "0x{:02X}/0x{:02X}".format(result[0], result[1])
        status = "OK"
        passed += 1
    elif result is None:
        decoded = "--"
        status = "no decode"
    else:
        decoded = "0x{:02X}/0x{:02X}".format(result[0], result[1])
        status = "mismatch"
    print("    0x{:02X} 0x{:02X}   {:<10} {:>4}   {}".format(
          addr, cmd, decoded, tries, status))
    time.sleep_ms(300)

print("    " + "-" * 40)
print("    {}/{} commands transmitted and decoded correctly\n".format(
      passed, len(test_set)))

print("=" * 56)
if passed == len(test_set):
    print("   RESULT: IR LINK FULLY WORKING")
    print("   MCU -> FPGA -> IR LED -> air -> TSOP -> FPGA -> MCU")
else:
    print("   RESULT: {}/{} ok - check IR LED <-> TSOP alignment".format(
          passed, len(test_set)))
print("=" * 56)
