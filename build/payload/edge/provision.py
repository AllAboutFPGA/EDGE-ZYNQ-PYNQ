# EDGE ZYNQ SoC FPGA kit: first-boot setup of the PYNQ image
# Invent Logics / allaboutfpga.com
# SPDX-License-Identifier: BSD-3-Clause
"""Turns the PYNQ v3.1 root file system into the EDGE ZYNQ one.

Runs from /boot/boot.py (as root) at every boot. Each step is done once per version of
the files in /boot/edge (see VERSION), so you can update the EDGE files by copying a new
/boot/edge folder to the SD card. A step that fails is tried again at the next boot.

Steps:
  * removes the PYNQ-Z2 overlays (always first: they do not fit this board's pins)
  * installs the EDGE base overlay (the XC7Z010 or XC7Z020 build, picked from the chip)
  * sets BOARD to EDGE-Z10 or EDGE-Z20
  * sets PYNQ's processor clock reference to 33.333 MHz (PYNQ assumes 50 MHz)
  * replaces the PYNQ-Z2 notebooks with the EDGE ones
  * gives eth0 a fixed MAC address made from the microSD card's ID, so the router
    gives the board the same IP address every time
"""
import glob
import hashlib
import json
import mmap
import os
import re
import shutil
import struct
import subprocess

EDGE = "/boot/edge"
SITE = "/usr/local/share/pynq-venv/lib/python3.10/site-packages"
OVERLAYS = SITE + "/pynq/overlays"
NOTEBOOKS = "/home/xilinx/jupyter_notebooks"
STATE = "/etc/edge-pynq-state.json"
BOARD_PROFILE = "/etc/profile.d/00-edge-board.sh"     # sorts before PYNQ's boardname.sh
ETH0 = "/etc/network/interfaces.d/eth0"
PYNQ_Z2_NOTEBOOKS = ["base", "logictools", "pynq_peripherals"]
PYNQ_Z2_GETTING_STARTED = ["4_base_overlay_iop.ipynb", "5_base_overlay_video.ipynb",
                           "6_base_overlay_audio.ipynb"]


def write_atomic(path, text):
    """Replace a file so that a power cut leaves either the old or the new file."""
    tmp = path + ".edge-tmp"
    with open(tmp, "w") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    if os.path.exists(path):
        shutil.copymode(path, tmp)
    os.replace(tmp, path)


def chip():
    """'z10' or 'z20' from the device code in SLCR PSS_IDCODE (0xF8000530)."""
    with open("/dev/mem", "rb") as f:
        m = mmap.mmap(f.fileno(), 0x1000, mmap.MAP_SHARED, mmap.PROT_READ, offset=0xF8000000)
        idcode = struct.unpack_from("<I", m, 0x530)[0]
        m.close()
    return {0x02: "z10", 0x07: "z20"}.get((idcode >> 12) & 0x1F), idcode


def is_edge_overlay():
    try:
        return "EDGE ZYNQ" in open(os.path.join(OVERLAYS, "base", "base.py")).read()
    except OSError:
        return False


def remove_pynq_z2_overlays():
    shutil.rmtree(os.path.join(OVERLAYS, "logictools"), ignore_errors=True)
    if os.path.isdir(os.path.join(OVERLAYS, "base")) and not is_edge_overlay():
        shutil.rmtree(os.path.join(OVERLAYS, "base"), ignore_errors=True)
        # PYNQ's record of the PYNQ-Z2 overlay that was loaded when the image was made
        for f in glob.glob(SITE + "/pynq/pl_server/_current_metadata.pkl") + \
                glob.glob(SITE + "/pynq/pl_server/global_pl_state_*.json"):
            os.remove(f)


def install_overlay(variant):
    src = os.path.join(EDGE, "overlays", "base")
    for f in ("base.bit", "base.hwh"):
        if not os.path.isfile(os.path.join(src, variant, f)):
            raise FileNotFoundError(os.path.join(src, variant, f))
    tmp = os.path.join(OVERLAYS, "base.edge-tmp")
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    for f in glob.glob(os.path.join(src, "*.py")):
        shutil.copy(f, os.path.join(tmp, os.path.basename(f).lower()))
    for f in ("base.bit", "base.hwh"):
        shutil.copy(os.path.join(src, variant, f), os.path.join(tmp, f))
    dst = os.path.join(OVERLAYS, "base")
    shutil.rmtree(dst, ignore_errors=True)
    os.rename(tmp, dst)


def set_board(board):
    write_atomic(BOARD_PROFILE, "# EDGE ZYNQ board name for PYNQ (written by /boot/edge/provision.py)\n"
                                "export BOARD=%s\n" % board)


def fix_clock_reference():
    path = SITE + "/pynq/ps.py"
    src = open(path).read()
    new_line = "DEFAULT_SRC_CLK_MHZ = 33.333333  # EDGE ZYNQ"
    if new_line in src:
        return
    i = src.find("class _ClocksZynq")
    j = src.find("DEFAULT_SRC_CLK_MHZ = 50.0", i)
    if i < 0 or j < 0:
        raise RuntimeError("pynq/ps.py is not as expected")
    if not os.path.exists(path + ".orig"):
        shutil.copy(path, path + ".orig")
    write_atomic(path, src[:j] + new_line + src[j + len("DEFAULT_SRC_CLK_MHZ = 50.0"):])
    for f in glob.glob(SITE + "/pynq/__pycache__/ps.*.pyc"):
        os.remove(f)


def install_notebooks():
    for name in PYNQ_Z2_NOTEBOOKS:
        shutil.rmtree(os.path.join(NOTEBOOKS, name), ignore_errors=True)
    for name in PYNQ_Z2_GETTING_STARTED:
        p = os.path.join(NOTEBOOKS, "getting_started", name)
        if os.path.exists(p):
            os.remove(p)
    src = os.path.join(EDGE, "notebooks")
    for item in os.listdir(src):
        s, d = os.path.join(src, item), os.path.join(NOTEBOOKS, item)
        if os.path.isdir(s):
            shutil.rmtree(d, ignore_errors=True)
            shutil.copytree(s, d)
        else:
            shutil.copy(s, d)
    subprocess.run(["chown", "-R", "xilinx:xilinx", NOTEBOOKS], check=False)


def mac_from_sd_card():
    cid = open("/sys/block/mmcblk0/device/cid").read().strip()
    h = hashlib.sha1(("EDGE-ZYNQ:" + cid).encode()).digest()
    return ":".join("%02x" % x for x in bytes([0x02]) + h[:5])    # locally administered, unicast


def set_mac():
    mac = mac_from_sd_card()
    text = open(ETH0).read()
    text = re.sub(r"\n\s*hwaddress ether [0-9a-fA-F:]+", "", text)
    if "iface eth0 inet dhcp" not in text:
        raise RuntimeError(ETH0 + " is not as expected")
    text = text.replace("iface eth0 inet dhcp", "iface eth0 inet dhcp\nhwaddress ether %s" % mac, 1)
    write_atomic(ETH0, text)
    # On this (first) boot the network may already be up with the old address: restart the
    # network once the normal start-up has finished, so the new address is used now.
    # The restart must run inside networking.service: an ifup run from this short-lived unit
    # would start dhclient in the unit's own process group, and systemd stops dhclient again
    # as soon as the unit ends, which leaves the board without a DHCP address.
    cmd = ('[ "$(cat /sys/class/net/eth0/address)" = "%s" ] || '
           '{ timeout 120 systemctl restart networking.service; timeout 30 ifup eth0:1; }' % mac)
    subprocess.run(["systemd-run", "--no-block", "--collect", "--unit=edge-mac-apply",
                    "--property=After=networking.service network-online.target",
                    "/bin/sh", "-c", cmd], check=False, timeout=30,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _load_state():
    try:
        return json.load(open(STATE))
    except Exception:  # noqa: BLE001
        return {}


def run(log):
    def step(name, fn):
        try:
            fn()
            log("provision: " + name)
            return True
        except Exception as e:  # noqa: BLE001  - one failed step must not stop the others
            log("provision: %s FAILED: %r" % (name, e))
            return False

    # never leave a PYNQ-Z2 overlay where the boot script could load it
    step("remove PYNQ-Z2 overlays", remove_pynq_z2_overlays)

    version = open(os.path.join(EDGE, "VERSION")).read().strip()
    variant, idcode = chip()
    state = _load_state()
    if state.get("version") != version or state.get("variant") != variant:
        state = {"version": version, "variant": variant, "done": []}
    steps = [("revision", lambda: shutil.copy("/boot/REVISION", "/home/xilinx/REVISION")),
             ("clock", fix_clock_reference),
             ("notebooks", install_notebooks),
             ("mac", set_mac)]
    if variant:
        steps[:0] = [("overlay", lambda: install_overlay(variant)),
                     ("board", lambda: set_board("EDGE-" + variant.upper()))]
    todo = [s for s in steps if s[0] not in state["done"]]
    if not todo:
        return variant
    log("provision: EDGE PYNQ files %s, chip IDCODE 0x%08x (%s)" % (version, idcode, variant or "unknown"))
    if not variant:
        log("provision: unknown chip, the base overlay is not installed")
    for name, fn in todo:
        if step(name, fn):
            state["done"].append(name)
            write_atomic(STATE, json.dumps(state) + "\n")
    os.sync()
    return variant
