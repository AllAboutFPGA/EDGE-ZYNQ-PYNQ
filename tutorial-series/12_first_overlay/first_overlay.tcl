# Episode 12: your first custom overlay - the processor and one AXI GPIO block
# (channel 1: the 4 LEDs as outputs, channel 2: the 4 slide switches as inputs).
#
#   vivado -mode batch -source first_overlay.tcl -tclargs <part> <work dir> <output dir>
#   part: xc7z010clg400-1 (EDGE Z7-10) or xc7z020clg400-1 (EDGE Z7-20)
# Output: first_overlay.bit and first_overlay.hwh in <output dir> (the .xsa stays in <work dir>)
set part   [lindex $argv 0]
set work   [file normalize [lindex $argv 1]]
set outdir [file normalize [lindex $argv 2]]
set here   [file dirname [file normalize [info script]]]
source $here/../common/overlay_lib.tcl

edge_project first_overlay $part $work {} [list $here/first_overlay.xdc]
set ps [edge_ps7]

# one AXI GPIO with two channels
set gpio [create_bd_cell -type ip -vlnv [ipv axi_gpio] gpio_led_sw]
set_property -dict [list CONFIG.C_IS_DUAL 1 \
    CONFIG.C_GPIO_WIDTH 4  CONFIG.C_ALL_OUTPUTS 1 \
    CONFIG.C_GPIO2_WIDTH 4 CONFIG.C_ALL_INPUTS_2 1] $gpio

create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 leds
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 sws
connect_bd_intf_net [get_bd_intf_pins $gpio/GPIO]  [get_bd_intf_ports leds]
connect_bd_intf_net [get_bd_intf_pins $gpio/GPIO2] [get_bd_intf_ports sws]

edge_axi_lite [list gpio_led_sw]
edge_clock_cells [list gpio_led_sw]
assign_bd_address -offset 0x41200000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs -of_objects [get_bd_cells gpio_led_sw]] -force

edge_build first_overlay $outdir
exit 0
