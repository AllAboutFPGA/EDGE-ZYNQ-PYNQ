// Minimal stand-in for Vitis HLS hls_stream.h (C simulation only).
#ifndef HLS_STREAM_SHIM_H
#define HLS_STREAM_SHIM_H
#include <deque>
#include <stdexcept>
namespace hls {
template <typename T> class stream {
    std::deque<T> q;
public:
    void write(const T &v) { q.push_back(v); }
    T read() {
        if (q.empty()) throw std::runtime_error("read from an empty stream");
        T v = q.front(); q.pop_front(); return v;
    }
    bool empty() const { return q.empty(); }
    size_t size() const { return q.size(); }
};
}
#endif
