"""Read a Zynq-7000 BOOT.BIN (UG585 chapter 6 / UG1283 boot image format) and pull out its partitions."""
import struct
import sys


def parse(blob):
    w = lambda off: struct.unpack_from("<I", blob, off)[0]
    if blob[0x24:0x28] != b"XNLX":
        raise ValueError("not a Zynq boot image")
    info = {
        "fsbl_offset": w(0x30), "fsbl_length": w(0x34), "fsbl_load": w(0x38),
        "fsbl_exec": w(0x3C), "total_length": w(0x40),
        "img_hdr_table": w(0x98), "part_hdr_table": w(0x9C),
    }
    parts = []
    off = info["part_hdr_table"]
    while True:
        h = struct.unpack_from("<16I", blob, off)
        if all(x == 0 for x in h[:15]):
            break
        enc_len, unenc_len, total_len, load, exec_, data_off, attr, sec_cnt, csum_off, img_hdr_off = h[:10]
        if total_len == 0xFFFFFFFF or data_off == 0xFFFFFFFF:
            break
        dest = (attr >> 4) & 0xF
        p = {
            "length": unenc_len * 4, "total": total_len * 4, "load": load, "exec": exec_,
            "offset": data_off * 4, "attr": attr, "dest": {1: "PS", 2: "PL"}.get(dest, str(dest)),
            "img_hdr": img_hdr_off * 4,
        }
        # partition name from its image header (name is stored as big-endian words)
        ih = p["img_hdr"]
        if ih:
            name_words = []
            o = ih + 16
            while True:
                (x,) = struct.unpack_from(">I", blob, o)
                if x == 0:
                    break
                name_words.append(struct.pack("<I", x))
                o += 4
                if len(name_words) > 64:
                    break
            p["name"] = b"".join(name_words).split(b"\0")[0].decode(errors="replace")
        p["data"] = blob[p["offset"]:p["offset"] + p["length"]]
        parts.append(p)
        off += 64
    return info, parts


if __name__ == "__main__":
    blob = open(sys.argv[1], "rb").read()
    info, parts = parse(blob)
    print({k: hex(v) for k, v in info.items()})
    for i, p in enumerate(parts):
        print(i, p.get("name"), p["dest"], "len=%d load=0x%x exec=0x%x off=0x%x attr=0x%x" % (
            p["length"], p["load"], p["exec"], p["offset"], p["attr"]))
        if len(sys.argv) > 2:
            open("%s/part%d_%s.bin" % (sys.argv[2], i, (p.get("name") or "x").replace("/", "_")), "wb").write(p["data"])
