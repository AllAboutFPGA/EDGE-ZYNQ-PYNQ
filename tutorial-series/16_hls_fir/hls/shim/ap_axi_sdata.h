// Minimal stand-in for Vitis HLS ap_axi_sdata.h (C simulation only).
#ifndef AP_AXI_SDATA_SHIM_H
#define AP_AXI_SDATA_SHIM_H
#include "ap_int.h"
template <int D, int U, int TI, int TD> struct ap_axis {
    ap_int<D> data;
    ap_uint<(D + 7) / 8> keep;
    ap_uint<(D + 7) / 8> strb;
    ap_uint<1> last;
};
#endif
