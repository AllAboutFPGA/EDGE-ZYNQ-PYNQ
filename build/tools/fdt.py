"""Minimal flattened device tree (DTB) reader/writer, enough to edit a device tree
and rebuild a U-Boot FIT image (image.ub) without dtc or mkimage.

Format: Devicetree Specification v0.4, chapter 5 (version 17 blobs).
"""
import struct

FDT_MAGIC = 0xD00DFEED
FDT_BEGIN_NODE, FDT_END_NODE, FDT_PROP, FDT_NOP, FDT_END = 1, 2, 3, 4, 9


class Node:
    def __init__(self, name):
        self.name = name
        self.props = []          # list of [name, bytes]
        self.children = []

    # ---- properties
    def prop(self, name):
        for p in self.props:
            if p[0] == name:
                return p[1]
        return None

    def has(self, name):
        return any(p[0] == name for p in self.props)

    def set(self, name, value):
        if isinstance(value, str):
            value = value.encode() + b"\0"
        elif isinstance(value, int):
            value = struct.pack(">I", value)
        elif isinstance(value, (list, tuple)):
            if value and isinstance(value[0], str):
                value = b"".join(v.encode() + b"\0" for v in value)
            else:
                value = b"".join(struct.pack(">I", v) for v in value)
        for p in self.props:
            if p[0] == name:
                p[1] = bytes(value)
                return
        self.props.append([name, bytes(value)])

    def delete(self, name):
        self.props = [p for p in self.props if p[0] != name]

    def u32(self, name):
        v = self.prop(name)
        return None if v is None else struct.unpack(">I", v[:4])[0]

    def cells(self, name):
        v = self.prop(name)
        return None if v is None else list(struct.unpack(">%dI" % (len(v) // 4), v))

    def str(self, name):
        v = self.prop(name)
        return None if v is None else v.rstrip(b"\0").decode(errors="replace")

    def strs(self, name):
        v = self.prop(name)
        return [] if v is None else [s.decode(errors="replace") for s in v.rstrip(b"\0").split(b"\0")]

    # ---- children
    def child(self, name):
        for c in self.children:
            if c.name == name:
                return c
        return None

    def add_child(self, name):
        c = self.child(name)
        if c is None:
            c = Node(name)
            self.children.append(c)
        return c

    def remove_child(self, name):
        self.children = [c for c in self.children if c.name != name]

    def walk(self, path="/"):
        yield path, self
        for c in self.children:
            yield from c.walk((path.rstrip("/") + "/" + c.name))

    def find(self, path):
        if path in ("", "/"):
            return self
        n = self
        for part in path.strip("/").split("/"):
            n = n.child(part)
            if n is None:
                return None
        return n


class FDT:
    def __init__(self, root, boot_cpuid=0, memrsv=None):
        self.root = root
        self.boot_cpuid = boot_cpuid
        self.memrsv = memrsv or []

    # ------------------------------------------------------------- parse
    @classmethod
    def parse(cls, blob):
        (magic, totalsize, off_struct, off_strings, off_rsv, version, last_comp,
         boot_cpuid, size_strings, size_struct) = struct.unpack(">10I", blob[:40])
        if magic != FDT_MAGIC:
            raise ValueError("not a device tree blob")
        memrsv = []
        o = off_rsv
        while True:
            a, s = struct.unpack(">QQ", blob[o:o + 16])
            o += 16
            if a == 0 and s == 0:
                break
            memrsv.append((a, s))
        strings = blob[off_strings:off_strings + size_strings]

        def getstr(off):
            e = strings.index(b"\0", off)
            return strings[off:e].decode()

        o = off_struct
        stack = []
        root = None
        while True:
            tok = struct.unpack(">I", blob[o:o + 4])[0]
            o += 4
            if tok == FDT_BEGIN_NODE:
                e = blob.index(b"\0", o)
                name = blob[o:e].decode()
                o = (e + 1 + 3) & ~3
                n = Node(name)
                if stack:
                    stack[-1].children.append(n)
                else:
                    root = n
                stack.append(n)
            elif tok == FDT_END_NODE:
                stack.pop()
            elif tok == FDT_PROP:
                ln, nameoff = struct.unpack(">II", blob[o:o + 8])
                o += 8
                stack[-1].props.append([getstr(nameoff), bytes(blob[o:o + ln])])
                o = (o + ln + 3) & ~3
            elif tok == FDT_NOP:
                pass
            elif tok == FDT_END:
                break
            else:
                raise ValueError("bad token %d at %d" % (tok, o - 4))
        return cls(root, boot_cpuid, memrsv)

    # ------------------------------------------------------------- write
    def to_blob(self, pad=0):
        strtab = bytearray()
        stroff = {}

        def soff(name):
            if name not in stroff:
                stroff[name] = len(strtab)
                strtab.extend(name.encode() + b"\0")
            return stroff[name]

        st = bytearray()

        def pad4():
            while len(st) % 4:
                st.append(0)

        def emit(n):
            st.extend(struct.pack(">I", FDT_BEGIN_NODE))
            st.extend(n.name.encode() + b"\0")
            pad4()
            for name, val in n.props:
                st.extend(struct.pack(">III", FDT_PROP, len(val), soff(name)))
                st.extend(val)
                pad4()
            for c in n.children:
                emit(c)
            st.extend(struct.pack(">I", FDT_END_NODE))

        emit(self.root)
        st.extend(struct.pack(">I", FDT_END))
        rsv = b"".join(struct.pack(">QQ", a, s) for a, s in self.memrsv) + struct.pack(">QQ", 0, 0)
        off_rsv = 40
        while off_rsv % 8:
            off_rsv += 1
        off_struct = off_rsv + len(rsv)
        off_strings = off_struct + len(st)
        total = off_strings + len(strtab) + pad
        hdr = struct.pack(">10I", FDT_MAGIC, total, off_struct, off_strings, off_rsv, 17, 16,
                          self.boot_cpuid, len(strtab), len(st))
        blob = bytearray(hdr)
        blob.extend(b"\0" * (off_rsv - len(blob)))
        blob.extend(rsv)
        blob.extend(st)
        blob.extend(strtab)
        blob.extend(b"\0" * pad)
        return bytes(blob)

    # ------------------------------------------------------------- helpers
    def phandles(self):
        out = {}
        for path, n in self.root.walk():
            ph = n.u32("phandle") if n.has("phandle") else (n.u32("linux,phandle") if n.has("linux,phandle") else None)
            if ph is not None:
                out[ph] = path
        return out

    def label_path(self, label):
        sym = self.root.child("__symbols__")
        return sym.str(label) if sym is not None and sym.has(label) else None

    def to_dts(self, skip_data_over=256):
        """Readable dump for review (not guaranteed to be valid dts input)."""
        out = ["/dts-v1/;", ""]

        def fmt(val):
            if len(val) == 0:
                return None
            if len(val) > skip_data_over:
                return "[%d bytes]" % len(val)
            if val[-1:] == b"\0" and all(32 <= b < 127 or b == 0 for b in val[:-1]) and b"\0\0" not in val:
                parts = val[:-1].split(b"\0")
                if all(parts):
                    return ", ".join('"%s"' % p.decode() for p in parts)
            if len(val) % 4 == 0:
                return "<" + " ".join("0x%x" % c for c in struct.unpack(">%dI" % (len(val) // 4), val)) + ">"
            return "[" + " ".join("%02x" % b for b in val) + "]"

        def rec(n, ind):
            out.append("%s%s {" % ("\t" * ind, n.name or "/"))
            for name, val in n.props:
                f = fmt(val)
                out.append("%s%s%s;" % ("\t" * (ind + 1), name, "" if f is None else " = " + f))
            for c in n.children:
                rec(c, ind + 1)
            out.append("%s};" % ("\t" * ind))

        rec(self.root, 0)
        return "\n".join(out) + "\n"
