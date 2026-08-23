# =============================================================================
# shrike_serv_monitor.py
# Project  : shrike_serv  (interactive SERV RV32I monitor over UART)
# Board    : Shrike-lite (RP2040)
# Firmware : MicroPython (Shrike custom UF2)
# Licence  : GPL-2.0
#
# Brings up the SERV monitor and turns the RP2040 into a transparent bridge
# between the laptop's USB serial and the FPGA's hardware UART, so typing in your
# terminal talks straight to the CPU. Steps:
#   1. flash the shrike_serv_uart bitstream into the FPGA
#   2. stream monitor.bin into the 4 KB BRAM over SPI and release the core
#      (0xA3 halt / 0xA0 load / 4096 bytes / 0xA2 run -- same loader as shrike_serv)
#   3. switch the shared pins to UART0 and bridge USB <-> UART forever
#
# Pin sharing: GPIO1 is the SPI chip-select during load, then UART0 RX during run
# (FPGA pin 4 flips from SPI_SS to UART TX). Both idle high, so the handover has
# no bus contention. GPIO0 is UART0 TX -> FPGA pin 6 (UART RX).
#
# USAGE (on the board): copy shrike_serv.bin + monitor.bin + this file to the
# board, then `mpremote run shrike_serv_uart.py` and start typing at `serv>`.
# =============================================================================

import sys
import time
import uselect
import shrike
from machine import Pin, SPI, UART

BITSTREAM = 'shrike_serv.bin'
MONITOR   = 'monitor.bin'
PROG_BYTES = 4096

# -- SPI program-load (core held in reset) -----------------------------------
spi = SPI(0, baudrate=1_000_000, polarity=0, phase=0,
          bits=8, firstbit=SPI.MSB,
          sck=Pin(2), mosi=Pin(3), miso=Pin(0))
cs = Pin(1, Pin.OUT, value=1)


def spi_cmd(byte):
    cs.value(0)
    spi.write(bytes([byte & 0xFF]))
    cs.value(1)


def load_monitor():
    with open(MONITOR, 'rb') as f:
        img = f.read()
    img = (img + b'\x00' * PROG_BYTES)[:PROG_BYTES]
    spi_cmd(0xA3)                 # halt + re-arm
    spi_cmd(0xA0)                 # enter load
    cs.value(0)
    spi.write(img)               # 4 KB in one frame
    cs.value(1)
    spi_cmd(0xA2)                 # run


def bridge():
    """Transparent USB<->UART bridge. Ctrl-] in mpremote to exit."""
    spi.deinit()                 # release SPI pins
    cs.init(Pin.IN)              # stop driving GPIO1; FPGA now drives it (UART TX)
    time.sleep_ms(5)
    uart = UART(0, baudrate=115200, tx=Pin(0), rx=Pin(1))
    uart.write(b'\r')            # nudge the monitor to print a fresh prompt

    poll = uselect.poll()
    poll.register(sys.stdin, uselect.POLLIN)
    while True:
        busy = False
        if poll.poll(0):                       # laptop -> CPU
            ch = sys.stdin.read(1)
            if ch:
                uart.write(ch); busy = True
        n = uart.any()                         # CPU -> laptop
        if n:
            data = uart.read(n)
            if data:                           # drop any non-ASCII (handover glitch
                clean = bytes(b for b in data if b < 128)   # bytes; MicroPython
                if clean:                      # decode() ignores an errors= arg)
                    sys.stdout.write(clean.decode()); busy = True
        if not busy:
            time.sleep_ms(1)                   # yield so USB servicing isn't starved


print('Flashing shrike_serv bitstream...')
shrike.flash(BITSTREAM)
time.sleep(1)
print('Loading monitor.bin...')
load_monitor()
print('Bridging USB <-> UART. Type at the serv> prompt (Ctrl-] to exit).')
bridge()
