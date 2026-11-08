# EDGE ZYNQ SoC FPGA kit: PYNQ base overlay
# Invent Logics / allaboutfpga.com
# SPDX-License-Identifier: BSD-3-Clause
"""Base overlay for the EDGE ZYNQ SoC FPGA kit (XC7Z010 and XC7Z020 boards).

    from pynq.overlays.base import BaseOverlay
    base = BaseOverlay("base.bit")

    base.leds[0].on()                  # LED D4
    base.switches.read()               # 4 slide switches, bit 0 = SW6 (leftmost)
    base.buttons[0].read()             # push buttons (0 = SW7 left, 1 = SW5 right)
    base.seven_seg.show_number(42.5)   # 4-digit 7-segment display
    base.buzzer.beep(1000, 0.2)        # buzzer (fit jumper J10 pins 1-2)
    base.xadc.temperature()            # Zynq die temperature in degC
    base.xadc.lm35_celsius()           # LM35 on J15 (jumper J15 pins 3-5)

    from pynq.lib.video import VideoMode, PIXEL_BGR
    hdmi_out = base.video.hdmi_out     # HDMI output, same API as the PYNQ-Z2 base overlay
    hdmi_out.configure(VideoMode(640, 480, 24), PIXEL_BGR)
    hdmi_out.start()
    frame = hdmi_out.newframe(); frame[:] = 255; hdmi_out.writeframe(frame)
"""
import time

import pynq

PS_CLK_MHZ = 33.333333      # processor reference clock of the EDGE ZYNQ board
FCLK0_HZ = 100_000_000      # PL clock used by the 7-segment and buzzer logic
J15_DIVIDER = 3.32          # J15 analog inputs: 2.32 kOhm / 1 kOhm divider in front of the XADC

# 7-segment font: bit 0 = a, 1 = b, 2 = c, 3 = d, 4 = e, 5 = f, 6 = g, 7 = dp
FONT = {
    "0": 0x3F, "1": 0x06, "2": 0x5B, "3": 0x4F, "4": 0x66, "5": 0x6D, "6": 0x7D,
    "7": 0x07, "8": 0x7F, "9": 0x6F, "A": 0x77, "B": 0x7C, "C": 0x39, "D": 0x5E,
    "E": 0x79, "F": 0x71, "G": 0x3D, "H": 0x76, "I": 0x30, "J": 0x1E, "L": 0x38,
    "N": 0x54, "O": 0x3F, "P": 0x73, "Q": 0x67, "R": 0x50, "S": 0x6D, "T": 0x78,
    "U": 0x3E, "Y": 0x6E, "b": 0x7C, "c": 0x58, "d": 0x5E, "h": 0x74, "n": 0x54,
    "o": 0x5C, "r": 0x50, "t": 0x78, "u": 0x1C, "-": 0x40, "_": 0x08, "=": 0x48,
    " ": 0x00, "'": 0x02, "\"": 0x22, "°": 0x63,
}


def board_variant():
    """Return 'EDGE-Z10' or 'EDGE-Z20' from the Zynq device code (SLCR PSS_IDCODE)."""
    idcode = pynq.MMIO(0xF8000000, 0x1000).read(0x530)
    return {0x02: "EDGE-Z10", 0x07: "EDGE-Z20"}.get((idcode >> 12) & 0x1F, "unknown")


def set_ps_clock_reference(mhz=PS_CLK_MHZ):
    """Tell pynq.Clocks that this board's processor clock is 33.333 MHz.

    PYNQ assumes 50 MHz on Zynq-7000 boards, which makes pynq.Clocks report
    (and set) wrong frequencies. Loading an overlay is not affected: it writes
    the PL clock dividers from the .hwh file.
    """
    try:
        from pynq.ps import Clocks
        Clocks._instance._ref_clk_mhz = mhz
    except Exception:       # not on a board, or a different PYNQ version
        pass


class SevenSegment:
    """The 4-digit 7-segment display (common anode, multiplexed in the PL)."""

    def __init__(self, gpio):
        self._ip = gpio          # AXI GPIO: channel 1 = control, channel 2 = raw segments
        self.clear()

    def _write(self, ctrl, raw=0):
        self._ip.write(0x8, raw & 0xFFFFFFFF)
        self._ip.write(0x0, ctrl & 0xFFFFFFFF)

    def clear(self):
        """Turn all four digits off."""
        self._write(0)

    def show_hex(self, value, dots=0):
        """Show a 16-bit value as 4 hex digits. dots: 4-bit mask, bit 3 = leftmost digit."""
        self._write((0xF << 20) | ((dots & 0xF) << 16) | (value & 0xFFFF))

    def show_segments(self, patterns):
        """Show raw segment patterns, leftmost digit first (bit 0 = a ... bit 7 = dp)."""
        p = (list(patterns) + [0, 0, 0, 0])[:4]
        raw = (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]
        self._write((1 << 24) | (0xF << 20), raw)

    def show_text(self, text, align="right"):
        """Show up to 4 characters; a '.' lights the decimal point of the character before it."""
        cells = []
        for ch in str(text):
            if ch == "." and cells and not cells[-1] & 0x80:
                cells[-1] |= 0x80
                continue
            if ch == ".":
                cells.append(0x80)
                continue
            seg = FONT.get(ch, FONT.get(ch.upper(), FONT.get(ch.lower(), 0x00)))
            cells.append(seg)
        if len(cells) > 4:
            cells = cells[:4]
        pad = [0] * (4 - len(cells))
        cells = pad + cells if align == "right" else cells + pad
        self.show_segments(cells)

    def show_number(self, value, decimals=None):
        """Show a number (right aligned). decimals=None picks as many as fit."""
        if isinstance(value, int) and decimals is None:
            s = str(value)
        else:
            s = None
            for d in ([decimals] if decimals is not None else [3, 2, 1, 0]):
                t = "%.*f" % (d, value)
                if len(t.replace(".", "")) <= 4:
                    s = t
                    break
            if s is None:
                s = "%.0f" % value
        if len(s.replace(".", "")) > 4:
            s = "----"
        self.show_text(s)


class Buzzer:
    """The buzzer (fit the jumper on J10 pins 1-2 to enable it)."""

    def __init__(self, gpio):
        self._ip = gpio
        self.off()

    def tone(self, freq_hz):
        """Start a square wave of freq_hz (20 Hz - 20 kHz)."""
        half = int(round(FCLK0_HZ / (2.0 * float(freq_hz))))
        if not 2 <= half < (1 << 31):
            raise ValueError("frequency out of range")
        self._ip.write(0x0, (1 << 31) | half)

    def off(self):
        self._ip.write(0x0, 0)

    def beep(self, freq_hz=2000, seconds=0.2):
        self.tone(freq_hz)
        time.sleep(seconds)
        self.off()

    def play(self, notes, gap=0.03):
        """Play a list of (frequency in Hz or 0 for a rest, seconds)."""
        for f, s in notes:
            if f:
                self.tone(f)
            else:
                self.off()
            time.sleep(s)
            self.off()
            time.sleep(gap)


class XADC:
    """XADC (AXI XADC Wizard): die temperature, supplies and the two J15 inputs."""

    TEMP, VCCINT, VCCAUX = 0x200, 0x204, 0x208
    VAUX_BASE = 0x240

    def __init__(self, ip):
        self._ip = ip

    def _raw(self, off):
        return self._ip.read(off) & 0xFFFF          # 12-bit result in bits 15:4

    def temperature(self):
        """Zynq die temperature in degC."""
        return self._raw(self.TEMP) * 503.975 / 65536.0 - 273.15

    def vccint(self):
        return self._raw(self.VCCINT) * 3.0 / 65536.0

    def vccaux(self):
        return self._raw(self.VCCAUX) * 3.0 / 65536.0

    def vaux(self, channel):
        """Voltage at the XADC auxiliary input (0-1 V)."""
        return self._raw(self.VAUX_BASE + 4 * channel) / 65536.0

    def j15_voltage(self, pin):
        """Voltage on J15 pin 3 (VAUX2) or pin 4 (VAUX10), 0-3.3 V."""
        ch = {3: 2, 4: 10}[pin]
        return self.vaux(ch) * J15_DIVIDER

    def lm35_celsius(self):
        """LM35 temperature (fit a jumper between J15 pins 3 and 5)."""
        return self.j15_voltage(3) * 100.0

    def light_level(self):
        """LDR light sensor voltage, rises with light (jumper between J15 pins 4 and 6)."""
        return self.j15_voltage(4)


class BaseOverlay(pynq.Overlay):
    """The base overlay for the EDGE ZYNQ SoC FPGA kit.

    Attributes
    ----------
    leds : AxiGPIO channel, 4 outputs (LEDs D4-D7)
    switches : AxiGPIO channel, 4 inputs (SW6, SW4, SW3, SW8: left to right, under D4-D7)
    buttons : AxiGPIO channel, 2 inputs (SW7 left = 0, SW5 right = 1), with interrupts
    seven_seg : SevenSegment
    buzzer : Buzzer
    xadc : XADC
    video : the HDMI output pipeline (the same picture also goes to the VGA connector P1);
        video.hdmi_out is a pynq.lib.video.VideoOut
        (640x480, 800x600, 1280x720, 1280x1024 or 1920x1080)
    """

    def __init__(self, bitfile="base.bit", **kwargs):
        super().__init__(bitfile, **kwargs)
        set_ps_clock_reference()
        if self.is_loaded():
            self.leds = self.leds_gpio.channel1
            self.leds.setlength(4)
            self.leds.setdirection("out")
            self.switches = self.switches_gpio.channel1
            self.switches.setlength(4)
            self.switches.setdirection("in")
            self.buttons = self.btns_gpio.channel1
            self.buttons.setlength(2)
            self.buttons.setdirection("in")
            self.seven_seg = SevenSegment(self.seg7_gpio)
            self.buzzer = Buzzer(self.buzzer_gpio)
            self.xadc = XADC(self.xadc_wiz_0)
            # HDMI output: PYNQ connects the output pipeline to its video DMA in a wrapper
            # that also needs an HDMI input, which this board's single HDMI port does not have
            # at the same time, so connect them here.
            try:
                self.video.hdmi_out._vdma = self.video.axi_vdma
            except Exception as e:  # noqa: BLE001  - keep the rest of the overlay usable
                import warnings
                warnings.warn("HDMI output not available: %r" % (e,))
