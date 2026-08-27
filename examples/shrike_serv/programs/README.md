# programs — write & run C/asm on the SERV core

The edit-compile-run loop for the `shrike_serv` example. Write a C program,
compile it, and run it on the bit-serial RV32I core — no re-synthesis.

## One-command flow

```bash
./run.py demo.c                 # compile, load onto the board, run, report PASS/FAIL
./run.py demo.c --compile-only  # just build the .bin (no board needed)
./run.py demo.c --keep          # keep the .elf/.bin next to the source
./run.py myprog.c --port /dev/cu.usbmodem1101
./run.py myprog.c --no-flash    # skip re-flashing the bitstream first
./run.py monitor.c --shell      # load a UART program and open its interactive terminal
```

Two program styles run on the same bitstream: a **self-check** that returns
`0`/non-`0` (crt0 reports it on the result latch, read back as PASS/FAIL — see
`demo.c`), or a **UART program** — the `serv>` monitor. For the monitor, the
simplest path is `python3 serv_shell.py` (auto-detects the board, flashes + loads
on first run); `run.py monitor.c --shell` rebuilds the monitor and reopens that
same terminal. See the top-level README's *Interactive Monitor*.

- **Compile** needs a RISC-V GCC (`riscv64-elf-gcc`, `riscv32-unknown-elf-gcc`,
  or similar — auto-detected).
- **Board run** needs `mpremote` (`pip install mpremote`) and assumes the board
  already has `shrike_serv.py` + `shrike_serv.bin` on it (see the top-level
  README's Quick Start).

## Writing a program

Write a normal C program with `int main(void)`:

```c
int main(void) {
    // ... compute something ...
    return 0;            // 0 = PASS, anything else = FAIL
}
```

The core has no OS and only a 2-bit result latch for output, so `crt0.S` turns
`main()`'s return value into the PASS/FAIL result the board reads back
(`main()==0` → PASS). Structure your program so a wrong answer changes the return
value — that is how a self-check reports failure. See `demo.c` for a worked
example (recursion, an in-place sort, a prime sieve, and multiply/divide).

## The 4 KB budget

Code + globals + stack share one flat **4 KB** memory (the 8 BRAM slices). The
linker (`link.ld`) will error if the static image alone overflows 4 KB; leave
headroom for the stack, which grows down from `0x1000`. `demo.c` uses ~730 bytes.

RV32I has no hardware multiply/divide, so GCC lowers `*`, `/`, `%` to libgcc
routines (`__mulsi3`, `__udivsi3`, …). These are linked automatically (`-lgcc`)
and run correctly — but each is a multi-cycle software loop, and SERV is
bit-serial, so heavy arithmetic is slow. That is expected.

## Files

| File | Purpose |
|---|---|
| `serv_shell.py` | Robust, turnkey interactive `serv>` terminal (auto-detect port, auto-provision, auto-reconnect) — the way to run the monitor |
| `run.py` | Compile a C/asm program and (optionally) load + run it on the board |
| `crt0.S` | C runtime: set stack, zero `.bss`, call `main()`, report result, halt |
| `link.ld` | 4 KB memory map; `_start` first at address 0 |
| `nolibc.c` | `memcpy`/`memset`/`memmove`/`memcmp` GCC may emit under `-nostdlib` |
| `demo.c` | Self-checking C demo (recursion, sort, sieve, mul/div) |
| `monitor.c` | Interactive `serv>` UART monitor (run with `--shell`; see COMMANDS.md) |
