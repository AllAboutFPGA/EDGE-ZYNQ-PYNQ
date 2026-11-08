# Episodes 13-14: the edge_pwm Verilog block (4 PWM outputs to the LEDs) on AXI-Lite,
# plus an AXI GPIO for the slide switches (channel 1) and push buttons (channel 2).
#
#   vivado -mode batch -source pwm_overlay.tcl -tclargs <part> <work dir> <output dir>
# Output: pwm_overlay.bit and pwm_overlay.hwh in <output dir> (the .xsa stays in <work dir>)
set part   [lindex $argv 0]
set work   [file normalize [lindex $argv 1]]
set outdir [file normalize [lindex $argv 2]]
set here   [file dirname [file normalize [info script]]]
source $here/../../common/overlay_lib.tcl

edge_project pwm_overlay $part $work [list $here/../hdl/edge_pwm.v] [list $here/pwm_overlay.xdc]
set ps [edge_ps7]

# the Verilog block, added straight from the source file (a "module reference")
set pwm [create_bd_cell -type module -reference edge_pwm pwm_0]
create_bd_port -dir O -from 3 -to 0 leds
connect_bd_net [get_bd_pins $pwm/pwm] [get_bd_ports leds]

set gpio [create_bd_cell -type ip -vlnv [ipv axi_gpio] inputs_gpio]
set_property -dict [list CONFIG.C_IS_DUAL 1 \
    CONFIG.C_GPIO_WIDTH 4  CONFIG.C_ALL_INPUTS 1 \
    CONFIG.C_GPIO2_WIDTH 2 CONFIG.C_ALL_INPUTS_2 1] $gpio
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 sws
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 btns
connect_bd_intf_net [get_bd_intf_pins $gpio/GPIO]  [get_bd_intf_ports sws]
connect_bd_intf_net [get_bd_intf_pins $gpio/GPIO2] [get_bd_intf_ports btns]

edge_axi_lite [list pwm_0 inputs_gpio]
edge_clock_cells [list pwm_0 inputs_gpio]
set space [get_bd_addr_spaces processing_system7_0/Data]
assign_bd_address -offset 0x43C00000 -range 0x00010000 -target_address_space $space \
    [get_bd_addr_segs -of_objects [get_bd_cells pwm_0]] -force
assign_bd_address -offset 0x41200000 -range 0x00010000 -target_address_space $space \
    [get_bd_addr_segs -of_objects [get_bd_cells inputs_gpio]] -force

edge_build pwm_overlay $outdir
exit 0
