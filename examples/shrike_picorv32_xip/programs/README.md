# Running your own programs on the XIP CPU

A full RV32I RISC-V CPU runs inside the FPGA and executes code from 64 KB of
RAM. Write a C program, run one command, watch it run on real hardware.

## One-time setup
1. Flash the loader firmware onto the RP2040 (once): build
   `../firmware/rp2040` and drag the `.uf2` onto the board in BOOTSEL.
   It configures the FPGA and hosts the RAM at boot.
2. Have a RISC-V gcc on PATH (`riscv64-elf-gcc` or similar) and pyserial
   (`pip3 install pyserial`).

## The loop
```
./run.py demo.c        # compile, load, run, show output
```
Edit `demo.c` (or write your own `.c`), run it again. That's the whole cycle.

## Writing a program
No operating system -- "output" is bytes you store to the console word at
`0xF000`, which the board relays to USB. Report success by storing `123456789`
to `0xF004`.

```c
#define CONSOLE (*(volatile unsigned int *)0xF000)
#define STATUS  (*(volatile unsigned int *)0xF004)
static void print(const char *s){ while(*s) CONSOLE = (unsigned char)*s++; }

int main(void) {
    print("hello\r\n");
    STATUS = 123456789;    // optional: marks the run PASS
    return 0;              // returning ends the run
}
```

Full ISA is available: recursion, arrays, structs, `*` and `/` (software
routines), etc. -- see `demo.c` for a worked example.

## The 64 KB address space

The CPU has one flat 64 KB of RAM (the RP2040 emulates it). The layout:

| Range | Size | What lives here |
|-------|------|-----------------|
| `0x0000`-`0xEFFF` | 60 KB | your program: code **and all data** (globals, arrays, strings) |
| `0xF000` | 1 word | **CONSOLE** — store a byte to print it |
| `0xF004` | 1 word | **STATUS** — store `123456789` to mark the run passed |
| `0xF008`-`0xFFFF` | ~4 KB | **stack** — grows down from `0x10000` |

Using the RAM is just ordinary C — you don't manage it by hand:

- **Globals and static arrays** land in RAM automatically, anywhere in the 60 KB
  code+data region. `static unsigned char buf[40000];` just works.
- **Local variables** live on the stack (~4 KB). Deep recursion or large local
  arrays can overflow it into the IO words — put big buffers in globals instead.
- **There is no heap / `malloc`** (no operating system). Use globals or locals.

`demo.c` shows both: a 512-byte `sieve[]` and a 32-element `items[]` array (globals
in RAM) alongside recursive `fib()` (the stack). `run.py` prints how many bytes
your program uses out of the 60 KB after compiling.

**Speed:** every instruction fetch and data access is a SPI transaction, so the
CPU is slow -- tens of thousands of memory accesses take a few seconds. The
loader caps a run at 20 s; a program signals it is done by writing the status
word (see above).

## Files

- `run.py`   -- compile + load + run + console, in one command
- `demo.c`   -- worked example (recursion, sieve, sort, div/mod)
- `crt0.S`   -- sets the stack, zeros .bss, calls main (you rarely touch this)
- `link.ld`  -- the memory map above (code+data below 0xF000, stack from 0x10000)
