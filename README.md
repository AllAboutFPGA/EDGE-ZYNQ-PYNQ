# EDGE ZYNQ PYNQ

PYNQ v3.1.1 for the **EDGE ZYNQ SoC FPGA kit** (XC7Z010 and XC7Z020 boards), from
[Invent Logics / allaboutfpga.com](https://allaboutfpga.com).

Write the image to a microSD card, boot the board and program its FPGA from Python in a web
browser. One image works on both the EDGE ZYNQ Z7-10 and Z7-20. It picks the right base
overlay for the chip on the first boot.

## Download

Get the files from the [Releases](../../releases) page:

| File | What it is |
| --- | --- |
| `EDGE_ZYNQ_PYNQ_v3.1.1_2026-11-08.zip` | Full microSD card image (8.3 GB once unzipped). Use this for a new card. |
| `EDGE_ZYNQ_PYNQ_update_2026-11-08.zip` | Update for a card that already has an EDGE PYNQ image: copy its `boot` folder onto the card's PYNQ drive. |
| `*.sha256` | Checksums |

## Quick start

1. Write the image zip to a **16 GB or larger** microSD card with
   [balenaEtcher](https://etcher.balena.io/) (it reads the .zip directly).
2. Set the boot jumper to **SD**, insert the card and connect Ethernet to your router.
3. Power on. The first boot takes about a minute longer while it sets up the board.
   `EdGE` appears on the 7-segment display, then the board's IP address, one number at a time.
4. Open `http://<board IP>:9090` in a browser. The Jupyter password is **xilinx**.

No router? Connect the board straight to your PC, give the PC the address 192.168.2.1, and
open `http://192.168.2.99:9090`. Linux login (SSH or serial at 115200): `xilinx` / `xilinx`.
Shut down with `sudo poweroff` before removing power.

## What is in the image

The image is AMD's PYNQ v3.1.1 image for the PYNQ-Z2 (Ubuntu 22.04, Linux 6.6.10) with a
new boot partition for the EDGE ZYNQ: the EDGE FSBL and device tree, and an EDGE base overlay.

| Base overlay block | Python | Notes |
| --- | --- | --- |
| 4 LEDs | `base.leds` | D4 to D7 |
| 4 slide switches | `base.switches` | With interrupts |
| 2 push buttons | `base.buttons` | With interrupts |
| 4-digit 7-segment display | `base.seven_seg` | Numbers, hex, text, raw segments |
| Buzzer | `base.buzzer` | Fit jumper J10 |
| XADC | `base.xadc` | Die temperature, supplies, LM35 and LDR on J15 |
| HDMI output | `base.video.hdmi_out` | `pynq.lib.video` works unchanged, 640x480 to 1920x1080 |
| VGA output, connector P1 | (same as HDMI) | Same picture as HDMI, 12-bit colour. New in 2026-11-08, not yet checked on a monitor |

The USB port J3 runs in host mode (fit jumpers J6 and J7), so USB webcams work with OpenCV.

Switches and buttons are numbered by their position on the board, left to right, so each
switch sits under the LED with the same number:

| Number | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| LED | D4 | D5 | D6 | D7 |
| Slide switch | SW6 | SW4 | SW3 | SW8 |
| Push button | SW7 (left) | SW5 (right) | | |

Notebooks on the board, in the `edge` folder:

1. LEDs, switches and buttons
2. 7-segment display
3. XADC sensors
4. Buzzer
5. Button interrupts with asyncio
6. OpenCV face detection, USB webcam to HDMI
7. OpenCV edge detection, USB webcam to HDMI

## This repository

| Folder | Contents |
| --- | --- |
| [`build/`](build) | Everything to rebuild the image: the base overlay (Vivado Tcl, pin file, Verilog), the FSBL script, device tree and boot partition tools, the files the image installs on first boot (`payload/`), and the scripts that assemble the card image. See [build/README.md](build/README.md). |
| [`tutorial-series/`](tutorial-series) | A 16-part PYNQ tutorial series: notebooks for the base overlay, HDMI, a USB webcam with OpenCV and a web dashboard, plus Vivado and Vitis HLS sources for your own overlays (a first overlay, a Verilog PWM over AXI-Lite, a driver class, AXI DMA and an HLS FIR filter). See [tutorial-series/README.md](tutorial-series/README.md). |

To update the EDGE files on a card without reflashing, copy `build/payload/edge` to the
card's boot partition and change `edge/VERSION`. The next boot installs it again.

## Tested

| Board | Release | Checked on hardware |
| --- | --- | --- |
| EDGE ZYNQ Z7-20 (V3) | 2026-11-08 | Boot, update install, LEDs, switches, buttons, 7-segment, XADC, buzzer, interrupts, HDMI, webcam face and edge detection |
| EDGE ZYNQ Z7-10 (V3) | 2026-11-07 (2) | Boot, Ethernet (RTL8211F), HDMI, webcam face and edge detection |

Still to do: the 2026-11-08 Z7-10 bitstream on hardware, the VGA output on a monitor, and
the tutorial series' own overlays (parts 12 to 16), which have been checked in simulation only.

## Releases

| Release | Changes |
| --- | --- |
| 2026-11-08 | VGA output (HDMI picture on P1). Switches and buttons numbered by board position. First boot keeps its DHCP address when it applies the fixed MAC address. Webcam notebooks no longer print a stray `<contextlib...>` line. |
| 2026-11-07 (2) | HDMI output, USB host mode, OpenCV webcam notebooks |
| 2026-11-07 | First PYNQ v3.1.1 image for the EDGE ZYNQ Z7-10 and Z7-20 |

## Licence

Files written by Invent Logics are under the BSD 3-Clause licence ([LICENSE](LICENSE)).
`build/pynq_ip.zip` holds files from the [PYNQ project](https://github.com/Xilinx/PYNQ)
(BSD 3-Clause, AMD/Xilinx) and Digilent's
[vivado-library](https://github.com/Digilent/vivado-library) (MIT). The card image contains
PYNQ, Ubuntu and Linux under their own licences.
