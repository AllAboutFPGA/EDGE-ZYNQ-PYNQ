# Episode 15: AXI DMA loopback - memory -> DMA -> AXI-Stream FIFO -> DMA -> memory.
#
#   vivado -mode batch -source dma_overlay.tcl -tclargs <part> <work dir> <output dir>
# Output: dma_overlay.bit and dma_overlay.hwh in <output dir> (the .xsa stays in <work dir>)
set part   [lindex $argv 0]
set work   [file normalize [lindex $argv 1]]
set outdir [file normalize [lindex $argv 2]]
set here   [file dirname [file normalize [info script]]]
source $here/../common/overlay_lib.tcl

edge_project dma_overlay $part $work {} [list $here/dma_overlay.xdc]
set ps [edge_ps7 $edge_hp0_config]

set fifo [create_bd_cell -type ip -vlnv [ipv axis_data_fifo] loopback_fifo]
set_property -dict [list CONFIG.FIFO_DEPTH 1024 CONFIG.TDATA_NUM_BYTES 4] $fifo
set dma [edge_dma loopback_fifo/S_AXIS loopback_fifo/M_AXIS]
edge_clock_cells [list loopback_fifo]

edge_interrupts [list axi_dma/mm2s_introut axi_dma/s2mm_introut]
edge_axi_lite [list axi_dma system_interrupts]
edge_clock_cells [list system_interrupts]

set space [get_bd_addr_spaces processing_system7_0/Data]
assign_bd_address -offset 0x40400000 -range 0x00010000 -target_address_space $space \
    [get_bd_addr_segs -of_objects [get_bd_cells axi_dma]] -force
assign_bd_address -offset 0x41800000 -range 0x00010000 -target_address_space $space \
    [get_bd_addr_segs -of_objects [get_bd_cells system_interrupts]] -force

edge_build dma_overlay $outdir
exit 0
