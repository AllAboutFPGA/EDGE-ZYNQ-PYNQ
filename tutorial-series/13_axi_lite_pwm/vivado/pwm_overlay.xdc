# EDGE ZYNQ: PWM outputs on the 4 LEDs, slide switches, push buttons
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {leds[0]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {leds[1]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {leds[2]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {leds[3]}]
# switches and buttons numbered by position, left to right: SW6 SW4 SW3 SW8 (under D4-D7), buttons SW7 SW5
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[0]}]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[1]}]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[2]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[3]}]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btns_tri_i[0]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btns_tri_i[1]}]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
