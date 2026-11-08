#! /usr/bin/env python3
# EDGE ZYNQ SoC FPGA kit: PYNQ boot script
# Invent Logics / allaboutfpga.com
#
# Linux runs this file (as root) at every boot, from the boot partition of the microSD
# card. You can edit it on a PC: the boot partition shows up as a drive.
#
# What it does:
#   1. First boot only: sets up the EDGE ZYNQ files (see /boot/edge/provision.py).
#   2. Loads the EDGE base overlay, blinks the four LEDs and shows "EdGE".
#   3. When the network is up, shows the board's IP address on the 7-segment display,
#      one number at a time; the last number stays on (e.g. "45" for 192.168.1.45).
# A log is written to /var/log/edge-boot.log.

import subprocess
import sys
import time
import traceback

LOG = "/var/log/edge-boot.log"


def log(msg):
    try:
        with open(LOG, "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")
    except OSError:
        pass


# 1. first boot setup
try:
    sys.path.insert(0, "/boot/edge")
    import provision
    provision.run(log)
except Exception:  # noqa: BLE001
    log("provision error:\n" + traceback.format_exc())

# 2. base overlay, LEDs and display
try:
    from time import sleep
    import pynq.overlays.base as edge_base

    if not hasattr(edge_base, "board_variant"):        # not the EDGE overlay: do not load it
        raise RuntimeError("the installed base overlay is not the EDGE ZYNQ one")
    base = edge_base.BaseOverlay("base.bit")
    base.seven_seg.show_text("EdGE")
    for _ in range(4):
        base.leds[0:4].on()
        sleep(0.2)
        base.leds[0:4].off()
        sleep(0.2)
    with open("/run/edge_base_loaded", "w") as f:
        f.write(str(time.time()))
    log("base overlay loaded")
except Exception:  # noqa: BLE001
    log("base overlay error:\n" + traceback.format_exc())

# 3. IP address on the 7-segment display, once the network is up (runs in the background)
try:
    r = subprocess.run(["systemd-run", "--no-block", "--collect", "--unit=edge-ip-display",
                        "--property=After=network-online.target clear_pl_statefile.service edge-mac-apply.service",
                        "--property=Wants=network-online.target", "--setenv=XILINX_XRT=/usr",
                        sys.executable, "/boot/edge/ip_display.py"],
                       check=False, timeout=30, capture_output=True, text=True)
    if r.returncode != 0:
        log("ip display start failed: %s" % (r.stderr or r.stdout).strip())
except Exception:  # noqa: BLE001
    log("ip display error:\n" + traceback.format_exc())


# ---------------------------------------------------------------------------------
# Your own boot-time code can go below. Examples from PYNQ:
#
# example #1 - WiFi connection at boot
#from pynq.lib import Wifi
#
#port = Wifi()
#port.connect('your_ssid', 'your_password', auto=True)
#
# example #2 - Change hostname
#import subprocess
#subprocess.call('pynq_hostname.sh aNewHostName'.split())
