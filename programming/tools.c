#include "tools.h"

volatile unsigned long long int * const I_OUTPUT = (long long int*)(0xFFFFFFFFFFFFFFF0);
volatile char * const OUTPUT = (char*)(0xFFFFFFFFFFFFFFFC);

void prints(char *c) {
    long long int i = 0;
    while (c[i])
        *OUTPUT = c[i++];
}

void printx(int n) {
    for (int i = 15; i >= 0; i--) {
        char c = (n & (0xF << (i << 2))) >> (i << 2);
        if (c > 9) {
            *OUTPUT = 'A' - 0xA + c;
        } else {
            *OUTPUT = '0' + c;
        }
    }
}
/*
int negate(int n) {
    return ~n + 1;
}

int mult32(int a, int b) {
    if (a == 0 | b == 0) {
        return 0;
    }

    long long int accumulator = 0;

    for (int i = 0; i < 32; i++) {
        if (b & (1 << i)) {
            accumulator += a << i;
        }
    }
    return accumulator;
}

int div32(int n, int d) {
    if (d == 0 || n == 0) return 0;
    if (n < 0) return negate(div32(negate(n), d));
    if (d < 0) return negate(div32(n, negate(d)));
    int q = 0;
    int r = 0;

    for (int i = 31; i >= 0; i--) {
        r = r << 1;
        r = (r & ~1) | ((n >> i) & 1);
        if (r >= d) {
            r -= d;
            q |= 1 << i;
        }
    }
    return q;
}

int mod32(int n, int d) {
    if (d == 0) return 0;
    int q = 0;
    int r = 0;

    for (int i = 31; i >= 0; i--) {
        r = r << 1;
        r = (r & -2) | ((n >> i) & 1);
        if (r >= d) {
            r -= d;
            q |= 1 << i;
        }
    }
    return r;
}
*/