# `serv>` monitor — command reference

Once the board is up and you're at the `serv>` prompt (see the README's Quick
Start), these are the commands the CPU understands. Type a command and press
Enter; the bit-serial core computes and prints the answer back. Editing:
BACKSPACE erases, UP/DOWN recall the last four commands, ENTER submits. Numbers
may be decimal (`42`) or hex (`0x2a`).

> SERV runs ~one bit per clock at 25 MHz, so heavy commands (`primes 1000`,
> `fib 40`) visibly take a moment — that pause *is* the bit-serial CPU working.

| Command | What it does | Example | Reply |
|---|---|---|---|
| `help` | List the commands and some examples | `help` | the command list |
| `echo <text>` | Print the rest of the line back — proves RX+TX both work | `echo hi there` | `hi there` |
| `fib <n>` | The nth Fibonacci number (iterative, 32-bit) | `fib 20` | `6765` |
| `primes <n>` | Count the prime numbers below `n` | `primes 100` | `25` |
| `calc <a><op><b>` | One arithmetic op: `+ - * /`, spaces optional | `calc 6*7` | `42` |
| `calc <n>!` | `n!` as a 32-bit value (wraps past `12!`) | `calc 10!` | `3628800` |
| `sort <n> <n> …` | Sort up to 12 numbers ascending | `sort 5 2 8 1 7` | `1 2 5 7 8` |
| `peek <addr> [n]` | Read a word — or hex-dump `n` words, 4 per row | `peek 0x0 8` | rows of 4 words |
| `poke <addr> <val>` | Write a 32-bit word into memory | `poke 0x800 123` | `ok` |
| `guess` | Number-guessing game, 1..100, replies higher/lower | `guess` | interactive |
| `led on` / `led off` | Turn the on-board **FPGA LED** on or off | `led on` | `led on` (LED lights) |
| `cycles` | Runtime of the *previous* command (24-bit, laps every 0.67 s) | `cycles` | e.g. `1840320 cycles` |
| `clear` | Clear the terminal | `clear` | (screen clears) |

Anything unrecognized prints `? see help`.

## Notes on the interesting ones

- **`calc` and multiply/divide.** Spaces are optional — `calc 23+43` and
  `calc 23 + 43` are the same — but a number glued to a letter (`12x`) is still
  an error. RV32I has no hardware multiply or divide, so `*`, `/` and `%` are
  software routines; they're correct but multi-cycle, another place you feel the
  bit-serial speed. `calc <n>!` is the factorial and takes no right-hand operand.

- **`peek` / `poke` — a real memory monitor.** The address space is the CPU's own
  4 KB RAM (`0x0`–`0xFFF`), where the monitor's own code and data live. `peek 0x0`
  returns `0x00001117` — the `auipc sp,0x1` that `crt0.S` starts with, read out of
  the running program. `peek 0x0 8` dumps the first eight instructions. `poke` into
  the low addresses will corrupt the monitor (that's the fun of a bare-metal
  monitor) — poke high addresses like `0x800` to experiment safely.

- **`led`.** Drives FPGA GPIO16, the on-board FPGA LED (not the MCU LED). This is
  the CPU reaching out and changing the physical world through a memory write.

- **History.** UP/DOWN walk the last four commands and a recalled line can be
  edited before you run it. The CPU does this itself, so it needs a terminal wired
  straight to the FPGA UART — `shrike_serv_monitor.py` passes arrow keys through.
  `serv_shell.py` reads whole lines instead, so there the host handles history and
  the arrow keys never reach the CPU. Either way you get history.

## Running it

From this example's directory (`examples/shrike_serv`):

```bash
python3 programs/serv_shell.py
```

Gives you the `serv>` prompt. Exit with `quit`, Ctrl-D, or Ctrl-C.

## Writing your own commands

The monitor is just a C program (`programs/monitor.c`). Add the name to the `CMDS`
table and a `case` to `run()` — `help` prints whatever is in the table, so it stays
in step by itself. Rebuild and reload with `programs/run.py monitor.c --shell`
(which reopens the terminal), and your command is live — no re-synthesis, no new
bitstream.

Code, data, bss *and* stack share one 4 KB BRAM. `run.py` prints the size and
refuses to link past 4096, but that only covers the first three — the monitor is
3369 bytes with 472 left below the stack, of which the deepest call chain uses
208. Add something substantial and it's worth checking both numbers, not just the
one the linker enforces.
