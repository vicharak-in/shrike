#!/usr/bin/env python3
"""run.py -- compile a C (or assembly) program and run it on the SERV core.

The whole edit-compile-run loop in one command:

    ./run.py demo.c                 compile, load onto the board, run, report PASS/FAIL
    ./run.py demo.c --keep          also keep the built .elf/.bin next to the source
    ./run.py demo.c --port /dev/cu.usbmodem1101
    ./run.py demo.c --compile-only  just build the .bin (no board needed)
    ./run.py monitor.c --shell      load a UART program and open its interactive terminal

Two program styles run on the same bitstream:
  * a self-check that returns 0/non-0 -- crt0 reports it on the result latch,
    which run.py reads back as PASS/FAIL (see demo.c);
  * a UART program (see monitor.c) -- run with --shell to drop into an
    interactive terminal bridged over the FPGA UART (Ctrl-] to exit).

The core has no OS; code + globals + stack must fit in 4 KB. Board path uses
mpremote and assumes the board already has shrike_serv.bin + the firmware on it
(see the top-level README). Requires a riscv gcc (riscv64-elf-gcc / riscv32-*).
"""
import argparse, glob, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MONITOR_FW = os.path.join(HERE, "..", "firmware", "micropython", "shrike_serv_monitor.py")
MEM_BYTES = 4096

def find_gcc():
    for p in ("riscv64-elf-gcc", "riscv32-unknown-elf-gcc",
              "riscv64-unknown-elf-gcc", "riscv-none-elf-gcc"):
        if shutil.which(p):
            return p[:-3]                       # strip "gcc" -> toolchain prefix
    sys.exit("no riscv gcc found (tried riscv64-elf-gcc, riscv32-unknown-elf-gcc, ...)")

def compile_program(src, rv, keep):
    base = os.path.splitext(os.path.basename(src))[0]
    outdir = HERE if keep else "/tmp"
    elf = os.path.join(outdir, base + ".elf")
    binf = os.path.join(outdir, base + ".bin")
    cmd = [rv + "gcc", "-Os", "-march=rv32i", "-mabi=ilp32",
           "-ffreestanding", "-nostdlib",
           "-o", elf,
           "-Wl,-Bstatic,-T," + os.path.join(HERE, "link.ld") + ",--strip-debug",
           os.path.join(HERE, "crt0.S"), os.path.join(HERE, "nolibc.c"), src, "-lgcc"]
    print("compiling:", os.path.basename(src))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr or "compile failed")
    subprocess.run([rv + "objcopy", "-O", "binary", elf, binf], check=True)
    size = os.path.getsize(binf)
    if size > MEM_BYTES:
        sys.exit(f"program is {size} bytes; only {MEM_BYTES} bytes (4 KB) available")
    print(f"  {size} bytes  ({MEM_BYTES} bytes / 4 KB available)")
    return binf

def find_port(override):
    if override:
        return override
    ports = sorted(glob.glob("/dev/cu.usbmodem*") + glob.glob("/dev/ttyACM*"))
    return ports[0] if ports else None

def run_on_board(binf, port, do_flash):
    if not shutil.which("mpremote"):
        sys.exit("mpremote required for the board run:  pip install mpremote\n"
                 "(or use --compile-only and copy the .bin yourself)")
    if not port:
        sys.exit("no board found; connect the Shrike-Lite (or pass --port), or use --compile-only")
    dst = "prog.bin"
    subprocess.run(["mpremote", "connect", port, "cp", binf, ":" + dst], check=True)
    flash = "s.flash_bitstream(); " if do_flash else ""
    snippet = ("import shrike_serv as s; " + flash +
               "r = s.run_test('%s'); "
               "print('RESULT', r, {3:'PASS',1:'FAIL',0:'DEAD'}.get(r, '?'))" % dst)
    print(f"running on {port}:\n" + "-" * 40)
    r = subprocess.run(["mpremote", "connect", port, "exec", snippet])
    return r.returncode

def run_shell(binf, port):
    """Load a UART program and hand off to the interactive bridge firmware."""
    if not shutil.which("mpremote"):
        sys.exit("mpremote required:  uv tool install mpremote  (or pip install mpremote)")
    if not port:
        sys.exit("no board found; connect the Shrike-Lite or pass --port")
    subprocess.run(["mpremote", "connect", port, "cp", binf, ":monitor.bin"], check=True)
    print(f"starting interactive session on {port} (Ctrl-] to exit)\n" + "-" * 40)
    os.execvp("mpremote", ["mpremote", "connect", port, "run", MONITOR_FW])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", help="C or .S program with a main()")
    ap.add_argument("--port", default=None)
    ap.add_argument("--keep", action="store_true", help="keep the built .elf/.bin")
    ap.add_argument("--compile-only", action="store_true", help="build the .bin, skip the board")
    ap.add_argument("--no-flash", action="store_true", help="don't re-flash the bitstream first")
    ap.add_argument("--shell", action="store_true",
                    help="load a UART program and open its interactive terminal")
    a = ap.parse_args()
    binf = compile_program(a.source, find_gcc(), a.keep or a.compile_only)
    if a.compile_only:
        print("built:", binf)
        return
    if a.shell:
        run_shell(binf, find_port(a.port))
        return
    sys.exit(run_on_board(binf, find_port(a.port), not a.no_flash))

if __name__ == "__main__":
    main()
