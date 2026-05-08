"""
Shrike-fi WebFlash — OTA FPGA Bitstream Flasher
================================================
Serves a drag-and-drop web UI over Wi-Fi AP/Station mode.
Connect to the Shrike-fi AP, open 192.168.4.1 in a browser,
and drop a .bin bitstream file to flash the SLG47910 ForgeFPGA.

Bitstreams are stored in the root of the ESP32 filesystem so
you can re-flash any previously uploaded design from the web UI.

Hardware: Shrike-fi (ESP32-S3 + Renesas SLG47910 ForgeFPGA)
Author:   Deepak Sharda / Vicharak Computers
"""

import network
import socket
import time
import os
import gc
import json
import shrike

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
# Station mode — set these to your Wi-Fi network
STA_SSID = ""                     # your Wi-Fi SSID (leave "" to skip station mode)
STA_PASSWORD = ""                 # your Wi-Fi password
STA_TIMEOUT = 10                  # seconds to wait for connection

# AP mode — fallback if station fails
AP_SSID = "Shrike-fi"
AP_PASSWORD = "vicharak123"       # min 8 chars for WPA2; set "" for open
AP_IP = "192.168.4.1"

WEB_PORT = 80
MAX_BITSTREAM_SIZE = 48 * 1024    # 48 KB — SLG47910 bitstream
LAST_FLASHED_FILE = "/last_flashed.txt"

# Files that should never show up in the bitstream list
SYSTEM_FILES = {"boot.py", "main.py", "index.html", "shrike.py", "webrepl_cfg.py", "last_flashed.txt"}


# ──────────────────────────────────────────────
# Filesystem helpers
# ──────────────────────────────────────────────
def list_bitstreams() -> list:
    """Return list of .bin files in root with name and size."""
    files = []
    try:
        for name in os.listdir("/"):
            if name.endswith(".bin") and name not in SYSTEM_FILES:
                stat = os.stat("/" + name)
                files.append({"name": name, "size": stat[6]})
        files.sort(key=lambda f: f["name"])
    except OSError:
        pass
    return files


def sanitize_filename(name: str) -> str:
    """Strip path components and dangerous characters."""
    if "/" in name:
        name = name.rsplit("/", 1)[-1]
    if "\\" in name:
        name = name.rsplit("\\", 1)[-1]
    allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."
    name = "".join(c for c in name if c in allowed)
    if not name.endswith(".bin"):
        name += ".bin"
    if name == ".bin":
        name = "bitstream.bin"
    return name


def get_last_flashed() -> str:
    """Return the name of the last flashed bitstream, or empty string."""
    try:
        with open(LAST_FLASHED_FILE, "r") as f:
            return f.read().strip()
    except OSError:
        return ""


def set_last_flashed(name: str):
    """Save the name of the last flashed bitstream."""
    try:
        with open(LAST_FLASHED_FILE, "w") as f:
            f.write(name)
    except:
        pass


# ──────────────────────────────────────────────
# Bitstream validation
# ──────────────────────────────────────────────
def validate_bitstream(data: bytes) -> tuple:
    """Basic sanity checks. Returns (ok, message)."""
    if len(data) == 0:
        return False, "Empty file"
    if len(data) > MAX_BITSTREAM_SIZE:
        return False, f"File too large ({len(data)} bytes, max {MAX_BITSTREAM_SIZE})"
    return True, "OK"


# ──────────────────────────────────────────────
# Web page
# ──────────────────────────────────────────────
def load_html() -> str:
    try:
        with open("index.html", "r") as f:
            return f.read()
    except OSError:
        return "<html><body><h1>Shrike-fi WebFlash</h1><p>index.html not found.</p></body></html>"


# ──────────────────────────────────────────────
# HTTP helpers
# ──────────────────────────────────────────────
def send_response(client, status, content_type, body):
    if isinstance(body, str):
        body = body.encode("utf-8")
    client.send(f"HTTP/1.1 {status}\r\n".encode())
    client.send(f"Content-Type: {content_type}\r\n".encode())
    client.send(f"Content-Length: {len(body)}\r\n".encode())
    client.send(b"Connection: close\r\n\r\n")
    # Send body in chunks — MicroPython socket.send() can truncate large buffers
    mv = memoryview(body)
    sent = 0
    while sent < len(body):
        chunk = mv[sent:sent + 1024]
        n = client.write(chunk)
        if n is None:
            n = len(chunk)
        sent += n


def send_json(client, status, obj):
    body = json.dumps(obj)
    send_response(client, status, "application/json", body)


def parse_request(client) -> tuple:
    """Read and parse HTTP request. Returns (method, path, headers, body) or None on bad request."""
    data = b""
    while b"\r\n\r\n" not in data:
        try:
            chunk = client.recv(1024)
        except:
            return None
        if not chunk:
            break
        data += chunk

    if not data or b"\r\n\r\n" not in data:
        return None

    header_end = data.find(b"\r\n\r\n")
    header_part = data[:header_end].decode("utf-8")
    body_part = data[header_end + 4:]

    lines = header_part.split("\r\n")
    parts = lines[0].split(" ")
    if len(parts) < 2:
        return None

    method = parts[0]
    path = parts[1]

    headers = {}
    for line in lines[1:]:
        if ": " in line:
            k, v = line.split(": ", 1)
            headers[k.lower()] = v

    content_length = int(headers.get("content-length", 0))
    while len(body_part) < content_length:
        try:
            chunk = client.recv(4096)
        except:
            break
        if not chunk:
            break
        body_part += chunk

    return method, path, headers, body_part


def url_decode(s: str) -> str:
    result = s.replace("+", " ")
    parts = result.split("%")
    decoded = parts[0]
    for part in parts[1:]:
        try:
            decoded += chr(int(part[:2], 16)) + part[2:]
        except (ValueError, IndexError):
            decoded += "%" + part
    return decoded


# ──────────────────────────────────────────────
# Wi-Fi — station mode with AP fallback
# ──────────────────────────────────────────────
def start_station() -> network.WLAN:
    """Try connecting to an existing Wi-Fi network. Returns WLAN if connected, None if failed."""
    if not STA_SSID:
        return None

    sta = network.WLAN(network.STA_IF)
    sta.active(True)
    sta.connect(STA_SSID, STA_PASSWORD)

    print(f"[sta] Connecting to {STA_SSID}...", end="")
    deadline = time.time() + STA_TIMEOUT
    while not sta.isconnected():
        if time.time() > deadline:
            print(" timeout")
            sta.active(False)
            return None
        time.sleep_ms(500)
        print(".", end="")

    ip = sta.ifconfig()[0]
    print(f" connected")
    print(f"[sta] IP: {ip}")
    return sta


def start_ap() -> network.WLAN:
    """Start Wi-Fi access point as fallback."""
    ap = network.WLAN(network.AP_IF)
    ap.active(True)
    if AP_PASSWORD:
        ap.config(essid=AP_SSID, password=AP_PASSWORD, authmode=network.AUTH_WPA2_PSK)
    else:
        ap.config(essid=AP_SSID, authmode=network.AUTH_OPEN)

    while not ap.active():
        time.sleep_ms(100)

    print(f"[ap] SSID: {AP_SSID}")
    print(f"[ap] IP:   {ap.ifconfig()[0]}")
    return ap


def start_wifi():
    """Try station mode first, fall back to AP."""
    sta = start_station()
    if sta:
        return sta, "station"

    print("[wifi] Station failed, starting AP mode")
    ap = start_ap()
    return ap, "ap"


# ──────────────────────────────────────────────
# Request routing
# ──────────────────────────────────────────────
def handle_request(client, method, path, headers, body):

    # GET / — serve web UI
    if method == "GET" and path == "/":
        html = load_html()
        send_response(client, "200 OK", "text/html", html)

    # GET /status — board info
    elif method == "GET" and path == "/status":
        send_json(client, "200 OK", {
            "board": "Shrike-fi",
            "fpga": "SLG47910",
            "max_size": MAX_BITSTREAM_SIZE,
            "free_mem": gc.mem_free(),
            "stored": len(list_bitstreams()),
        })

    # GET /files — list stored bitstreams
    elif method == "GET" and path == "/files":
        send_json(client, "200 OK", {
            "ok": True,
            "files": list_bitstreams(),
            "last_flashed": get_last_flashed(),
        })

    # POST /upload — save bitstream to flash (no flashing)
    elif method == "POST" and path == "/upload":
        fname = headers.get("x-filename", "bitstream.bin")
        fname = sanitize_filename(fname)

        ok, msg = validate_bitstream(body)
        if not ok:
            send_json(client, "400 Bad Request", {"ok": False, "error": msg})
            return

        fpath = "/" + fname
        try:
            with open(fpath, "wb") as f:
                f.write(body)
            print(f"[upload] Saved {fname} ({len(body)} bytes)")
            send_json(client, "200 OK", {
                "ok": True,
                "message": f"Saved {fname}",
                "name": fname,
                "size": len(body),
            })
        except Exception as e:
            send_json(client, "500 Internal Server Error", {"ok": False, "error": str(e)})

    # POST /flash — upload + flash immediately
    elif method == "POST" and path == "/flash":
        fname = headers.get("x-filename", "bitstream.bin")
        fname = sanitize_filename(fname)

        ok, msg = validate_bitstream(body)
        if not ok:
            send_json(client, "400 Bad Request", {"ok": False, "error": msg})
            return

        fpath = "/" + fname
        try:
            with open(fpath, "wb") as f:
                f.write(body)
            print(f"[flash] Saved {fname} ({len(body)} bytes)")
        except Exception as e:
            send_json(client, "500 Internal Server Error", {"ok": False, "error": f"Save failed: {e}"})
            return

        try:
            shrike.flash(fpath)
            set_last_flashed(fname)
            print(f"[flash] Flashed {fname}")
            send_json(client, "200 OK", {
                "ok": True,
                "message": f"Flashed {fname}",
                "name": fname,
                "size": len(body),
            })
        except Exception as e:
            send_json(client, "500 Internal Server Error", {"ok": False, "error": f"Flash failed: {e}"})

    # POST /flash/<filename> — flash a stored bitstream
    elif method == "POST" and path.startswith("/flash/"):
        fname = url_decode(path[7:])
        fname = sanitize_filename(fname)
        fpath = "/" + fname

        try:
            os.stat(fpath)
        except OSError:
            send_json(client, "404 Not Found", {"ok": False, "error": f"File not found: {fname}"})
            return

        try:
            shrike.flash(fpath)
            set_last_flashed(fname)
            print(f"[flash] Flashed stored {fname}")
            send_json(client, "200 OK", {
                "ok": True,
                "message": f"Flashed {fname}",
                "name": fname,
            })
        except Exception as e:
            send_json(client, "500 Internal Server Error", {"ok": False, "error": f"Flash failed: {e}"})

    # DELETE /files/<filename> — delete a stored bitstream
    elif method == "DELETE" and path.startswith("/files/"):
        fname = url_decode(path[7:])
        fname = sanitize_filename(fname)
        fpath = "/" + fname

        try:
            os.remove(fpath)
            print(f"[delete] Removed {fname}")
            send_json(client, "200 OK", {"ok": True, "message": f"Deleted {fname}"})
        except OSError:
            send_json(client, "404 Not Found", {"ok": False, "error": f"File not found: {fname}"})

    # POST /reset — reset the FPGA
    elif method == "POST" and path == "/reset":
        try:
            shrike.reset()
            print("[reset] FPGA reset")
            send_json(client, "200 OK", {"ok": True, "message": "FPGA reset"})
        except Exception as e:
            send_json(client, "500 Internal Server Error", {"ok": False, "error": f"Reset failed: {e}"})

    else:
        send_response(client, "404 Not Found", "text/plain", "404 Not Found")


# ──────────────────────────────────────────────
# Main server loop
# ──────────────────────────────────────────────
def main():
    # Auto-flash last bitstream on boot
    last = get_last_flashed()
    if last:
        fpath = "/" + last
        try:
            os.stat(fpath)
            print(f"[boot] Auto-flashing {last}...")
            shrike.flash(fpath)
            print(f"[boot] Flashed {last}")
        except OSError:
            print(f"[boot] {last} not found, skipping auto-flash")
        except Exception as e:
            print(f"[boot] Auto-flash failed: {e}")
    else:
        print("[boot] No previous bitstream, skipping auto-flash")

    wlan, mode = start_wifi()
    ip = wlan.ifconfig()[0]

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", WEB_PORT))
    srv.listen(2)
    print(f"[srv] Listening on {ip}:{WEB_PORT} ({mode} mode)")

    while True:
        gc.collect()
        client, addr = srv.accept()
        print(f"[srv] Connection from {addr}")

        try:
            result = parse_request(client)
            if result is None:
                print("[srv] Bad request, skipping")
                client.close()
                continue

            method, path, headers, body = result
            print(f"[srv] {method} {path}")
            handle_request(client, method, path, headers, body)

        except Exception as e:
            print(f"[srv] Error: {e}")
            try:
                send_json(client, "500 Internal Server Error", {"ok": False, "error": str(e)})
            except:
                pass

        finally:
            client.close()


if __name__ == "__main__":
    main()
