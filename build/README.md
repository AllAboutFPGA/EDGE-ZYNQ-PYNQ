# EDGE ZYNQ PYNQ v3.1.1 image: build files

Invent Logics / allaboutfpga.com, 8 November 2026 (release 3: VGA output, switches and buttons numbered by board position)

The image is AMD's PYNQ v3.1.1 image for the PYNQ-Z2 with a new boot partition for the
EDGE ZYNQ kit. The EDGE ZYNQ uses the same processor I/O as the PYNQ-Z2 (UART0 on MIO 14/15,
microSD on SD0 with card detect on MIO 47, Ethernet on MIO 16-27 with MDIO on MIO 52/53,
USB0 with reset on MIO 46, QSPI, 512 MB DDR3), so the PYNQ Linux kernel and Ubuntu root file
system are used as they are. What changes:

| Part | Change |
|---|---|
| BOOT.BIN | EDGE FSBL (Vitis 2022.2, from the EDGE processor settings: 33.333 MHz clock, DDR3 timing, MIO) + the PYNQ U-Boot 2024.01 + the EDGE U-Boot device tree |
| image.ub | PYNQ Linux 6.6.10 kernel + the EDGE device tree |
| boot.py | first-boot setup, base overlay, LED blink, IP address on the 7-segment display |
| edge/ | EDGE base overlay (XC7Z010 and XC7Z020 builds), driver, notebooks, setup scripts |

Device tree changes (tools/make_edge_dtb.py): processor clock 50 MHz -> 33.333 MHz, board
name, PS-XADC driver off (the base overlay uses the XADC from the PL), PYNQ-Z2 audio codec
node removed, Ethernet reset reference (MIO 9) removed, SD write-protect ignored, and on
Linux: USB0 in host mode (connector J3, jumpers J6 and J7 fitted) and a heartbeat on the
PS LED D1 (MIO 9). The Ethernet PHY address is not fixed, so both the RTL8211E (V1/V2
boards) and the RTL8211F (V3 board) work; `rgmii-id` turns on the RTL8211F RGMII delays.

## Base overlay

LEDs, switches, push buttons (with interrupts), 7-segment display, buzzer, XADC (die
temperature, supplies, J15 inputs) and HDMI output. Switches and buttons are numbered by their
position on the board, left to right, so each switch sits under the LED with the same number:
LEDs 0-3 = D4-D7, switches 0-3 = SW6, SW4, SW3, SW8, buttons 0-1 = SW7, SW5
(vivado/edge_base.xdc; EDGE_ZYNQ_Master.xdc numbers the switches SW3, SW4, SW6, SW8). The HDMI output is PYNQ's own video
pipeline with the same block names as the PYNQ-Z2 base overlay
(video/axi_vdma -> video/hdmi_out/{pixel_unpack, color_convert, frontend/{vtc_out,
axi_dynclk, rgb2dvi}}), so `pynq.lib.video` works unchanged:

```python
from pynq.overlays.base import BaseOverlay
from pynq.lib.video import VideoMode, PIXEL_BGR
base = BaseOverlay("base.bit")
hdmi_out = base.video.hdmi_out
hdmi_out.configure(VideoMode(640, 480, 24), PIXEL_BGR)
hdmi_out.start()
frame = hdmi_out.newframe(); frame[:] = 255; hdmi_out.writeframe(frame)
```

The board has one HDMI connector, used as an output (HDMI_OUT_EN, pin L20, is driven high).
The same picture also goes to the 12-bit VGA connector P1 (vivado/hdl/edge_vga.v taps the
pixels going into rgb2dvi, 4 bits per colour, blanked outside the active picture; the sync
polarities are the ones PYNQ sets for each mode).
Notebooks edge/6 and edge/7 are the OpenCV face and edge detection demos (USB webcam to HDMI).

## Rebuilding

1. PYNQ's video IP: unzip pynq_ip.zip (PYNQ v3.1 boards/ip: axi_dynclk, rgb2dvi,
   color_swap, the TMDS interface and the HLS sources), then build the two HLS cores with
   Vitis HLS 2022.2: in ip/hls run `vitis_hls -f color_convert/script.tcl` and
   `vitis_hls -f pixel_unpack/script.tcl` (see build_hls_ip.ps1).
2. Base overlay (Vivado 2022.2), for each chip:
   `vivado -mode batch -source vivado/edge_base.tcl -tclargs xc7z020clg400-1 <work> <out> <ip dir>`
   (and `xc7z010clg400-1`). Output: base.bit, base.hwh, base.xsa.
3. FSBL (Vitis 2022.2): `xsct vivado/fsbl.tcl <out>/base.xsa <fsbl dir>`.
4. From the PYNQ-Z2 v3.1.1 image's boot partition, take U-Boot out of BOOT.BIN and the device
   tree out of image.ub (tools/bootbin.py, tools/fdt.py), then run tools/make_edge_dtb.py
   (add `--linux` for the Linux tree) and tools/make_fit.py.
5. `bootgen -arch zynq -image edge_pynq_boot.bif -o BOOT.BIN -w on`
6. Copy the overlay files to payload/edge/overlays/base/z10 and z20, run
   tools/make_notebooks.py payload/edge/notebooks, then tools/make_bootfs.py builds the boot
   partition (needs pyfatfs).
7. `assemble_image.ps1 -Name <image name>` writes it into a copy of the PYNQ-Z2 image and
   zips it. tools/make_update_zip.py makes the zip for updating a card without reflashing.

To change only the Python files, notebooks or overlays on a card, copy the edge folder to the
card's boot partition and change edge/VERSION; the next boot installs it again.

pynq_ip.zip holds files from the PYNQ project (BSD 3-Clause, AMD/Xilinx) and Digilent's
vivado-library (MIT); see their licence files in the PYNQ repository.
