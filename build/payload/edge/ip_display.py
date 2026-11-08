# EDGE ZYNQ SoC FPGA kit: show the board's IP address on the 7-segment display after boot
# Invent Logics / allaboutfpga.com
# SPDX-License-Identifier: BSD-3-Clause
#
# Started by /boot/boot.py through systemd-run, after the network is up. Shows the four
# numbers of the DHCP address one at a time (twice), then leaves the last number on.
# Without a DHCP address it shows the fixed address 192.168.2.99. It does nothing if
# the base overlay was not loaded at boot or if another overlay has been loaded since.
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import traceback

os.environ.setdefault("XILINX_XRT", "/usr")     # PYNQ needs it to find the Zynq PL

SITE = "/usr/local/share/pynq-venv/lib/python3.10/site-packages"
STATIC_IP = "192.168.2.99"
BASE = SITE + "/pynq/overlays/base"
SEG7_GPIO = 0x41230000          # seg7_gpio in the EDGE base overlay (checked against base.hwh)
WAIT_S = 90
LOG = "/var/log/edge-boot.log"


def log(msg):
    try:
        with open(LOG, "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + "ip display: " + msg + "\n")
    except OSError:
        pass


def dhcp_ip():
    out = subprocess.run(["ip", "-4", "-o", "addr", "show", "dev", "eth0"],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        parts = line.split()
        if "inet" in parts:
            ip = parts[parts.index("inet") + 1].split("/")[0]
            if ip != STATIC_IP:
                return ip
    return None


def base_still_loaded():
    """True if the EDGE base overlay that boot.py loaded is still the one in the PL."""
    if not os.path.exists("/run/edge_base_loaded"):
        return False
    try:
        if open("/sys/class/fpga_manager/fpga0/state").read().strip() != "operating":
            return False
    except OSError:
        return False
    states = glob.glob(SITE + "/pynq/pl_server/global_pl_state_*.json")
    if not states:
        return True     # PYNQ cleared its record at boot and nothing was loaded since
    h = hashlib.sha1()
    with open(BASE + "/base.bit", "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    for f in states:
        try:
            st = json.load(open(f))
        except Exception:  # noqa: BLE001
            return False
        if st.get("bitfile_hash") and st["bitfile_hash"] != h.hexdigest():
            return False    # another overlay was loaded
        if not st.get("bitfile_hash") and not st.get("bitfile_name", "").endswith("/overlays/base/base.bit"):
            return False
    return True


def seg7_address():
    """seg7_gpio base address from base.hwh (falls back to the built-in value)."""
    try:
        hwh = open(BASE + "/base.hwh").read()
        m = re.search(r'BASEVALUE="(0x[0-9A-Fa-f]+)"[^>]*INSTANCE="seg7_gpio"', hwh) or \
            re.search(r'INSTANCE="seg7_gpio"[^>]*BASEVALUE="(0x[0-9A-Fa-f]+)"', hwh)
        if m:
            return int(m.group(1), 16)
    except OSError:
        pass
    return SEG7_GPIO


def main():
    deadline = time.time() + WAIT_S
    ip = dhcp_ip()
    while ip is None and time.time() < deadline:
        time.sleep(2)
        ip = dhcp_ip()
    ip = ip or STATIC_IP
    if not base_still_loaded():
        return
    import pynq
    sys.path.insert(0, BASE)
    from base import SevenSegment
    addr = seg7_address()
    if addr != SEG7_GPIO:
        log("seg7_gpio at 0x%08x" % addr)
    seg = SevenSegment(pynq.MMIO(addr, 0x1000))
    nums = ip.split(".")
    for _ in range(2):
        for i, n in enumerate(nums):
            if not base_still_loaded():
                return
            seg.show_text(n + ("." if i < 3 else ""))
            time.sleep(1.2)
    seg.show_text(nums[-1])


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001
        log(traceback.format_exc())
