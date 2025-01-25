volatile long long int * const OUTPUT = (void*)(0xFFFFFFFFFFFFFFFC);

long int __muldi3(long int a, long int b) {
    if (a == 0 | b == 0) {
        return 0;
    }

    int accumulator = 0;

    for (int i = 0; i < 63; i++) {
        if (b & (1 << i)) {
            accumulator += a << i;
        }
    }
    return accumulator;
}

long int __divdi3(long int n, long int d) {
    if (d == 0 || n == 0) return 0;
    if (n < 0) return -((-n)/d);
    if (d < 0) return -(n/(-d));
    int q = 0;
    int r = 0;

    for (int i = 63; i >= 0; i--) {
        r = r << 1;
        r = (r & ~1) | ((n >> i) & 1);
        if (r >= d) {
            r -= d;
            q |= 1 << i;
        }
    }
    return q;
}

#define MAX_ITER 12
#define SCALE 256

// Function to determine if a point is in the Mandelbrot set
int mandelbrot(int x0, int y0) {
    return 1;
}

void main() {
    const char* chars = " .:-=+*\\?\%S#@";
    const int w = 64;
    const int h = 24;

    const int x_i = -2*SCALE;
    const int x_f = SCALE;
    const int dx = 3*SCALE/w + 1;

    const int y_i = -3*SCALE/2;
    const int y_f = 3*SCALE/2;
    const int dy = 3*SCALE/h + 1;

    prints("START");
    *OUTPUT = '\n';

    for (int y = y_i; y < y_f; y+=dy) {
        for (int x = x_i; x < x_f; x+=dx) {
            *OUTPUT = '\n';
            //*OUTPUT = chars[mandelbrot(x, y)];
        }
    }
}