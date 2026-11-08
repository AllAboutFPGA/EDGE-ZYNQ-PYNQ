# EDGE ZYNQ: 4 LEDs and 4 slide switches (same pins as the base overlay)
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[0]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[1]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[2]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[3]}]
# switches and buttons numbered by position, left to right: SW6 SW4 SW3 SW8 (under D4-D7), buttons SW7 SW5
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[0]}]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[1]}]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[2]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[3]}]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
