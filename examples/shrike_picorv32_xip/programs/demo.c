// Compiled-C demo for the XIP core: proves the machine runs real programs out
// of the 64 KB external RAM, not just hand-written instruction vectors.
//
// Exercises what the conformance suite does not: compiler-generated code, a
// stack with nested calls and recursion, arrays and structs living in RAM,
// multiply/divide via libgcc, string formatting, and self-checking results.
//
// Console = byte stored to 0xF000, status = 123456789 stored to 0xF004.

#define CONSOLE (*(volatile unsigned int *)0xF000)
#define STATUS  (*(volatile unsigned int *)0xF004)
#define PASS_VALUE 123456789u

static void putch(char c)          { CONSOLE = (unsigned char)c; }
static void print(const char *s)   { while (*s) putch(*s++); }

static void print_uint(unsigned int v)
{
	char buf[12];
	int i = 0;
	if (!v) { putch('0'); return; }
	while (v) { buf[i++] = '0' + (v % 10); v /= 10; }   // needs libgcc div/mod
	while (i) putch(buf[--i]);
}

// ---- recursion: exercises the stack and the link register ----
static unsigned int fib(unsigned int n)
{
	return (n < 2) ? n : fib(n - 1) + fib(n - 2);
}

// ---- array work in external RAM: sieve of Eratosthenes ----
#define SIEVE_N 512
static unsigned char sieve[SIEVE_N];

static unsigned int count_primes(void)
{
	unsigned int i, j, n = 0;
	for (i = 0; i < SIEVE_N; i++) sieve[i] = 1;
	sieve[0] = sieve[1] = 0;
	for (i = 2; i * i < SIEVE_N; i++)
		if (sieve[i])
			for (j = i * i; j < SIEVE_N; j += i) sieve[j] = 0;
	for (i = 0; i < SIEVE_N; i++) n += sieve[i];
	return n;
}

// ---- structs, pointers and sorting ----
struct item { unsigned short key; unsigned short tag; };
static struct item items[32];

static void sort_items(struct item *a, int n)
{
	for (int i = 1; i < n; i++) {          // insertion sort
		struct item t = a[i];
		int j = i - 1;
		while (j >= 0 && a[j].key > t.key) { a[j + 1] = a[j]; j--; }
		a[j + 1] = t;
	}
}

// ---- byte/half/word memory traffic through the SPI bus ----
static unsigned int checksum(void)
{
	unsigned int i, s = 0;
	for (i = 0; i < 32; i++) s += items[i].key * (i + 1);
	return s;
}

int main(void)
{
	unsigned int ok = 1;

	print("XIP compiled-C demo\r\n");

	// 1. recursion / stack
	unsigned int f = fib(18);                       // 2584
	print("fib(18)      = "); print_uint(f);
	if (f != 2584) { print("  WRONG"); ok = 0; }
	print("\r\n");

	// 2. arrays + nested loops in external RAM
	unsigned int p = count_primes();                // 97 primes below 512
	print("primes<512   = "); print_uint(p);
	if (p != 97) { print("  WRONG"); ok = 0; }
	print("\r\n");

	// 3. structs, pointers, sorting, sub-word access
	for (int i = 0; i < 32; i++) {
		items[i].key = (unsigned short)((i * 37 + 11) & 0x1FF);
		items[i].tag = (unsigned short)i;
	}
	sort_items(items, 32);
	unsigned int sorted = 1;
	for (int i = 1; i < 32; i++) if (items[i - 1].key > items[i].key) sorted = 0;
	print("sorted       = "); print(sorted ? "yes" : "NO");
	if (!sorted) ok = 0;
	print("\r\n");

	unsigned int c = checksum();
	print("checksum     = "); print_uint(c); print("\r\n");

	// 4. multiply / divide (libgcc software routines)
	unsigned int q = c / 7, r = c % 7;
	print("chk/7, chk%7 = "); print_uint(q); print(", "); print_uint(r);
	if (q * 7 + r != c) { print("  WRONG"); ok = 0; }
	print("\r\n");

	print(ok ? "ALL OK\r\n" : "FAILED\r\n");
	if (ok) STATUS = PASS_VALUE;

	__asm__ volatile ("ebreak");
	while (1) ;
}
