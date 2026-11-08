"""Turn the PYNQ-Z2 v3.1.1 device tree into the EDGE ZYNQ one.

The EDGE ZYNQ board has the same processor I/O as the PYNQ-Z2 (UART0 on MIO 14/15, SD0 with
card detect on MIO 47, Ethernet on MIO 16-27 with MDIO on MIO 52/53, USB0 with reset on MIO 46,
QSPI, 512 MB DDR3) but a 33.333 MHz processor clock instead of 50 MHz, a different board
name, no audio codec, and the XADC is used from the PL (base overlay) instead of from Linux.

Usage: python3 make_edge_dtb.py <in.dtb> <out.dtb> [<out.dts for review>]
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from fdt import FDT  # noqa: E402

PS_CLK_HZ = 33333333
BOARD = "EDGE-ZYNQ"
MODEL = "EDGE ZYNQ SoC FPGA kit"


def edit(t, linux=False):
    root = t.root
    changes = []

    root.set("model", MODEL)
    changes.append("model")

    clkc = root.find("axi/slcr@f8000000/clkc@100")
    assert clkc is not None and clkc.u32("ps-clk-frequency") == 50000000, "clkc not as expected"
    clkc.set("ps-clk-frequency", PS_CLK_HZ)
    changes.append("ps-clk-frequency 50 MHz -> 33.333 MHz")

    chosen = root.child("chosen")
    assert chosen.str("pynq_board") == "Pynq-Z2"
    chosen.set("pynq_board", BOARD)
    changes.append("pynq_board")

    # XADC: the base overlay uses it through the PL (AXI XADC Wizard). The Linux PS-XADC driver
    # would switch the XADC to the PS-XADC interface and block the PL access.
    adc = root.find("axi/adc@f8007100")
    adc.set("status", "disabled")
    changes.append("PS XADC driver off")

    # PYNQ-Z2 audio codec UIO node: no codec on the EDGE board (0x43C00000 is the XADC here)
    if root.child("audio-codec-ctrl@43c00000") is not None:
        root.remove_child("audio-codec-ctrl@43c00000")
        sym = root.child("__symbols__")
        if sym is not None:
            sym.props = [p for p in sym.props if b"audio-codec" not in p[1]]
        changes.append("audio codec node removed")

    # Ethernet: the EDGE processor settings have no Ethernet reset pin (PCW_ENET0_RESET_ENABLE 0),
    # so the PYNQ-Z2's MIO 9 reset reference is removed.
    # The PHY address is not given, so the driver scans MDIO: this works for the RTL8211E
    # (V1/V2 boards) and the RTL8211F (V3 board); phy-mode rgmii-id turns on the RTL8211F
    # internal RGMII delays, like the EDGE bare-metal Ethernet example does.
    gem0 = root.find("axi/ethernet@e000b000")
    gem0.delete("enet-reset")
    assert gem0.str("phy-mode") == "rgmii-id" and not gem0.has("phy-handle")
    changes.append("gem0 enet-reset removed")

    # microSD: no write-protect switch is used
    sd0 = root.find("axi/mmc@e0100000")
    sd0.set("disable-wp", b"")
    changes.append("sd0 disable-wp")

    if linux:
        # USB 0 as a host (connector J3, jumpers J6 and J7 fitted), for webcams, keyboards
        # and memory sticks; without this the controller picks its role from the ID pin
        usb0 = root.find("axi/usb@e0002000")
        usb0.set("dr_mode", "host")
        changes.append("USB0 host mode")

        # PS LED D1 on MIO 9 (active high): Linux heartbeat, so you can see that Linux runs
        gpio0 = root.find("axi/gpio@e000a000")
        ph = gpio0.u32("phandle")
        leds = root.add_child("leds")
        leds.set("compatible", "gpio-leds")
        led = leds.add_child("ps-led")
        led.set("label", "ps_led_d1")
        led.set("gpios", [ph, 9, 0])
        led.set("linux,default-trigger", "heartbeat")
        changes.append("PS LED D1 (MIO 9) heartbeat")
    return changes


if __name__ == "__main__":
    linux = "--linux" in sys.argv
    sys.argv = [a for a in sys.argv if a != "--linux"]
    t = FDT.parse(open(sys.argv[1], "rb").read())
    ch = edit(t, linux=linux)
    open(sys.argv[2], "wb").write(t.to_blob(pad=4096))
    if len(sys.argv) > 3:
        open(sys.argv[3], "w").write(t.to_dts())
    print("; ".join(ch))
