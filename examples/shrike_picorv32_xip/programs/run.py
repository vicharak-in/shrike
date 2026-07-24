#!/usr/bin/env python3
"""run.py -- compile a C (or assembly) program and run it on the Shrike-XIP CPU.

The whole edit-compile-run loop in one command:

    ./run.py demo.c              compile demo.c, load it, run it, show output
    ./run.py demo.c --keep       also keep the built .elf/.bin next to the source
    ./run.py blink.c --port /dev/cu.usbmodem1101

Write a normal C program with a main(); print with the two helpers below (the
CPU has no OS -- "output" is bytes stored to the console word at 0xF000, which
the RP2040 relays to USB). End main() however you like; returning traps the CPU
and ends the run.

    #define CONSOLE (*(volatile unsigned int *)0xF000)
    static void print(const char *s){ while(*s) CONSOLE=(unsigned char)*s++; }
    int main(void){ print("hello\r\n"); return 0; }

Requires: a riscv gcc (riscv64-elf-gcc / riscv32-*/ riscv64-*), pyserial, and the
board flashed with the firmware/rp2040 loader (shrike_xip.uf2).
"""
import argparse, glob, os, shutil, struct, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))

def find_gcc():
    for p in ("riscv64-elf-gcc", "riscv32-unknown-elf-gcc",
              "riscv64-unknown-elf-gcc", "riscv-none-elf-gcc"):
        if shutil.which(p):
            return p[:-3]                      # strip "gcc" -> toolchain prefix
    sys.exit("no riscv gcc found (tried riscv64-elf-gcc, riscv32-unknown-elf-gcc, ...)")

def find_port(override):
    if override:
        return override
    ports = sorted(glob.glob("/dev/cu.usbmodem*") + glob.glob("/dev/ttyACM*"))
    if not ports:
        sys.exit("no board found; connect it and flash firmware/rp2040/shrike_xip.uf2")
    return ports[0]

def compile_program(src, rv, keep):
    base = os.path.splitext(os.path.basename(src))[0]
    outdir = HERE if keep else "/tmp"
    elf = os.path.join(outdir, base + ".elf")
    binf = os.path.join(outdir, base + ".bin")
    cmd = [rv + "gcc", "-Os", "-march=rv32i", "-mabi=ilp32",
           "-ffreestanding", "-nostdlib",
           "-o", elf,
           "-Wl,-Bstatic,-T," + os.path.join(HERE, "link.ld") + ",--strip-debug",
           os.path.join(HERE, "crt0.S"), src, "-lgcc"]
    print("compiling:", os.path.basename(src))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr or "compile failed")
    subprocess.run([rv + "objcopy", "-O", "binary", elf, binf], check=True)
    size = os.path.getsize(binf)
    if size > 0xF000:
        sys.exit(f"program is {size} bytes; the 60 KB code region ends at 0xF000")
    print(f"  {size} bytes  (60 KB available)")
    return binf

def run_on_board(binf, port):
    try:
        import serial
    except ImportError:
        sys.exit("pyserial required:  pip3 install pyserial")
    img = open(binf, "rb").read()
    s = serial.Serial(port, 115200, timeout=1)
    time.sleep(0.3); s.read(65536)
    s.write(b"L" + struct.pack("<I", len(img)) + img)     # load
    time.sleep(0.5)
    ack = s.readline().decode("utf-8", "replace").strip()
    if not ack.startswith("#OK"):
        sys.exit(f"load failed: {ack!r}")
    print(f"running on {port}:\n" + "-" * 40)
    s.write(b"R")                                         # release the CPU
    t0 = time.time()
    while time.time() - t0 < 30:
        line = s.readline().decode("utf-8", "replace")
        if not line:
            continue
        sys.stdout.write(line); sys.stdout.flush()
        if line.startswith("#TRAP") or line.startswith("#TIMEOUT"):
            s.close()
            return 0 if "PASS" in line else 1
    s.close()
    return 0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help="C or .S program with a main()/_start")
    ap.add_argument("--port", default=None)
    ap.add_argument("--keep", action="store_true", help="keep the built .elf/.bin")
    a = ap.parse_args()
    binf = compile_program(a.source, find_gcc(), a.keep)
    sys.exit(run_on_board(binf, find_port(a.port)))

if __name__ == "__main__":
    main()
