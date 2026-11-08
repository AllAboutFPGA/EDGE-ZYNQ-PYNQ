// 31-tap low-pass FIR filter for Vitis HLS (PYNQ tutorial series, episode 16)
// Invent Logics / allaboutfpga.com
#ifndef FIR_H
#define FIR_H
#include <ap_axi_sdata.h>
#include <hls_stream.h>

// One stream word: a 16-bit signed sample in bits 15:0 of a 32-bit word, TLAST on the last one.
typedef ap_axis<32, 0, 0, 0> axis_t;

const int N_TAPS = 31;

// Low-pass, cutoff 0.08 x sample rate, Hamming window, scaled so they add up to 32768 (1.0 in Q15).
const short COEF[N_TAPS] = {
      53,   46,   24,  -36, -150, -306, -451, -492, -321,  148,  941, 1993, 3154, 4214, 4957,
    5220,
    4957, 4214, 3154, 1993,  941,  148, -321, -492, -451, -306, -150,  -36,   24,   46,   53};

void fir(hls::stream<axis_t> &x_in, hls::stream<axis_t> &y_out);
#endif
