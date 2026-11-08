"""Build the EDGE ZYNQ PYNQ boot (FAT) partition from the PYNQ-Z2 one.

Usage: python3 make_bootfs.py <z2_boot_part.bin> <payload dir> <BOOT.BIN> <image.ub> <out.bin>

The PYNQ-Z2 partition is copied (same size, same FAT16 layout and label), its BOOT.BIN,
image.ub, boot.py and REVISION are replaced, and the payload's edge/ folder is added.
boot.scr is kept: it loads image.ub with the kernel and device tree.
"""
import hashlib
import os
import shutil
import sys
import warnings

warnings.filterwarnings("ignore")
from pyfatfs.PyFatFS import PyFatFS  # noqa: E402

src, payload, bootbin, imageub, out = sys.argv[1:6]
shutil.copy(src, out)

files = {"/BOOT.BIN": open(bootbin, "rb").read(),
         "/image.ub": open(imageub, "rb").read(),
         "/boot.py": open(os.path.join(payload, "boot.py"), "rb").read(),
         "/REVISION": open(os.path.join(payload, "REVISION"), "rb").read()}
for v in ("z10", "z20"):
    for f in ("base.bit", "base.hwh"):
        p = os.path.join(payload, "edge", "overlays", "base", v, f)
        assert os.path.getsize(p) > 100000, "missing overlay file " + p
for root, dirs, names in os.walk(os.path.join(payload, "edge")):
    dirs[:] = [d for d in dirs if d != "__pycache__"]
    for n in names:
        if n.endswith(".pyc"):
            continue
        p = os.path.join(root, n)
        rel = "/" + os.path.relpath(p, payload).replace(os.sep, "/")
        files[rel] = open(p, "rb").read()

fs = PyFatFS(out)
for old in ("/BOOT.BIN", "/IMAGE.UB", "/BOOT.PY", "/REVISION"):
    if fs.exists(old):
        fs.remove(old)
for path in sorted(files):
    d = path.rsplit("/", 1)[0]
    if d:
        fs.makedirs(d, recreate=True)
    fs.writebytes(path, files[path])
fs.close()

# read everything back and compare
fs = PyFatFS(out, read_only=True)
found = {p: fs.readbytes(p) for p in fs.walk.files()}
fs.close()
for path, data in files.items():
    got = found.get(path)
    if got is None:     # names that differ only in case
        got = next((v for k, v in found.items() if k.lower() == path.lower()), None)
    assert got == data, "mismatch " + path
extra = sorted(set(k.lower() for k in found) - set(k.lower() for k in files))
print("boot partition: %d files, %d bytes; kept: %s" % (len(files), sum(map(len, files.values())), extra))
for path in sorted(found):
    print("  %-60s %9d  %s" % (path, len(found[path]), hashlib.sha256(found[path]).hexdigest()[:16]))
