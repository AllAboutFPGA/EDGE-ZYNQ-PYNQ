EDGE ZYNQ SoC FPGA kit - PYNQ files on the boot partition
Invent Logics / allaboutfpga.com

This folder holds the EDGE parts of the PYNQ image. On the first boot, boot.py
(next to this folder) runs provision.py, which:
  * installs the EDGE base overlay (overlays/base/z10 or z20, picked from the chip)
  * replaces the PYNQ-Z2 notebooks with the EDGE notebooks (notebooks/)
  * sets BOARD to EDGE-Z10 or EDGE-Z20 and the PYNQ processor clock to 33.333 MHz
  * gives eth0 a fixed MAC address made from the microSD card's ID
It writes a log to /var/log/edge-boot.log on the board.

To update these files, copy a newer edge folder over this one and change VERSION:
the next boot installs it again.

Numbering in the base overlay (left to right on the board, so each switch sits under the
LED with the same number):
  LEDs      0..3 = D4, D5, D6, D7
  switches  0..3 = SW6, SW4, SW3, SW8
  buttons   0..1 = SW7 (left), SW5 (right)

VGA: the HDMI picture is also sent to the VGA connector P1 (12-bit colour).

HDMI output and USB webcam: see notebooks/edge/6 and 7 (USB host connector J3 with
jumpers J6 and J7 fitted; connect the HDMI monitor before running the notebook).

Board defaults: user xilinx / password xilinx, Jupyter at http://<board>:9090
(password xilinx), fixed address 192.168.2.99 for a direct cable to a PC.
