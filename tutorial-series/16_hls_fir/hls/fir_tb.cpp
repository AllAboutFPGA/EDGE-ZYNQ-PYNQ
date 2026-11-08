// C testbench for fir(): compares the hardware function with a plain reference filter.
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <vector>
#include "fir.h"

static const double PI = 3.14159265358979323846;   // M_PI is missing on some Windows compilers

static short reference(const std::vector<short> &x, int n) {
    long long acc = 0;
    for (int k = 0; k < N_TAPS; k++)
        if (n - k >= 0) acc += (long long)x[n - k] * COEF[k];
    long long y = (acc + (1 << 14)) >> 15;
    if (y > 32767) y = 32767;
    if (y < -32768) y = -32768;
    return (short)y;
}

static int run_packet(const std::vector<short> &x) {
    hls::stream<axis_t> in, out;
    for (size_t n = 0; n < x.size(); n++) {
        axis_t w;
        w.data = (int)x[n];          // sign-extended, as the Python side sends it
        w.keep = -1;
        w.strb = -1;
        w.last = (n == x.size() - 1);
        in.write(w);
    }
    fir(in, out);
    int errors = 0;
    for (size_t n = 0; n < x.size(); n++) {
        axis_t w = out.read();
        short got = (short)(w.data & 0xFFFF);
        short want = reference(x, (int)n);
        bool last_ok = (bool)w.last == (n == x.size() - 1);
        if (got != want || !last_ok) {
            if (errors < 5) printf("sample %zu: got %d want %d last %d\n", n, got, want, (int)w.last);
            errors++;
        }
    }
    if (!out.empty()) { printf("extra output words\n"); errors++; }
    return errors;
}

int main() {
    int errors = 0;
    // 1: two sines (a slow one to keep, a fast one to remove) plus noise, near full scale
    std::vector<short> x(4096);
    srand(1);
    for (size_t n = 0; n < x.size(); n++) {
        double v = 12000 * sin(2 * PI * 0.01 * n) + 12000 * sin(2 * PI * 0.3 * n)
                 + (rand() % 2001 - 1000);
        x[n] = (short)v;
    }
    errors += run_packet(x);
    // 2: full-scale steps, to exercise saturation
    std::vector<short> s(300);
    for (size_t n = 0; n < s.size(); n++) s[n] = (n / 40) % 2 ? 32767 : -32768;
    errors += run_packet(s);
    // 3: a single sample (impulse) gives the first coefficient, rounded
    errors += run_packet(std::vector<short>(1, 32767));
    // 4: a second packet starts from silence again
    errors += run_packet(x);

    // the slow sine passes, the fast one is removed: check the output power of a fast-only signal
    std::vector<short> fast(2000);
    for (size_t n = 0; n < fast.size(); n++) fast[n] = (short)(12000 * sin(2 * PI * 0.3 * n));
    hls::stream<axis_t> in, out;
    for (size_t n = 0; n < fast.size(); n++) {
        axis_t w; w.data = (int)fast[n]; w.keep = -1; w.strb = -1;
        w.last = (n == fast.size() - 1); in.write(w);
    }
    fir(in, out);
    double peak = 0;
    for (size_t n = 0; n < fast.size(); n++) {
        double v = (short)(out.read().data & 0xFFFF);
        if (n > N_TAPS && fabs(v) > peak) peak = fabs(v);
    }
    printf("fast sine 12000 -> peak %.0f after the filter\n", peak);
    if (peak > 120) { printf("stop band too weak\n"); errors++; }

    if (errors == 0) printf("TEST PASSED\n");
    else printf("TEST FAILED: %d errors\n", errors);
    return errors ? 1 : 0;
}
