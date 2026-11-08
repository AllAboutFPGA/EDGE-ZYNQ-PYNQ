"""Make the update zip: every file of the EDGE boot partition, for copying onto a card that
already has an EDGE PYNQ image (no reflashing needed).

Usage: python3 make_update_zip.py <edge_boot_part.bin> <out.zip> <readme.txt>
(needs pyfatfs and pyfilesystem2 on PYTHONPATH)
"""
import hashlib
import sys
import zipfile

import fs
from pyfatfs.PyFatFS import PyFatFS


def main(part, out, readme):
    files = []
    with PyFatFS(part) as fat:
        for path in sorted(fat.walk.files("/")):
            data = fat.readbytes(path)
            files.append((path.lstrip("/"), data))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(readme, "README_UPDATE.txt")
        for name, data in files:
            z.writestr("boot/" + name, data)
    # read back and compare
    with zipfile.ZipFile(out) as z:
        for name, data in files:
            assert z.read("boot/" + name) == data, name
        assert z.testzip() is None
    for name, data in files:
        print("%9d  %s  %s" % (len(data), hashlib.sha1(data).hexdigest()[:12], name))
    print("files:", len(files))


if __name__ == "__main__":
    main(*sys.argv[1:4])
