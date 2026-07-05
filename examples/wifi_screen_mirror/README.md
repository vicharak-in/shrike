# WiFi Screen Mirror (Shrike-fi)

**Difficulty:** Advanced
**Uses MCU:** Yes
**External Hardware:** None — just the Shrike-fi board and a laptop on the same WiFi network

## A quick note before the template

This example doesn't touch the FPGA fabric — no Verilog, no bitstream. It's a
pure MCU/WiFi project built entirely on the ESP32-S3 side of Shrike-fi: the
board receives a live JPEG stream from a laptop over TCP and re-broadcasts it
to any browser on the network over WebSocket. Because of that, the usual
`ffpga/`, `bitstream/`, and `.ffpga` parts of the example folder structure
don't apply here and have been left out rather than filled with placeholders.
Flagging this up front in case this doesn't fit where FPGA-only examples are
meant to go — happy to move it under a different category if there's a
better fit than `examples/`.

## Overview

Turns the Shrike-fi into a wireless screen mirror. A small Python script on
the laptop grabs the screen, compresses it to JPEG, and sends it to the
board over a raw TCP socket. The board forwards frames to a WebSocket, and
any browser on the same WiFi (laptop, phone, TV) can open a page and watch
the screen live. To keep bandwidth down, only the part of the screen that
actually changed gets sent most of the time, instead of a full frame every
time.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-fi (ESP32-S3) | `firmware/arduino-ide/` | ✅ Tested |
| Shrike (RP2350) | — | ⬜ Not applicable, no WiFi on this board |
| Shrike-lite (RP2040) | — | ⬜ Not applicable, no WiFi on this board |

This example is WiFi-dependent, so it only runs on Shrike-fi.

## Hardware Setup

No external hardware required. Just the Shrike-fi board over USB and a
laptop on the same WiFi network.

## Quick Start

1. Open `firmware/arduino-ide/wifi_screen_mirror.ino` in Arduino IDE
2. Set your WiFi SSID/password near the top of the sketch
3. Install the **WebSockets** library by Markus Sattler (Sketch → Include
   Library → Manage Libraries → search "WebSockets") — the sketch will not
   compile without it
4. Board settings: ESP32S3 Dev Module, 240MHz CPU, PSRAM disabled
5. Upload, open Serial Monitor at 115200 baud, wait for it to print an IP
6. On the laptop: `pip install mss numpy opencv-python`, then run
   `host/screen_sender.py`
7. Open the printed URL (or `http://shrikecast.local/`) in a browser on any
   device on the same WiFi

## Build From Source

No FPGA build step — there's no Verilog in this example. Just compile and
upload the sketch from Arduino IDE as described above.

## How It Works

**Sender (laptop, Python):** captures the screen with `mss`, compares the
current frame to the last one sent, and finds the smallest region that
actually changed. Most frames only send that small changed region ("diff
frame"); every 5th frame sends the whole screen to stay in sync. Each frame
is sent as `[1B type]['F' or 'D'][2B x][2B y][4B length][JPEG bytes]` over
TCP — the x/y tells the receiver where on screen that patch belongs.

**Board (ESP32-S3):** one FreeRTOS task on core 0 does nothing but receive
TCP data and assemble frames into a double buffer. The main loop (core 1)
watches for a new frame and broadcasts it to every connected WebSocket
client. No image processing happens on the board — it's a pass-through, kept
deliberately simple to leave headroom for network I/O.

**Browser:** keeps one `<canvas>` alive for the session. Full frames redraw
the canvas from (0,0). Diff patches get drawn at their real (x,y) on top of
whatever's already there — nothing gets cleared. That's what turns a bunch
of small patches back into a coherent, correctly-updating picture instead of
a floating rectangle.

## Known Issue: watchdog reset on oversized frames

Worth documenting since it cost real debugging time and would trip up
anyone else pushing this board past its comfort zone.

The board has a fixed-size buffer for incoming frames (no PSRAM on this
particular unit — `ESP.getPsramSize()` reports 0 despite PSRAM showing as
present). If an incoming frame is larger than that buffer, the board is
supposed to just discard it and resync on the next valid frame header. The
first version of that discard/resync loop had no yield point in it — if
data kept arriving while it was draining an oversized frame, the loop could
spin long enough to starve the watchdog timer, and the board would hard
reset. From the laptop side this looked like `WinError 10054: An existing
connection was forcibly closed by the remote host`, with no obvious
indication that the board itself had crashed.

Fixed by bounding every read inside the drain loop and yielding periodically
regardless of how much data is queued, so an oversized frame gets discarded
cleanly and logged instead of taking the board down. Current firmware logs
`[TCP] Rejected frame: N bytes (buffer is N) — draining` when this happens,
so it's visible instead of silent.

## FPS vs Resolution

Tested on a local WiFi network, JPEG quality 70, diff frame every 5 frames.
"Sender FPS" is what the Python terminal reports (how fast the laptop is
capturing and pushing frames); "Render FPS" is what actually displays in
the browser — these diverge because decoding + drawing each JPEG into the
canvas is the real bottleneck at higher resolutions, not the network or the
capture side.

| Resolution | Sender FPS | Render FPS (browser) | Status |
|---|---|---|---|
| 320×240 | ~29–30 fps | 10–12 fps | Stable |
| 640×480 | ~26 fps | 6–8 fps | Stable, but render-bound |
| 960×540 | — | — | **Failed** — connection dropped immediately on connect |
| 1280×720 | ~1.5 fps (before crash) | — | **Failed** — ran briefly then the board reset |

**Where and why it broke:** both 960×540 and 1280×720 produce JPEGs that
routinely exceed the board's internal frame buffer. Once a frame is too big,
it hits the watchdog-reset bug described above (fixed in the firmware
included here, but the *practical* ceiling is still real — a rejected frame
is a dropped frame either way). Without PSRAM, 640×480 is the realistic
upper bound for this board; 320×240 is the sweet spot if you want smooth,
responsive mirroring rather than maximum resolution.

## Expected Output

Browser shows a live, correctly-positioned mirror of the laptop's screen.
Scrolling, typing, and window switches should all update smoothly at
640×480 or below. *(Add a screenshot to `images/` here.)*
