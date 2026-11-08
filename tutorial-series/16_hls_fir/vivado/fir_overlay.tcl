# Episode 16: the HLS FIR filter between the two directions of an AXI DMA.
#
#   vivado -mode batch -source fir_overlay.tcl -tclargs <part> <work dir> <output dir> <HLS IP dir>
#   HLS IP dir: ../hls/fir_prj/solution1/impl/ip (after vitis_hls -f run_hls.tcl)
# Output: fir_overlay.bit and fir_overlay.hwh in <output dir> (the .xsa stays in <work dir>)
set part   [lindex $argv 0]
set work   [file normalize [lindex $argv 1]]
set outdir [file normalize [lindex $argv 2]]
set hlsip  [file normalize [lindex $argv 3]]
set here   [file dirname [file normalize [info script]]]
source $here/../../common/overlay_lib.tcl

edge_project fir_overlay $part $work {} [list $here/fir_overlay.xdc] [list $hlsip]
set ps [edge_ps7 $edge_hp0_config]

set fir [create_bd_cell -type ip -vlnv [ipv fir allaboutfpga.com:hls] fir_0]
set dma [edge_dma fir_0/x_in fir_0/y_out]
edge_clock_cells [list fir_0]

edge_interrupts [list axi_dma/mm2s_introut axi_dma/s2mm_introut]
edge_axi_lite [list axi_dma fir_0 system_interrupts]
edge_clock_cells [list system_interrupts]

set space [get_bd_addr_spaces processing_system7_0/Data]
assign_bd_address -offset 0x40400000 -range 0x00010000 -target_address_space $space \
    [get_bd_addr_segs -of_objects [get_bd_cells axi_dma]] -force
assign_bd_address -offset 0x43C00000 -range 0x00010000 -target_address_space $space \
    [get_bd_addr_segs -of_objects [get_bd_cells fir_0]] -force
assign_bd_address -offset 0x41800000 -range 0x00010000 -target_address_space $space \
    [get_bd_addr_segs -of_objects [get_bd_cells system_interrupts]] -force

edge_build fir_overlay $outdir
exit 0
