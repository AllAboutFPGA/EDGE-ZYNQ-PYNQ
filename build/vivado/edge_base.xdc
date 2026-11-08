# EDGE ZYNQ PYNQ base overlay pins (same for XC7Z010 and XC7Z020 boards)
# Pins follow the EDGE board file (edgeZ7_10 / edgeZ7_20) and the EDGE ZYNQ examples.

# LEDs D4..D7, left to right (bit 0 = D4, R16)
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[0]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[1]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[2]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[3]}]

# Slide switches, numbered by position on the board so each one sits under its LED:
# left to right they are SW6, SW4, SW3, SW8 (bit 0 = SW6 under D4 ... bit 3 = SW8 under D7).
# The EDGE_ZYNQ_Master.xdc numbers them by reference (sw[0] = SW3 W19, sw[1] = SW4 N17,
# sw[2] = SW6 P18, sw[3] = SW8 P15), so bits 0 and 2 are swapped compared with that file.
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[0]}]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[1]}]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[2]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[3]}]

# Push buttons (active high, with pull-downs), numbered by position: left to right SW7, SW5
# (bit 0 = SW7 W15, bit 1 = SW5 V15; the EDGE_ZYNQ_Master.xdc has pb[0] = SW5, pb[1] = SW7)
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btns_tri_i[0]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btns_tri_i[1]}]

# 7-segment display: digit enables (active high, an[0] = leftmost digit)
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS33} [get_ports {seg7_an[0]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {seg7_an[1]}]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports {seg7_an[2]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {seg7_an[3]}]
# segments (active low): a b c d e f g dp
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[0]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[1]}]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[2]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[3]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[4]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[5]}]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[6]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {seg7_seg_n[7]}]

# Buzzer
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports buzzer]

# XADC auxiliary inputs on J15 (VAUX2 and VAUX10)
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports Vaux2_v_p]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports Vaux2_v_n]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports Vaux10_v_p]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports Vaux10_v_n]

# HDMI output on connector U11 (TMDS_33): lane 0 = blue, 1 = green, 2 = red
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports HDMI_OUT_clk_p]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports HDMI_OUT_clk_n]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD TMDS_33} [get_ports {HDMI_OUT_data_p[0]}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD TMDS_33} [get_ports {HDMI_OUT_data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {HDMI_OUT_data_p[1]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {HDMI_OUT_data_n[1]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports {HDMI_OUT_data_p[2]}]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports {HDMI_OUT_data_n[2]}]
# HDMI_OUT_EN high: the port is an output and the connector gets its 5 V
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports hdmi_out_en]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# VGA on connector P1 (12-bit resistor DAC): the HDMI picture, from hdl/edge_vga.v
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVCMOS33} [get_ports vga_hs]
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS33} [get_ports vga_vs]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {vga_r[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {vga_r[1]}]
set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS33} [get_ports {vga_r[2]}]
set_property -dict {PACKAGE_PIN F17 IOSTANDARD LVCMOS33} [get_ports {vga_r[3]}]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports {vga_g[0]}]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {vga_g[1]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {vga_g[2]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {vga_g[3]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33} [get_ports {vga_b[0]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports {vga_b[1]}]
set_property -dict {PACKAGE_PIN B19 IOSTANDARD LVCMOS33} [get_ports {vga_b[2]}]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports {vga_b[3]}]
set_property IOB TRUE [get_ports {vga_r[*] vga_g[*] vga_b[*] vga_hs vga_vs}]
