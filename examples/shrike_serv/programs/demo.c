// demo.c -- self-checking C demo for the SERV RV32I core on Shrike.
//
// Exercises a real compiled-C workload inside the 4 KB budget: recursion,
// an array + in-place sort, a prime sieve, and 32-bit multiply/divide (which
// RV32I lacks in hardware, so gcc lowers them to libgcc __mulsi3/__divsi3 --
// proving the toolchain path end to end). main() returns 0 only if every
// computed value matches its known-good answer; crt0 turns that into the
// PASS/FAIL result the board reads back. Edit freely and rerun ./run.py demo.c.

static unsigned fib(unsigned n) {          // recursion + the call stack
    return n < 2 ? n : fib(n - 1) + fib(n - 2);
}

static void bsort(int *a, int n) {         // in-place data memory writes
    for (int i = 0; i < n - 1; i++)
        for (int j = 0; j < n - 1 - i; j++)
            if (a[j] > a[j + 1]) {
                int t = a[j]; a[j] = a[j + 1]; a[j + 1] = t;
            }
}

static int count_primes(int limit) {       // sieve in a stack array
    unsigned char sieve[64];
    for (int i = 0; i < limit; i++) sieve[i] = 1;
    sieve[0] = sieve[1] = 0;
    for (int p = 2; p * p < limit; p++)
        if (sieve[p])
            for (int k = p * p; k < limit; k += p) sieve[k] = 0;
    int c = 0;
    for (int i = 2; i < limit; i++) c += sieve[i];
    return c;
}

int main(void) {
    // 1) recursion
    if (fib(10) != 55) return 1;

    // 2) array sort
    int a[8] = { 5, 2, 8, 1, 7, 3, 6, 4 };   // a permutation of 1..8
    bsort(a, 8);
    for (int i = 0; i < 8; i++)
        if (a[i] != i + 1) return 2;

    // 3) prime sieve up to 50 -> 15 primes
    if (count_primes(50) != 15) return 3;

    // 4) mul/div via libgcc (no hardware M extension)
    unsigned x = 12345u * 6789u;           // __mulsi3
    if (x != 83810205u) return 4;
    if (x / 6789u != 12345u) return 5;     // __udivsi3
    if (x % 1000u != 205u) return 6;       // __umodsi3

    return 0;                              // all checks passed
}
