"""Rebuild the PYNQ image.ub (U-Boot FIT image) with a different device tree blob.

Usage: python3 make_fit.py <original image.ub> <new system.dtb> <out image.ub>
The kernel is kept as it is; the device tree data and its sha1 hash are replaced.
"""
import hashlib
import struct
import sys
import time

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from fdt import FDT  # noqa: E402

fit = FDT.parse(open(sys.argv[1], "rb").read())
dtb = open(sys.argv[2], "rb").read()
FDT.parse(dtb)  # must be a valid blob

images = fit.root.child("images")
fdt_nodes = [c for c in images.children if c.str("type") == "flat_dt"]
assert len(fdt_nodes) == 1, "expected one device tree in the FIT image"
node = fdt_nodes[0]
node.set("data", dtb)
h = node.child("hash-1")
assert h.str("algo") == "sha1"
h.set("value", hashlib.sha1(dtb).digest())
fit.root.set("timestamp", int(time.time()))

# check every image hash
for img in images.children:
    hh = img.child("hash-1")
    assert hashlib.sha1(img.prop("data")).digest() == hh.prop("value"), img.name

blob = fit.to_blob()
open(sys.argv[3], "wb").write(blob)
print("FIT", len(blob), "bytes;", ", ".join("%s %d" % (c.name, len(c.prop("data"))) for c in images.children))
