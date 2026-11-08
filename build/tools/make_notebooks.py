"""Write the EDGE ZYNQ example notebooks (Jupyter nbformat 4)."""
import json
import os
import sys

OUT = sys.argv[1]


def nb(cells, prefix="c"):
    out = []
    for n, (kind, src) in enumerate(cells):
        src = src.strip("\n")
        lines = [l + "\n" for l in src.split("\n")]
        lines[-1] = lines[-1].rstrip("\n")
        c = {"cell_type": kind, "id": "%s%02d" % (prefix, n), "metadata": {}, "source": lines}
        if kind == "code":
            c["execution_count"] = None
            c["outputs"] = []
        out.append(c)
    return {"cells": out, "metadata": {
        "kernelspec": {"display_name": "Python 3 (ipykernel)", "language": "python", "name": "python3"},
        "language_info": {"name": "python"}}, "nbformat": 4, "nbformat_minor": 5}


def write(rel, cells, prefix="c"):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(nb(cells, prefix), f, indent=1, ensure_ascii=False)
        f.write("\n")


M, C = "markdown", "code"

write("Welcome to EDGE ZYNQ.ipynb", [
    (M, """
# Welcome to PYNQ on the EDGE ZYNQ SoC FPGA kit

This image is PYNQ v3.1 (Ubuntu 22.04, Python 3.10, JupyterLab) for the EDGE ZYNQ kit from
[allaboutfpga.com](https://allaboutfpga.com). It works on both the XC7Z010 and the XC7Z020 board.

**Notebooks**
* `edge/` – the EDGE base overlay: LEDs, switches, push buttons, 7-segment display,
  XADC (Zynq temperature, LM35 and light sensor on J15), buzzer, and HDMI output with
  OpenCV face and edge detection from a USB webcam (notebooks 6 and 7)
* `getting_started/` – Jupyter and Python basics
* `common/` – general PYNQ examples

**On this board**
* The PS LED (D1) blinks a heartbeat while Linux runs.
* After boot the 7-segment display shows the board's IP address, one number at a time.
* USB webcam, keyboard or memory stick: USB host connector J3, with jumpers J6 and J7 fitted.
* HDMI monitor: connect it before you run an HDMI notebook. The same picture is also on the
  VGA connector P1 (12-bit colour), so a VGA monitor works too, or both at once.
* Fixed address for a direct cable to a PC: `192.168.2.99`. Jupyter: `http://<address>:9090`,
  password `xilinx`. Login (SSH or serial at 115200): `xilinx` / `xilinx`.
"""),
    (C, """
import os
from pynq.overlays.base import board_variant
print("Board:", os.environ.get("BOARD"), "| detected:", board_variant())
"""),
    (C, """
from pynq import Clocks
print("CPU clock: {:.1f} MHz, PL clock 0: {:.1f} MHz".format(Clocks.cpu_mhz, Clocks.fclk0_mhz))
"""),
])

write("edge/1_leds_switches_buttons.ipynb", [
    (M, """
# LEDs, slide switches and push buttons

The EDGE base overlay connects the 4 LEDs, the 4 slide switches and the 2 PL push buttons
to AXI GPIO blocks. They are numbered by position on the board, left to right, so each
switch sits under the LED with the same number:

| Number | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| LED | D4 | D5 | D6 | D7 |
| Slide switch | SW6 | SW4 | SW3 | SW8 |
| Push button | SW7 | SW5 | | |
"""),
    (C, """
from pynq.overlays.base import BaseOverlay
base = BaseOverlay("base.bit")
"""),
    (M, "## LEDs"),
    (C, """
from time import sleep

base.leds[0].on()        # LED D4
sleep(1)
base.leds[0].off()

for i in range(4):       # running light
    base.leds[i].on()
    sleep(0.3)
    base.leds[i].off()
"""),
    (C, """
base.leds[0:4].write(0b1010)   # write all four LEDs at once
"""),
    (M, "## Slide switches\nMove the switches and run the cell again."),
    (C, """
value = base.switches.read()
print("Switches: {:04b}".format(value))
for i in range(4):
    print("switch", i, "is", "on" if base.switches[i].read() else "off")
"""),
    (M, "## Switches drive the LEDs\nRuns for 10 seconds."),
    (C, """
import time
end = time.time() + 10
while time.time() < end:
    base.leds[0:4].write(base.switches.read())
    time.sleep(0.05)
base.leds[0:4].off()
"""),
    (M, "## Push buttons\nPress a button within 10 seconds."),
    (C, """
end = time.time() + 10
while time.time() < end:
    b = base.buttons.read()
    if b:
        print("button value", b)
        base.leds[0:4].write(0b1111 if b == 3 else (0b0011 if b == 1 else 0b1100))
        while base.buttons.read():
            time.sleep(0.02)
        base.leds[0:4].off()
    time.sleep(0.02)
"""),
])

write("edge/2_seven_segment.ipynb", [
    (M, """
# 4-digit 7-segment display

The display is multiplexed in the FPGA logic, so it shows a steady value without any help
from Python. You can show numbers, hex values, short text or your own segment patterns.
"""),
    (C, """
from pynq.overlays.base import BaseOverlay
base = BaseOverlay("base.bit")
seg = base.seven_seg
"""),
    (C, """
seg.show_number(1234)
"""),
    (C, """
seg.show_number(-3.75)
"""),
    (C, """
seg.show_hex(0xBEEF)
"""),
    (C, """
seg.show_text("HELP")
"""),
    (M, "Your own patterns: bit 0 = segment a, 1 = b, 2 = c, 3 = d, 4 = e, 5 = f, 6 = g, 7 = decimal point."),
    (C, """
seg.show_segments([0x01, 0x40, 0x08, 0x80])
"""),
    (M, "## A counter"),
    (C, """
import time
for n in range(0, 101):
    seg.show_number(n)
    time.sleep(0.05)
"""),
    (M, "## A clock (hh.mm) for 20 seconds"),
    (C, """
end = time.time() + 20
while time.time() < end:
    t = time.localtime()
    seg.show_text("{:02d}.{:02d}".format(t.tm_hour, t.tm_min))
    time.sleep(0.5)
"""),
    (C, "seg.clear()"),
])

write("edge/3_xadc_sensors.ipynb", [
    (M, """
# XADC: chip temperature, supplies and the J15 sensors

J15 pins 3 and 4 go to the XADC (VAUX2 and VAUX10) through a 2.32 kΩ / 1 kΩ divider,
so they accept 0–3.3 V.

* **LM35 temperature sensor**: fit a jumper between J15 pins 3 and 5.
* **LDR light sensor**: fit a jumper between J15 pins 4 and 6.
"""),
    (C, """
from pynq.overlays.base import BaseOverlay
base = BaseOverlay("base.bit")
xadc = base.xadc
"""),
    (C, """
print("Zynq die temperature: {:.1f} °C".format(xadc.temperature()))
print("VCCINT  {:.3f} V".format(xadc.vccint()))
print("VCCAUX  {:.3f} V".format(xadc.vccaux()))
"""),
    (C, """
print("J15 pin 3: {:.3f} V".format(xadc.j15_voltage(3)))
print("J15 pin 4: {:.3f} V".format(xadc.j15_voltage(4)))
print("LM35 temperature: {:.1f} °C".format(xadc.lm35_celsius()))
print("Light level: {:.2f} V (higher = brighter)".format(xadc.light_level()))
"""),
    (M, "## Show the LM35 temperature on the 7-segment display (20 seconds)"),
    (C, """
import time
end = time.time() + 20
while time.time() < end:
    base.seven_seg.show_number(round(xadc.lm35_celsius(), 1))
    time.sleep(0.5)
"""),
    (M, "## Plot the light level for 10 seconds\nCover the LDR with your hand while it runs."),
    (C, """
%matplotlib inline
import matplotlib.pyplot as plt
samples = []
end = time.time() + 10
while time.time() < end:
    samples.append(xadc.light_level())
    time.sleep(0.05)
plt.plot(samples)
plt.ylabel("LDR voltage (V)")
plt.xlabel("sample")
plt.show()
"""),
])

write("edge/4_buzzer.ipynb", [
    (M, """
# Buzzer

Fit the jumper on **J10 between pins 1 and 2** to connect the buzzer.
"""),
    (C, """
from pynq.overlays.base import BaseOverlay
base = BaseOverlay("base.bit")
bz = base.buzzer
"""),
    (C, "bz.beep(2000, 0.3)"),
    (C, """
C4, D4, E4, F4, G4, A4, B4, C5 = 262, 294, 330, 349, 392, 440, 494, 523
bz.play([(C4, .25), (D4, .25), (E4, .25), (F4, .25), (G4, .25), (A4, .25), (B4, .25), (C5, .5)])
"""),
    (M, "## Buzz when a push button is pressed (10 seconds)"),
    (C, """
import time
end = time.time() + 10
while time.time() < end:
    b = base.buttons.read()
    if b == 1:
        bz.tone(1000)
    elif b == 2:
        bz.tone(2000)
    else:
        bz.off()
    time.sleep(0.02)
bz.off()
"""),
])

write("edge/5_buttons_interrupts.ipynb", [
    (M, """
# Push buttons with interrupts (asyncio)

The buttons and switches raise interrupts, so Python can wait for them without polling.
Press button 0 (SW7, left) to toggle LED D4 and button 1 (SW5, right) to toggle LED D5;
flip switch 0 (SW6, leftmost) to stop.
"""),
    (C, """
from pynq.overlays.base import BaseOverlay
base = BaseOverlay("base.bit")
"""),
    (C, """
import asyncio

async def toggle_on_press(btn, led):
    while True:
        await base.buttons[btn].wait_for_value_async(1)
        base.leds[led].toggle()
        await base.buttons[btn].wait_for_value_async(0)

async def main():
    start = base.switches[0].read()
    tasks = [asyncio.ensure_future(toggle_on_press(0, 0)),
             asyncio.ensure_future(toggle_on_press(1, 1))]
    await base.switches[0].wait_for_value_async(1 - start)
    for t in tasks:
        t.cancel()
    print("stopped")

await main()
"""),
    (C, "base.leds[0:4].off()"),
])

write("edge/6_opencv_face_detection_webcam.ipynb", [
    (M, """
# OpenCV face detection: USB webcam to HDMI monitor

Finds faces (and eyes) in the webcam picture with OpenCV and shows the result on an HDMI
monitor, like the EDGE ZYNQ face detection demo video.

**You need**
* a USB webcam on the USB host connector **J3**, with jumpers **J6 and J7 fitted** (host mode)
* an HDMI monitor on the HDMI connector and/or a VGA monitor on connector P1 (both show the
  same picture; connect the monitor before you run this notebook)
"""),
    (M, "## 1. Load the overlay and start the HDMI output"),
    (C, """
from pynq.overlays.base import BaseOverlay
from pynq.lib.video import VideoMode, PIXEL_BGR
base = BaseOverlay("base.bit")

hdmi_out = base.video.hdmi_out
hdmi_out.configure(VideoMode(640, 480, 24), PIXEL_BGR)
hdmi_out.start();
"""),
    (M, "## 2. Open the webcam"),
    (C, """
import os
os.environ["OPENCV_LOG_LEVEL"] = "SILENT"
import cv2

cam = cv2.VideoCapture(0, cv2.CAP_V4L2)
cam.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cam.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
print("Webcam open:", cam.isOpened())
if not cam.isOpened():
    print("Check the webcam is on J3 and jumpers J6 and J7 are fitted, then run: !ls /dev/video*")

def grab():
    \"\"\"One webcam picture as 640x480 BGR (some webcams ignore the size request).\"\"\"
    ok, img = cam.read()
    if ok and img.shape[:2] != (480, 640):
        img = cv2.resize(img, (640, 480))
    return ok, img
"""),
    (M, "## 3. One picture: webcam to HDMI and to this notebook"),
    (C, """
ok, frame = grab()
if not ok:
    raise RuntimeError("could not read from the webcam")
out = hdmi_out.newframe()
out[:] = frame
hdmi_out.writeframe(out)

%matplotlib inline
from matplotlib import pyplot as plt
plt.imshow(frame[:, :, ::-1])
plt.axis("off")
plt.show()
"""),
    (M, "## 4. Face and eye detection on that picture"),
    (C, """
CASCADES = "/usr/share/opencv4/haarcascades/"          # trained face and eye detectors
if not os.path.isdir(CASCADES) and hasattr(cv2, "data"):   # pip builds of OpenCV keep them here
    CASCADES = cv2.data.haarcascades
face_cascade = cv2.CascadeClassifier(CASCADES + "haarcascade_frontalface_default.xml")
eye_cascade = cv2.CascadeClassifier(CASCADES + "haarcascade_eye.xml")
assert not face_cascade.empty() and not eye_cascade.empty(), "Haar cascade files not found"

def detect(img):
    \"\"\"Draw a blue box round each face and green boxes round the eyes; returns the face count.\"\"\"
    small = cv2.resize(img, (320, 240))                  # detect on a smaller picture: faster
    gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.2, 5, minSize=(30, 30))
    for (x, y, w, h) in faces:
        x, y, w, h = 2 * x, 2 * y, 2 * w, 2 * h
        cv2.rectangle(img, (x, y), (x + w, y + h), (255, 0, 0), 2)
        roi = cv2.cvtColor(img[y:y + h // 2 + h // 8, x:x + w], cv2.COLOR_BGR2GRAY)
        for (ex, ey, ew, eh) in eye_cascade.detectMultiScale(roi, 1.1, 6):
            cv2.rectangle(img, (x + ex, y + ey), (x + ex + ew, y + ey + eh), (0, 255, 0), 2)
    return len(faces)

n = detect(frame)
print(n, "face(s) found")
out = hdmi_out.newframe()
out[:] = frame
hdmi_out.writeframe(out)
plt.imshow(frame[:, :, ::-1])
plt.axis("off")
plt.show()
"""),
    (M, """
## 5. Live face detection

Runs until you press **push button 0** (SW7, the left button) or for 2 minutes. The 7-segment display shows the
number of faces found.
"""),
    (C, """
import time
frames, start = 0, time.time()
while time.time() - start < 120 and not base.buttons[0].read():
    ok, frame = grab()
    if not ok:
        continue
    n = detect(frame)
    base.seven_seg.show_number(n)
    out = hdmi_out.newframe()
    out[:] = frame
    hdmi_out.writeframe(out)
    frames += 1
print("{:.1f} frames per second".format(frames / (time.time() - start)))
"""),
    (M, "## 6. Release the webcam and stop the HDMI output"),
    (C, """
cam.release()
hdmi_out.close()
base.seven_seg.clear()
"""),
], prefix="f")

write("edge/7_opencv_edge_detection_webcam.ipynb", [
    (M, """
# OpenCV edge detection: USB webcam to HDMI monitor

Applies edge detection filters to the webcam picture and shows the result on an HDMI monitor,
like the EDGE ZYNQ edge detection demo video. The slide switches pick the filter while it runs.

**You need**
* a USB webcam on the USB host connector **J3**, with jumpers **J6 and J7 fitted** (host mode)
* an HDMI monitor on the HDMI connector and/or a VGA monitor on connector P1 (both show the
  same picture; connect the monitor before you run this notebook)
"""),
    (M, "## 1. Load the overlay, start the HDMI output and open the webcam"),
    (C, """
from pynq.overlays.base import BaseOverlay
from pynq.lib.video import VideoMode, PIXEL_BGR
import os
os.environ["OPENCV_LOG_LEVEL"] = "SILENT"
import cv2
import numpy as np

base = BaseOverlay("base.bit")
hdmi_out = base.video.hdmi_out
hdmi_out.configure(VideoMode(640, 480, 24), PIXEL_BGR)
hdmi_out.start();

cam = cv2.VideoCapture(0, cv2.CAP_V4L2)
cam.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cam.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
print("Webcam open:", cam.isOpened())

def grab():
    \"\"\"One webcam picture as 640x480 BGR (some webcams ignore the size request).\"\"\"
    ok, img = cam.read()
    if ok and img.shape[:2] != (480, 640):
        img = cv2.resize(img, (640, 480))
    return ok, img
"""),
    (M, "## 2. The filters"),
    (C, """
def laplacian(img):
    return cv2.Laplacian(img, cv2.CV_8U, ksize=3)

def canny(img):
    edges = cv2.Canny(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY), 100, 110)
    return cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)

def sobel(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gx = cv2.Sobel(gray, cv2.CV_16S, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_16S, 0, 1, ksize=3)
    mag = cv2.addWeighted(cv2.convertScaleAbs(gx), 0.5, cv2.convertScaleAbs(gy), 0.5, 0)
    return cv2.cvtColor(mag, cv2.COLOR_GRAY2BGR)

FILTERS = [("camera", lambda img: img), ("Laplacian", laplacian), ("Canny", canny), ("Sobel", sobel)]
"""),
    (M, "## 3. One picture with each filter"),
    (C, """
%matplotlib inline
from matplotlib import pyplot as plt
ok, frame = grab()
if not ok:
    raise RuntimeError("could not read from the webcam")
plt.figure(figsize=(12, 9))
for i, (name, f) in enumerate(FILTERS):
    plt.subplot(2, 2, i + 1)
    plt.imshow(f(frame.copy())[:, :, ::-1])
    plt.title(name)
    plt.axis("off")
plt.show()
"""),
    (M, """
## 4. Live edge detection on the HDMI monitor

The two left slide switches (switch 0 = SW6, switch 1 = SW4) pick the filter: 0 = camera,
1 = Laplacian, 2 = Canny, 3 = Sobel. The 7-segment display shows the frames per second.
Press **push button 0** (SW7, the left button) to stop
(it also stops after 2 minutes).
"""),
    (C, """
import time
frames, start, shown = 0, time.time(), time.time()
while time.time() - start < 120 and not base.buttons[0].read():
    ok, frame = grab()
    if not ok:
        continue
    name, f = FILTERS[base.switches.read() & 0x3]
    out = hdmi_out.newframe()
    out[:] = f(frame)
    hdmi_out.writeframe(out)
    frames += 1
    if time.time() - shown > 1:
        base.seven_seg.show_number(round(frames / (time.time() - start), 1))
        shown = time.time()
print("{:.1f} frames per second".format(frames / (time.time() - start)))
"""),
    (M, "## 5. Release the webcam and stop the HDMI output"),
    (C, """
cam.release()
hdmi_out.close()
base.seven_seg.clear()
"""),
], prefix="e")

print("notebooks written to", OUT)
