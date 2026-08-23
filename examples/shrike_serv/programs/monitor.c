// monitor.c -- an interactive `serv>` monitor for the SERV RV32I core.
//
// Runs on the CPU inside the FPGA and talks to a laptop terminal over the
// memory-mapped UART (the RP2040 bridges USB serial <-> the FPGA UART). Reads a
// line, parses a command, runs it, prints the result -- a tiny ROM-monitor for a
// bit-serial CPU.  See COMMANDS.md for what each command does.
//
// Code, data, bss and stack share one 4 KB BRAM, so this is written for size.

#define UART_DATA (*(volatile unsigned *)0x40000010)  // w = TX byte, r = RX byte
#define UART_STAT (*(volatile unsigned *)0x40000014)  // bit0 = RX valid, bit1 = TX busy
#define LEDREG    (*(volatile unsigned *)0x40000018)  // bit0 -> on-board LED
#define CYCLES    (*(volatile unsigned *)0x4000001C)  // free-running cycle counter (24-bit)
#define ST_RXV 1u
#define ST_TXB 2u

#define LMAX 48                                       // longest command line
#define HIST 4                                        // recallable previous lines

// -- UART primitives ---------------------------------------------------------
static int  getc_(void)      { while (!(UART_STAT & ST_RXV)) ; return UART_DATA & 0xFF; }
static void putc_(int c)     { while (UART_STAT & ST_TXB) ; UART_DATA = (unsigned)c; }
static void puts_(const char *s) { while (*s) { if (*s == '\n') putc_('\r'); putc_(*s++); } }

static void put_udec(unsigned v) {
    char b[10]; int i = 0;
    if (!v) { putc_('0'); return; }
    // one divide per digit: `%` as well would cost a second software division
    while (v) { unsigned q = v / 10; b[i++] = '0' + (v - q * 10); v = q; }
    while (i) putc_(b[--i]);
}
static void put_hex(unsigned v) {
    puts_("0x");
    for (int i = 28; i >= 0; i -= 4) putc_("0123456789abcdef"[(v >> i) & 0xF]);
}

// -- division ----------------------------------------------------------------
// gcc calls these for `/` and `%`; ours replace libgcc's 180-byte div.o lump.
unsigned __udivsi3(unsigned a, unsigned b) {
    unsigned q = 0, bit = 1;
    if (!b) return 0xFFFFFFFFu;                       // matches libgcc: x/0 = ~0
    while (b < a && !(b >> 31)) { b <<= 1; bit <<= 1; }
    while (bit) { if (a >= b) { a -= b; q |= bit; } b >>= 1; bit >>= 1; }
    return q;
}
// Its own loop; `a - __udivsi3(a,b)*b` measured 36% slower on `primes`.
unsigned __umodsi3(unsigned a, unsigned b) {
    unsigned bit = 1;
    if (!b) return a;                                 // matches libgcc: x%0 = x
    while (b < a && !(b >> 31)) { b <<= 1; bit <<= 1; }
    while (bit) { if (a >= b) a -= b; b >>= 1; bit >>= 1; }
    return a;
}

// -- command table -----------------------------------------------------------
// Packed nul-separated, in enum order. `help` prints this, so it can't drift.
static const char CMDS[] =
    "help\0echo\0fib\0primes\0calc\0sort\0peek\0poke\0guess\0led\0cycles\0clear\0";
enum { C_HELP, C_ECHO, C_FIB, C_PRIMES, C_CALC, C_SORT,
       C_PEEK, C_POKE, C_GUESS, C_LED, C_CYCLES, C_CLEAR };

// Index of the next word at *p in a packed table, or -1; advances *p past it.
static int lookup(char **p, const char *t) {
    char *s = *p, *w;
    while (*s == ' ') s++;
    w = s;
    while (*s && *s != ' ') s++;
    *p = s;
    for (int i = 0; *t; i++) {
        const char *a = t; char *b = w;
        while (*a && b < s && *a == *b) { a++; b++; }
        if (!*a && b == s) return i;                  // whole name, whole word
        while (*t) t++;                               // step to the next name
        t++;
    }
    return -1;
}

// Unsigned dec/hex at *p, stopping where the number does -- reads `43` of `23+43`.
static unsigned scan_u(char **p, int *ok) {
    char *s = *p;
    unsigned v = 0;
    int any = 0, hex = 0;
    while (*s == ' ') s++;
    if (*s == '0' && (s[1] | 32) == 'x') { s += 2; hex = 1; }
    for (;;) {
        char c = *s;
        unsigned d;
        if (c >= '0' && c <= '9') d = c - '0';
        else if (hex && (c | 32) >= 'a' && (c | 32) <= 'f') d = (c | 32) - 'a' + 10;
        else break;
        v = hex ? (v << 4) + d : v * 10 + d;
        any = 1; s++;
    }
    if ((*s | 32) >= 'a' && (*s | 32) <= 'z') any = 0;
    *p = s;
    *ok = any;
    return v;
}

static int at_end(char *p) { while (*p == ' ') p++; return !*p; }

// -- line input: echo, backspace, and up/down history ------------------------
// The line being typed lives in the ring, so remembering it is just `cur++`.
static char slots[HIST + 1][LMAX];
static int  cur, hvalid;                              // current slot, recallable lines

// Replace what the user has typed with `s`, on screen and in the buffer.
static void redraw(char *buf, int *n, const char *s) {
    while (*n) { puts_("\b \b"); (*n)--; }
    int i = 0;
    while (s[i] && i < LMAX - 1) { putc_(s[i]); buf[i] = s[i]; i++; }
    buf[i] = 0;
    *n = i;
}

static void getline_(char *buf) {
    int n = 0, hp = 0;                                // hp = how far back we are
    for (;;) {
        int c = getc_();
        if (c == 0x1B) {                              // ESC [ A / ESC [ B
            if (getc_() != '[') continue;
            c = getc_();
            if (c == 'A' && hp < hvalid) hp++;
            else if (c == 'B' && hp > 0) hp--;
            else continue;
            int i = cur - hp;
            if (i < 0) i += HIST + 1;
            redraw(buf, &n, hp ? slots[i] : "");
            continue;
        }
        if (c == '\r' || c == '\n') { puts_("\n"); buf[n] = 0; return; }
        if ((c == 0x7F || c == 0x08) && n) { n--; puts_("\b \b"); continue; }
        if (c >= 0x20 && c < 0x7F && n < LMAX - 1) { buf[n++] = (char)c; putc_(c); }
    }
}

// -- compute -----------------------------------------------------------------
static unsigned fib(unsigned n) {
    unsigned a = 0, b = 1;
    while (n--) { unsigned t = a + b; a = b; b = t; }
    return a;
}
static unsigned count_primes(unsigned n) {
    unsigned count = 0;
    for (unsigned k = 2; k < n; k++) {
        int prime = 1;
        for (unsigned d = 2; d * d <= k; d++) if (k % d == 0) { prime = 0; break; }
        if (prime) count++;
    }
    return count;
}
static unsigned factorial(unsigned n) {
    unsigned f = 1;
    for (unsigned i = 2; i <= n; i++) f *= i;
    return f;
}

static unsigned last_cycles;                          // runtime of the last command

static void bad(void) { puts_("? see help\n"); }
static void put_ln(unsigned v) { put_udec(v); puts_("\n"); }

static void cmd_help(void) {
    puts_("cmds:");
    for (const char *s = CMDS; *s; s++) { putc_(' '); puts_(s); while (*s) s++; }
    puts_("\ne.g. calc 6*7 | calc 5! | fib 20 | peek 0 4 | led on\n");
}

// Own buffer: with HIST+1 slots, getline_'s cur-HIST aliases the slot at cur+1.
static void cmd_guess(void) {
    char line[LMAX];
    unsigned secret = (CYCLES % 100u) + 1u;           // entropy from the cycle counter
    puts_("1..100, blank to give up\n");
    for (;;) {
        int ok;
        puts_("? ");
        getline_(line);
        char *p = line;
        unsigned g = scan_u(&p, &ok);
        if (at_end(line)) { puts_("it was "); put_ln(secret); return; }
        if (!ok) { bad(); continue; }
        if (g == secret) { puts_("correct!\n"); return; }
        puts_(g < secret ? "higher\n" : "lower\n");
    }
}

// -- dispatch ----------------------------------------------------------------
// Returns the command index (or -1); main() uses it to stop `cycles` self-timing.
static int run(char *line) {
    char *p = line;
    int ok, o2, cmd = lookup(&p, CMDS);
    unsigned a, b;

    switch (cmd) {
    case C_HELP:  cmd_help(); break;
    case C_ECHO:
        while (*p == ' ') p++;
        puts_(p); puts_("\n");
        break;
    case C_FIB:
    case C_PRIMES:
        a = scan_u(&p, &ok);
        if (!ok) { bad(); break; }
        put_ln(cmd == C_FIB ? fib(a) : count_primes(a));
        break;
    case C_CALC: {
        // `a op b`, with or without spaces; `a !` is factorial and takes no b.
        a = scan_u(&p, &ok);
        while (*p == ' ') p++;
        char c = *p++;
        if (!ok || !c) { bad(); break; }
        if (c == '!') { put_ln(factorial(a)); break; }
        b = scan_u(&p, &o2);
        if (!o2) { bad(); break; }
        if (c == '+') a += b;
        else if (c == '-') a -= b;
        else if (c == '*') a *= b;
        else if (c == '/') { if (!b) { puts_("div by zero\n"); break; } a /= b; }
        else { bad(); break; }
        put_ln(a);
        break;
    }
    case C_SORT: {
        unsigned v[12]; int n = 0;
        while (n < 12) { v[n] = scan_u(&p, &ok); if (!ok) break; n++; }
        if (!n || !at_end(p)) { bad(); break; }
        for (int i = 0; i < n - 1; i++) for (int j = 0; j < n - 1 - i; j++)
            if (v[j] > v[j + 1]) { unsigned t = v[j]; v[j] = v[j + 1]; v[j + 1] = t; }
        for (int i = 0; i < n; i++) { put_udec(v[i]); if (i < n - 1) putc_(' '); }
        puts_("\n");
        break;
    }
    case C_PEEK: {
        // `peek addr` prints one word; `peek addr n` dumps n, 4 per line
        a = scan_u(&p, &ok);
        b = scan_u(&p, &o2);
        if (!ok) { bad(); break; }
        if (!o2) b = 1;
        for (unsigned i = 0; i < b; i++) {
            if (b > 1 && (i & 3) == 0) { put_hex(a + i * 4); puts_(": "); }
            put_hex(*(volatile unsigned *)(a + i * 4));
            if ((i & 3) == 3 || i == b - 1) puts_("\n"); else putc_(' ');
        }
        break;
    }
    case C_POKE:
        a = scan_u(&p, &ok);
        b = scan_u(&p, &o2);
        if (!ok || !o2) { bad(); break; }
        *(volatile unsigned *)a = b;
        puts_("ok\n");
        break;
    case C_GUESS: cmd_guess(); break;
    case C_LED: {
        int s = lookup(&p, "off\0on\0");
        if (s < 0) { bad(); break; }
        LEDREG = (unsigned)s;
        puts_(s ? "led on\n" : "led off\n");
        break;
    }
    case C_CLEAR: puts_("\x1b[2J\x1b[H"); break;
    case C_CYCLES: put_udec(last_cycles); puts_(" cycles\n"); break;
    case -1:
        if (!at_end(line)) bad();                     // blank line: just re-prompt
        break;
    }
    return cmd;
}

int main(void) {
    puts_("\n=== SERV bit-serial RV32I ===\ntype 'help'\n");
    for (;;) {
        char *line = slots[cur];
        puts_("serv> ");
        getline_(line);
        unsigned t0 = CYCLES;
        // `cycles` reports the previous command; mask to the counter's 24 bits
        if (run(line) != C_CYCLES) last_cycles = (CYCLES - t0) & 0xFFFFFFu;
        if (*line) {                                  // keep it; blank lines aren't
            if (++cur > HIST) cur = 0;
            if (hvalid < HIST) hvalid++;
        }
    }
    return 0;
}
