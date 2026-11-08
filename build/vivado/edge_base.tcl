# Build the EDGE ZYNQ PYNQ base overlay (Vivado 2022.2, batch mode)
# Invent Logics / allaboutfpga.com
#
#   vivado -mode batch -source edge_base.tcl -tclargs <part> <work dir> <output dir> <PYNQ ip dir>
#   part: xc7z010clg400-1 (EDGE Z7-10) or xc7z020clg400-1 (EDGE Z7-20)
#   PYNQ ip dir: PYNQ's boards/ip folder (axi_dynclk, rgb2dvi, color_swap, tmds interface)
#                with the HLS color_convert and pixel_unpack IP built (hls/*/solution1/impl/ip)
#
# Output: base.bit, base.hwh (for PYNQ) and base.xsa (for the FSBL).
#
# HDMI output uses the same video pipeline and names as the PYNQ-Z2 base overlay
# (video/axi_vdma -> video/hdmi_out/{pixel_unpack, color_convert, frontend}), so PYNQ's
# pynq.lib.video drivers (HDMIOut, VideoMode, newframe/writeframe) work unchanged.
# The same picture also goes to the 12-bit VGA connector P1 (hdl/edge_vga.v).

set part   [lindex $argv 0]
set work   [file normalize [lindex $argv 1]]
set outdir [file normalize [lindex $argv 2]]
set ipdir  [file normalize [lindex $argv 3]]
set here   [file dirname [file normalize [info script]]]
file mkdir $work $outdir

proc ipv {name {vendor xilinx.com:ip}} {
    set d [lindex [lsort [get_ipdefs -all ${vendor}:${name}:*]] end]
    if {$d eq ""} { error "IP $vendor:$name not found" }
    return $d
}
proc try_set {cell dict} {
    foreach {k v} $dict {
        if {[catch {set_property $k $v [get_bd_cells $cell]} e]} { puts "EDGE_WARN $cell $k: $e" }
    }
}

create_project -force base $work -part $part
set_property target_language Verilog [current_project]
set_property ip_repo_paths [list $ipdir] [current_project]
update_ip_catalog
add_files -norecurse [glob $here/hdl/*.v]
add_files -fileset constrs_1 -norecurse $here/edge_base.xdc
update_compile_order -fileset sources_1

create_bd_design base

# ---------------------------------------------------------------- processing system
source $here/ps7_config.tcl
# video: 142 MHz stream clock (FCLK1) and the HP0 port for the video DMA, as on the PYNQ-Z2
lappend edge_ps7_config CONFIG.PCW_EN_CLK1_PORT 1 CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 142 \
    CONFIG.PCW_USE_S_AXI_HP0 1 CONFIG.PCW_S_AXI_HP0_DATA_WIDTH 64
set ps [create_bd_cell -type ip -vlnv [ipv processing_system7] processing_system7_0]
# all at once, like a board preset (Vivado resolves the dependencies between the settings)
if {[catch {set_property -dict $edge_ps7_config $ps} e]} {
    puts "EDGE_WARN ps7 settings as one set failed ($e), setting them one by one"
    for {set pass 0} {$pass < 3} {incr pass} {
        set nbad 0
        foreach {k v} $edge_ps7_config { if {[catch {set_property $k $v $ps}]} { incr nbad } }
    }
    puts "EDGE_PS7 settings not accepted: $nbad"
}
foreach k {PCW_CRYSTAL_PERIPHERAL_FREQMHZ PCW_UIPARAM_DDR_PARTNO PCW_UIPARAM_DDR_BUS_WIDTH PCW_UIPARAM_DDR_FREQ_MHZ
           PCW_UART0_PERIPHERAL_ENABLE PCW_UART0_UART0_IO PCW_SD0_PERIPHERAL_ENABLE PCW_SD0_GRP_CD_IO
           PCW_SD0_GRP_WP_ENABLE PCW_ENET0_PERIPHERAL_ENABLE PCW_ENET0_ENET0_IO PCW_ENET0_GRP_MDIO_IO
           PCW_USB0_PERIPHERAL_ENABLE PCW_USB0_RESET_IO PCW_QSPI_PERIPHERAL_ENABLE PCW_PRESET_BANK1_VOLTAGE
           PCW_FPGA0_PERIPHERAL_FREQMHZ PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ PCW_APU_PERIPHERAL_FREQMHZ
           PCW_USE_M_AXI_GP0 PCW_USE_FABRIC_INTERRUPT PCW_IRQ_F2P_INTR
           PCW_FPGA1_PERIPHERAL_FREQMHZ PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ PCW_USE_S_AXI_HP0} {
    puts "EDGE_PS7 $k = [get_property CONFIG.$k $ps]"
}
make_bd_intf_pins_external [get_bd_intf_pins $ps/DDR] [get_bd_intf_pins $ps/FIXED_IO]
set_property name DDR [get_bd_intf_ports DDR_0]
set_property name FIXED_IO [get_bd_intf_ports FIXED_IO_0]

set rst [create_bd_cell -type ip -vlnv [ipv proc_sys_reset] rst_ps7_0_100M]
connect_bd_net [get_bd_pins $ps/FCLK_CLK0] [get_bd_pins $rst/slowest_sync_clk]
connect_bd_net [get_bd_pins $ps/FCLK_RESET0_N] [get_bd_pins $rst/ext_reset_in]
set rst142 [create_bd_cell -type ip -vlnv [ipv proc_sys_reset] rst_ps7_0_142M]
connect_bd_net [get_bd_pins $ps/FCLK_CLK1] [get_bd_pins $rst142/slowest_sync_clk]
connect_bd_net [get_bd_pins $ps/FCLK_RESET0_N] [get_bd_pins $rst142/ext_reset_in]

# ---------------------------------------------------------------- peripherals
set leds [create_bd_cell -type ip -vlnv [ipv axi_gpio] leds_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 4 CONFIG.C_ALL_OUTPUTS 1] $leds
set sws [create_bd_cell -type ip -vlnv [ipv axi_gpio] switches_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 4 CONFIG.C_ALL_INPUTS 1 CONFIG.C_INTERRUPT_PRESENT 1] $sws
set btns [create_bd_cell -type ip -vlnv [ipv axi_gpio] btns_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 2 CONFIG.C_ALL_INPUTS 1 CONFIG.C_INTERRUPT_PRESENT 1] $btns
set s7g [create_bd_cell -type ip -vlnv [ipv axi_gpio] seg7_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 32 CONFIG.C_ALL_OUTPUTS 1 CONFIG.C_IS_DUAL 1 \
                         CONFIG.C_GPIO2_WIDTH 32 CONFIG.C_ALL_OUTPUTS_2 1] $s7g
set bzg [create_bd_cell -type ip -vlnv [ipv axi_gpio] buzzer_gpio]
set_property -dict [list CONFIG.C_GPIO_WIDTH 32 CONFIG.C_ALL_OUTPUTS 1] $bzg

set xadc [create_bd_cell -type ip -vlnv [ipv xadc_wiz] xadc_wiz_0]
try_set xadc_wiz_0 [list CONFIG.INTERFACE_SELECTION Enable_AXI \
    CONFIG.XADC_STARUP_SELECTION channel_sequencer CONFIG.SEQUENCER_MODE Continuous \
    CONFIG.ENABLE_RESET false CONFIG.OT_ALARM false CONFIG.USER_TEMP_ALARM false \
    CONFIG.VCCINT_ALARM false CONFIG.VCCAUX_ALARM false CONFIG.ENABLE_VCCPINT_ALARM false \
    CONFIG.ENABLE_VCCPAUX_ALARM false CONFIG.ENABLE_VCCDDRO_ALARM false \
    CONFIG.CHANNEL_ENABLE_TEMPERATURE true CONFIG.CHANNEL_ENABLE_VCCINT true \
    CONFIG.CHANNEL_ENABLE_VCCAUX true CONFIG.CHANNEL_ENABLE_VP_VN false \
    CONFIG.CHANNEL_ENABLE_VAUXP2_VAUXN2 true CONFIG.CHANNEL_ENABLE_VAUXP10_VAUXN10 true \
    CONFIG.CHANNEL_AVERAGING 16]

set seg7 [create_bd_cell -type module -reference edge_seg7 seg7_0]
set tone [create_bd_cell -type module -reference edge_tone tone_0]

# ---------------------------------------------------------------- HDMI output (PYNQ-Z2 structure)
create_bd_cell -type hier video
current_bd_instance /video
set vdma [create_bd_cell -type ip -vlnv [ipv axi_vdma] axi_vdma]
set_property -dict [list CONFIG.c_include_s2mm 0 CONFIG.c_m_axi_mm2s_data_width 32 \
    CONFIG.c_m_axis_mm2s_tdata_width 32 CONFIG.c_mm2s_genlock_mode 1 CONFIG.c_mm2s_linebuffer_depth 512 \
    CONFIG.c_mm2s_max_burst_length 32 CONFIG.c_num_fstores 4] $vdma
create_bd_cell -type hier hdmi_out
current_bd_instance /video/hdmi_out
set punpack [create_bd_cell -type ip -vlnv [ipv pixel_unpack xilinx.com:hls] pixel_unpack]
set slice [create_bd_cell -type ip -vlnv [ipv axis_register_slice] axis_register_slice_0]
set_property CONFIG.TUSER_WIDTH 1 $slice
set cconv [create_bd_cell -type ip -vlnv [ipv color_convert xilinx.com:hls] color_convert]
create_bd_cell -type hier frontend
current_bd_instance /video/hdmi_out/frontend
set dynclk [create_bd_cell -type ip -vlnv [ipv axi_dynclk digilentinc.com:ip] axi_dynclk]
set cswap [create_bd_cell -type ip -vlnv [ipv color_swap xilinx.com:user] color_swap_0]
set r2d [create_bd_cell -type ip -vlnv [ipv rgb2dvi digilentinc.com:ip] rgb2dvi_0]
set_property -dict [list CONFIG.kClkRange 2 CONFIG.kGenerateSerialClk false CONFIG.kRstActiveHigh false] $r2d
set vout [create_bd_cell -type ip -vlnv [ipv v_axi4s_vid_out] v_axi4s_vid_out_0]
set_property -dict [list CONFIG.C_ADDR_WIDTH 11 CONFIG.C_HAS_ASYNC_CLK 1 CONFIG.C_HYSTERESIS_LEVEL 1024 \
    CONFIG.C_VTG_MASTER_SLAVE 1] $vout
set vtc [create_bd_cell -type ip -vlnv [ipv v_tc] vtc_out]
set_property -dict [list CONFIG.enable_detection false] $vtc
set vga [create_bd_cell -type module -reference edge_vga vga_out]
current_bd_instance /
# stream path
connect_bd_intf_net [get_bd_intf_pins video/axi_vdma/M_AXIS_MM2S] [get_bd_intf_pins video/hdmi_out/pixel_unpack/stream_in_32]
connect_bd_intf_net [get_bd_intf_pins video/hdmi_out/pixel_unpack/stream_out_24] [get_bd_intf_pins video/hdmi_out/axis_register_slice_0/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins video/hdmi_out/axis_register_slice_0/M_AXIS] [get_bd_intf_pins video/hdmi_out/color_convert/stream_in_24]
connect_bd_intf_net [get_bd_intf_pins video/hdmi_out/color_convert/stream_out_24] [get_bd_intf_pins video/hdmi_out/frontend/v_axi4s_vid_out_0/video_in]
connect_bd_intf_net [get_bd_intf_pins video/hdmi_out/frontend/vtc_out/vtiming_out] [get_bd_intf_pins video/hdmi_out/frontend/v_axi4s_vid_out_0/vtiming_in]
connect_bd_intf_net [get_bd_intf_pins video/hdmi_out/frontend/v_axi4s_vid_out_0/vid_io_out] [get_bd_intf_pins video/hdmi_out/frontend/color_swap_0/pixel_input]
# colour-swapped pixels to the HDMI encoder and, on the same nets, to the VGA output
set fe video/hdmi_out/frontend
foreach {src hdmi v} {pixel_out vid_pData pixel  vde_out vid_pVDE vde  hsync_out vid_pHSync hsync  vsync_out vid_pVSync vsync} {
    connect_bd_net [get_bd_pins $fe/color_swap_0/$src] [get_bd_pins $fe/rgb2dvi_0/$hdmi] [get_bd_pins $fe/vga_out/$v]
}
# pixel clock from the dynamic clock generator (100 MHz reference)
set pxclk [get_bd_pins video/hdmi_out/frontend/axi_dynclk/PXL_CLK_O]
connect_bd_net $pxclk [get_bd_pins video/hdmi_out/frontend/rgb2dvi_0/PixelClk] \
    [get_bd_pins video/hdmi_out/frontend/v_axi4s_vid_out_0/vid_io_out_clk] [get_bd_pins video/hdmi_out/frontend/vtc_out/clk] \
    [get_bd_pins video/hdmi_out/frontend/vga_out/clk]
connect_bd_net [get_bd_pins video/hdmi_out/frontend/axi_dynclk/PXL_CLK_5X_O] [get_bd_pins video/hdmi_out/frontend/rgb2dvi_0/SerialClk]
connect_bd_net [get_bd_pins video/hdmi_out/frontend/axi_dynclk/LOCKED_O] [get_bd_pins video/hdmi_out/frontend/rgb2dvi_0/aRst_n]
# HDMI pins: TMDS out, and HDMI_OUT_EN high (port as output, 5 V to the connector, HPD as input)
create_bd_intf_port -mode Master -vlnv digilentinc.com:interface:tmds_rtl:1.0 HDMI_OUT
connect_bd_intf_net [get_bd_intf_pins video/hdmi_out/frontend/rgb2dvi_0/TMDS] [get_bd_intf_ports HDMI_OUT]
set one [create_bd_cell -type ip -vlnv [ipv xlconstant] hdmi_out_en_const]
set_property -dict [list CONFIG.CONST_VAL 1 CONFIG.CONST_WIDTH 1] $one
create_bd_port -dir O hdmi_out_en
connect_bd_net [get_bd_pins $one/dout] [get_bd_ports hdmi_out_en]
# VGA pins (connector P1): the HDMI picture, 4 bits per colour
foreach {name width} {vga_r 4 vga_g 4 vga_b 4} {
    create_bd_port -dir O -from [expr {$width - 1}] -to 0 $name
    connect_bd_net [get_bd_pins video/hdmi_out/frontend/vga_out/$name] [get_bd_ports $name]
}
foreach name {vga_hs vga_vs} {
    create_bd_port -dir O $name
    connect_bd_net [get_bd_pins video/hdmi_out/frontend/vga_out/$name] [get_bd_ports $name]
}
# video DMA to DDR through HP0
set hpic [create_bd_cell -type ip -vlnv [ipv axi_interconnect] axi_mem_intercon]
set_property -dict [list CONFIG.NUM_SI 1 CONFIG.NUM_MI 1] $hpic
connect_bd_intf_net [get_bd_intf_pins video/axi_vdma/M_AXI_MM2S] [get_bd_intf_pins $hpic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $hpic/M00_AXI] [get_bd_intf_pins $ps/S_AXI_HP0]

set cat [create_bd_cell -type ip -vlnv [ipv xlconcat] irq_concat]
set_property CONFIG.NUM_PORTS 3 $cat
set intc [create_bd_cell -type ip -vlnv [ipv axi_intc] system_interrupts]

# ---------------------------------------------------------------- AXI
set ic [create_bd_cell -type ip -vlnv [ipv axi_interconnect] ps7_0_axi_periph]
set slaves [list $leds $sws $btns $s7g $bzg $xadc $intc]
# video register ports: {AXI-Lite pin, clock domain (100 or 142 MHz)}
set vslaves [list \
    video/axi_vdma/S_AXI_LITE 100 \
    video/hdmi_out/pixel_unpack/s_axi_control 142 \
    video/hdmi_out/color_convert/s_axi_control 142 \
    video/hdmi_out/frontend/vtc_out/ctrl 100 \
    video/hdmi_out/frontend/axi_dynclk/s00_axi 100]
set_property -dict [list CONFIG.NUM_MI [expr {[llength $slaves] + [llength $vslaves] / 2}] CONFIG.NUM_SI 1] $ic
connect_bd_intf_net [get_bd_intf_pins $ps/M_AXI_GP0] [get_bd_intf_pins $ic/S00_AXI]
set i 0
foreach s $slaves {
    set sa [get_bd_intf_pins -of_objects $s -filter {MODE == Slave && VLNV =~ "xilinx.com:interface:aximm_rtl:*"}]
    if {[llength $sa] != 1} { error "AXI slave port of $s not found: $sa" }
    connect_bd_intf_net [get_bd_intf_pins $ic/M[format %02d $i]_AXI] $sa
    incr i
}
set clk [get_bd_pins $ps/FCLK_CLK0]
set arstn [get_bd_pins $rst/peripheral_aresetn]
connect_bd_net $clk [get_bd_pins $ps/M_AXI_GP0_ACLK] [get_bd_pins $ic/ACLK] [get_bd_pins $ic/S00_ACLK]
connect_bd_net [get_bd_pins $rst/interconnect_aresetn] [get_bd_pins $ic/ARESETN]
connect_bd_net $arstn [get_bd_pins $ic/S00_ARESETN]
for {set i 0} {$i < [llength $slaves]} {incr i} {
    set m [format %02d $i]
    connect_bd_net $clk [get_bd_pins $ic/M${m}_ACLK]
    connect_bd_net $arstn [get_bd_pins $ic/M${m}_ARESETN]
}
foreach s $slaves {
    connect_bd_net $clk [get_bd_pins $s/s_axi_aclk]
    connect_bd_net $arstn [get_bd_pins $s/s_axi_aresetn]
}
connect_bd_net $clk [get_bd_pins $seg7/clk] [get_bd_pins $tone/clk]
connect_bd_net $arstn [get_bd_pins $seg7/resetn] [get_bd_pins $tone/resetn]

# video register ports on the same interconnect
set clk142 [get_bd_pins $ps/FCLK_CLK1]
set arstn142 [get_bd_pins $rst142/peripheral_aresetn]
set i [llength $slaves]
foreach {pin dom} $vslaves {
    set m [format %02d $i]
    connect_bd_intf_net [get_bd_intf_pins $ic/M${m}_AXI] [get_bd_intf_pins $pin]
    if {$dom == 142} {
        connect_bd_net $clk142 [get_bd_pins $ic/M${m}_ACLK]
        connect_bd_net $arstn142 [get_bd_pins $ic/M${m}_ARESETN]
    } else {
        connect_bd_net $clk [get_bd_pins $ic/M${m}_ACLK]
        connect_bd_net $arstn [get_bd_pins $ic/M${m}_ARESETN]
    }
    incr i
}
# 100 MHz: register clocks of the VDMA, timing controller and clock generator
connect_bd_net $clk [get_bd_pins video/axi_vdma/s_axi_lite_aclk] [get_bd_pins video/hdmi_out/frontend/vtc_out/s_axi_aclk] \
    [get_bd_pins video/hdmi_out/frontend/axi_dynclk/s00_axi_aclk] [get_bd_pins video/hdmi_out/frontend/axi_dynclk/REF_CLK_I]
connect_bd_net $arstn [get_bd_pins video/axi_vdma/axi_resetn] [get_bd_pins video/hdmi_out/frontend/vtc_out/s_axi_aresetn] \
    [get_bd_pins video/hdmi_out/frontend/axi_dynclk/s00_axi_aresetn]
# 142 MHz: video stream and the DMA memory port
connect_bd_net $clk142 [get_bd_pins video/axi_vdma/m_axi_mm2s_aclk] [get_bd_pins video/axi_vdma/m_axis_mm2s_aclk] \
    [get_bd_pins video/hdmi_out/pixel_unpack/ap_clk] [get_bd_pins video/hdmi_out/color_convert/ap_clk] \
    [get_bd_pins video/hdmi_out/axis_register_slice_0/aclk] [get_bd_pins video/hdmi_out/frontend/v_axi4s_vid_out_0/aclk] \
    [get_bd_pins $hpic/ACLK] [get_bd_pins $hpic/S00_ACLK] [get_bd_pins $hpic/M00_ACLK] [get_bd_pins $ps/S_AXI_HP0_ACLK]
connect_bd_net $arstn142 [get_bd_pins video/hdmi_out/pixel_unpack/ap_rst_n] [get_bd_pins video/hdmi_out/color_convert/ap_rst_n] \
    [get_bd_pins video/hdmi_out/axis_register_slice_0/aresetn] [get_bd_pins $hpic/S00_ARESETN] [get_bd_pins $hpic/M00_ARESETN]
connect_bd_net [get_bd_pins $rst142/interconnect_aresetn] [get_bd_pins $hpic/ARESETN]

# ---------------------------------------------------------------- pins
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 leds
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 sws
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gpio_rtl:1.0 btns
connect_bd_intf_net [get_bd_intf_pins $leds/GPIO] [get_bd_intf_ports leds]
connect_bd_intf_net [get_bd_intf_pins $sws/GPIO] [get_bd_intf_ports sws]
connect_bd_intf_net [get_bd_intf_pins $btns/GPIO] [get_bd_intf_ports btns]

connect_bd_net [get_bd_pins $s7g/gpio_io_o] [get_bd_pins $seg7/ctrl]
connect_bd_net [get_bd_pins $s7g/gpio2_io_o] [get_bd_pins $seg7/raw]
create_bd_port -dir O -from 3 -to 0 seg7_an
create_bd_port -dir O -from 7 -to 0 seg7_seg_n
connect_bd_net [get_bd_pins $seg7/an] [get_bd_ports seg7_an]
connect_bd_net [get_bd_pins $seg7/seg_n] [get_bd_ports seg7_seg_n]

connect_bd_net [get_bd_pins $bzg/gpio_io_o] [get_bd_pins $tone/ctrl]
create_bd_port -dir O buzzer
connect_bd_net [get_bd_pins $tone/buzzer] [get_bd_ports buzzer]

create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 Vaux2
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_analog_io_rtl:1.0 Vaux10
connect_bd_intf_net [get_bd_intf_pins $xadc/Vaux2] [get_bd_intf_ports Vaux2]
connect_bd_intf_net [get_bd_intf_pins $xadc/Vaux10] [get_bd_intf_ports Vaux10]

# ---------------------------------------------------------------- interrupts
connect_bd_net [get_bd_pins $sws/ip2intc_irpt] [get_bd_pins $cat/In0]
connect_bd_net [get_bd_pins $btns/ip2intc_irpt] [get_bd_pins $cat/In1]
connect_bd_net [get_bd_pins video/axi_vdma/mm2s_introut] [get_bd_pins $cat/In2]
connect_bd_net [get_bd_pins $cat/dout] [get_bd_pins $intc/intr]
connect_bd_net [get_bd_pins $intc/irq] [get_bd_pins $ps/IRQ_F2P]

# ---------------------------------------------------------------- addresses (PYNQ reads them from the .hwh)
set space [get_bd_addr_spaces processing_system7_0/Data]
foreach {cell base} {leds_gpio 0x41200000 switches_gpio 0x41210000 btns_gpio 0x41220000 \
                     seg7_gpio 0x41230000 buzzer_gpio 0x41240000 system_interrupts 0x41800000 xadc_wiz_0 0x43C00000} {
    assign_bd_address -offset $base -range 0x00010000 -target_address_space $space \
        [get_bd_addr_segs -of_objects [get_bd_cells $cell]] -force
}
assign_bd_address
foreach s [get_bd_addr_segs -quiet processing_system7_0/Data/*] { puts "EDGE_ADDR $s [get_property offset $s] [get_property range $s]" }

validate_bd_design
save_bd_design
set wrapper [make_wrapper -files [get_files base.bd] -top]
add_files -norecurse $wrapper
set_property top base_wrapper [current_fileset]
update_compile_order -fileset sources_1

# ---------------------------------------------------------------- build
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { puts "EDGE_RESULT FAIL implementation"; exit 1 }
open_run impl_1
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "EDGE_WNS $wns"
report_utilization -file $outdir/utilization.txt
set bit [glob $work/base.runs/impl_1/*.bit]
file copy -force $bit $outdir/base.bit
set hwh [lindex [get_files -all -of_objects [get_files base.bd] -filter {NAME =~ *base.hwh}] 0]
if {$hwh eq ""} { set hwh [lindex [glob -nocomplain $work/base.gen/sources_1/bd/base/hw_handoff/base.hwh $work/base.srcs/sources_1/bd/base/hw_handoff/base.hwh] 0] }
file copy -force $hwh $outdir/base.hwh
write_hw_platform -fixed -include_bit -force -file $outdir/base.xsa
puts "EDGE_RESULT OK $part wns=$wns"
exit 0
