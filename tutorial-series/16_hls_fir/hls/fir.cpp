// 31-tap FIR filter: one 16-bit sample in, one filtered sample out, every clock cycle.
// Each call filters one DMA transfer (up to TLAST), starting from silence, so the result
// equals numpy.convolve(x, COEF)[:len(x)] scaled by 2^-15 with rounding and saturation.
#include "fir.h"

static short saturate16(long long v) {
    if (v > 32767) return 32767;
    if (v < -32768) return -32768;
    return (short)v;
}

void fir(hls::stream<axis_t> &x_in, hls::stream<axis_t> &y_out) {
#pragma HLS INTERFACE mode=axis port=x_in
#pragma HLS INTERFACE mode=axis port=y_out
#pragma HLS INTERFACE mode=s_axilite port=return

    short taps[N_TAPS];
#pragma HLS ARRAY_PARTITION variable=taps type=complete
clear:
    for (int i = 0; i < N_TAPS; i++) {
#pragma HLS UNROLL
        taps[i] = 0;
    }

    bool last = false;
samples:
    while (!last) {
#pragma HLS PIPELINE II=1
        axis_t s = x_in.read();
    shift:
        for (int i = N_TAPS - 1; i > 0; i--) {
#pragma HLS UNROLL
            taps[i] = taps[i - 1];
        }
        taps[0] = (short)(s.data & 0xFFFF);

        long long acc = 0;
    mac:
        for (int i = 0; i < N_TAPS; i++) {
#pragma HLS UNROLL
            acc += (long long)taps[i] * COEF[i];
        }

        axis_t o = s;                                        // keeps TKEEP, TSTRB and TLAST
        o.data = (int)saturate16((acc + (1 << 14)) >> 15);   // Q15 -> integer, rounded
        y_out.write(o);
        last = s.last;
    }
}
