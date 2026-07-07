

import socket
import struct
import time
import sys
import argparse
import numpy as np
import mss
import cv2

# ── Args ──────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser()
parser.add_argument("--ip",      default="10.251.35.135" ,       help="ESP32 IP address")
parser.add_argument("--port",    default=5000,  type=int)
parser.add_argument("--width",   default=960,   type=int)
parser.add_argument("--height",  default=540,   type=int)
parser.add_argument("--quality", default=70,    type=int, help="JPEG quality 1-95")
parser.add_argument("--fps",     default=30,    type=int, help="Target FPS")
parser.add_argument("--diff",    default=5,     type=int,
                    help="Send full frame every N frames. 1=always full (no diff)")
parser.add_argument("--monitor", default=1,     type=int)
parser.add_argument("--threshold", default=20,  type=int,
                    help="Pixel change threshold 0-255 for diff detection")
args = parser.parse_args()

W         = args.width
H         = args.height
QUALITY   = args.quality
FPS       = args.fps
INTERVAL  = 1.0 / FPS
DIFF_N    = args.diff
THRESHOLD = args.threshold
BLOCK     = 16  # diff block size in pixels

if W > 65535 or H > 65535:
    print("[ERROR] width/height must fit in uint16 for the offset header")
    sys.exit(1)

# ── Connect ───────────────────────────────────────────────────────────────────
def connect(ip, port, retries=10):
    for i in range(retries):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            s.settimeout(5.0)
            s.connect((ip, port))
            s.settimeout(None)
            print(f"[NET] Connected to {ip}:{port}")
            return s
        except Exception as e:
            print(f"[NET] Retry {i+1}/{retries}: {e}")
            time.sleep(1.0)
    print("[NET] Could not connect. Is ESP32 running and on same network?")
    sys.exit(1)

sock = connect(args.ip, args.port)

# ── Screen capture setup ──────────────────────────────────────────────────────
sct = mss.MSS()
mon_info = sct.monitors[args.monitor]
screen_w = mon_info["width"]
screen_h = mon_info["height"]

# Capture center crop at exact output resolution — no resize needed
cx = mon_info["left"] + (screen_w - W) // 2
cy = mon_info["top"]  + (screen_h - H) // 2
region = {"left": cx, "top": cy, "width": W, "height": H}

print(f"[INFO] Screen: {screen_w}x{screen_h}")
print(f"[INFO] Capture region: {W}x{H} center crop")
print(f"[INFO] JPEG quality: {QUALITY}  FPS target: {FPS}")
print(f"[INFO] Diff every {DIFF_N} frames  Block size: {BLOCK}px  Threshold: {THRESHOLD}")
print(f"[INFO] Press Ctrl+C to stop\n")

# ── Send helpers ──────────────────────────────────────────────────────────────

def send_frame(frame_type: bytes, x: int, y: int, jpeg_bytes: bytes):
    """Send [1B type][2B x][2B y][4B length][JPEG data]"""
    header = frame_type + struct.pack(">HH", x, y) + struct.pack(">I", len(jpeg_bytes))
    try:
        sock.sendall(header + jpeg_bytes)
    except (BrokenPipeError, ConnectionResetError, OSError):
        raise

def encode_jpeg(img_array: np.ndarray, quality: int) -> bytes:
    """Encode numpy HxWx3 BGR array to JPEG bytes using OpenCV (fast)."""
    _, buf = cv2.imencode('.jpg', img_array,
                          [cv2.IMWRITE_JPEG_QUALITY, quality])
    return buf.tobytes()

# ── Frame differencing ────────────────────────────────────────────────────────

def find_diff_region(prev: np.ndarray, curr: np.ndarray):
    """
    Find the bounding box of changed 16x16 blocks between prev and curr.
    Returns (x, y, w, h) of the changed region, or None if nothing changed.
    Both arrays are HxWx3 uint8.
    """
    # Per-pixel max channel difference
    diff = np.max(np.abs(curr.astype(np.int16) - prev.astype(np.int16)), axis=2)

    changed_rows = []
    changed_cols = []
    for by in range(0, H, BLOCK):
        for bx in range(0, W, BLOCK):
            block = diff[by:by+BLOCK, bx:bx+BLOCK]
            if block.max() > THRESHOLD:
                changed_rows.append(by)
                changed_rows.append(min(by + BLOCK, H))
                changed_cols.append(bx)
                changed_cols.append(min(bx + BLOCK, W))

    if not changed_rows:
        return None  # nothing changed

    y0 = min(changed_rows)
    y1 = max(changed_rows)
    x0 = min(changed_cols)
    x1 = max(changed_cols)
    return (x0, y0, x1 - x0, y1 - y0)

# ── Main loop ─────────────────────────────────────────────────────────────────

frame_count  = 0
full_count   = 0
diff_count   = 0
skip_count   = 0
t_start      = time.time()
prev_frame   = None

try:
    while True:
        t0 = time.perf_counter()

        # Capture
        shot  = sct.grab(region)
        curr  = np.array(shot)[:, :, :3]  # mss gives BGRA, drop alpha -> BGR

        frame_count += 1
        is_full = (frame_count % DIFF_N == 0) or (prev_frame is None)

        if is_full:
            jpeg = encode_jpeg(curr, QUALITY)
            send_frame(b'F', 0, 0, jpeg)
            full_count  += 1
            prev_frame   = curr.copy()

        else:
            region_box = find_diff_region(prev_frame, curr)
            if region_box is None:
                # Screen hasn't changed — skip this frame entirely
                skip_count += 1
            else:
                x, y, w, h = region_box
                patch = curr[y:y+h, x:x+w]
                jpeg  = encode_jpeg(patch, QUALITY)
                send_frame(b'D', x, y, jpeg)
                diff_count  += 1
                prev_frame   = curr.copy()

        # Stats every 60 frames
        if frame_count % 60 == 0:
            elapsed = time.time() - t_start
            avg_fps = frame_count / elapsed
            frame_ms = (time.perf_counter() - t0) * 1000
            print(f"[SEND] frame={frame_count:5d}  "
                  f"full={full_count}  diff={diff_count}  skip={skip_count}  "
                  f"avg={avg_fps:.1f}fps  frame={frame_ms:.1f}ms")

        # Rate limit
        elapsed_frame = time.perf_counter() - t0
        sleep_t = INTERVAL - elapsed_frame
        if sleep_t > 0:
            time.sleep(sleep_t)

except KeyboardInterrupt:
    elapsed = time.time() - t_start
    print(f"\n[DONE] {frame_count} frames in {elapsed:.1f}s  "
          f"avg={(frame_count/elapsed):.1f} FPS")
    print(f"       full={full_count}  diff={diff_count}  skip={skip_count}")
except (BrokenPipeError, ConnectionResetError) as e:
    print(f"\n[ERROR] Connection lost: {e}")
    print("[ERROR] ESP32 may have rebooted — restart both")
finally:
    sct.close()
    sock.close()
