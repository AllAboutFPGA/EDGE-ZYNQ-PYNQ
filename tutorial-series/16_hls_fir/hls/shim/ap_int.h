// Minimal stand-in for Vitis HLS ap_int.h, for C simulation without the Xilinx tools.
#ifndef AP_INT_SHIM_H
#define AP_INT_SHIM_H
#include <cstdint>
template <int W> struct ap_int {
    int64_t v = 0;
    ap_int() {}
    ap_int(long long x) { set(x); }
    void set(long long x) {
        uint64_t m = (W >= 64) ? ~0ULL : ((1ULL << W) - 1);
        uint64_t u = (uint64_t)x & m;
        if (W < 64 && (u >> (W - 1)) & 1) u |= ~m;   // sign-extend
        v = (int64_t)u;
    }
    ap_int &operator=(long long x) { set(x); return *this; }
    operator long long() const { return v; }
};
template <int W> struct ap_uint {
    uint64_t v = 0;
    ap_uint() {}
    ap_uint(long long x) { set(x); }
    void set(long long x) { v = (uint64_t)x & ((W >= 64) ? ~0ULL : ((1ULL << W) - 1)); }
    ap_uint &operator=(long long x) { set(x); return *this; }
    operator unsigned long long() const { return v; }
};
#endif
