# Shared helpers for the PYNQ tutorial overlays (Vivado 2022.2, batch mode)
# PYNQ tutorial series for the EDGE ZYNQ SoC FPGA kit - Invent Logics / allaboutfpga.com
#
# Each episode script does:
#   source overlay_lib.tcl
#   edge_project <name> <part> <work dir> <hdl files> <xdc files> [<ip repo dirs>]
#   set ps [edge_ps7 [list <extra PS settings>]]
#   ... create its own blocks ...
#   edge_interrupts {<interrupt pins>}       (optional)
#   edge_axi_lite {<cells with an AXI-Lite slave>}
#   edge_build <name> <output dir>
#
# Output: <name>.bit and <name>.hwh in the output folder (PYNQ loads these as a pair), and
# <name>.xsa in the work folder (keep it away from the board's overlay folder).

set edge_lib_dir [file dirname [file normalize [info script]]]

proc ipv {name {vendor xilinx.com:ip}} {
    set d [lindex [lsort [get_ipdefs -all ${vendor}:${name}:*]] end]
    if {$d eq ""} { error "IP $vendor:$name not found" }
    return $d
}

proc edge_project {name part work hdl xdc {iprepos {}}} {
    file mkdir $work
    create_project -force $name $work -part $part
    set_property target_language Verilog [current_project]
    if {[llength $iprepos]} {
        set_property ip_repo_paths $iprepos [current_project]
        update_ip_catalog
    }
    if {[llength $hdl]} { add_files -norecurse $hdl }
    if {[llength $xdc]} { add_files -fileset constrs_1 -norecurse $xdc }
    update_compile_order -fileset sources_1
    create_bd_design $name
}

# Zynq processing system with the EDGE ZYNQ settings (33.333 MHz clock, DDR3, MIO),
# FCLK0 = 100 MHz, M_AXI_GP0 and PL interrupts on. Returns the PS cell.
proc edge_ps7 {{extra {}}} {
    global edge_lib_dir edge_ps7_config
    source $edge_lib_dir/ps7_config.tcl
    set cfg [concat $edge_ps7_config $extra]
    set ps [create_bd_cell -type ip -vlnv [ipv processing_system7] processing_system7_0]
    if {[catch {set_property -dict $cfg $ps} e]} {
        puts "EDGE_WARN PS settings as one set failed ($e), setting them one by one"
        for {set pass 0} {$pass < 3} {incr pass} {
            foreach {k v} $cfg { catch {set_property $k $v $ps} }
        }
    }
    make_bd_intf_pins_external [get_bd_intf_pins $ps/DDR] [get_bd_intf_pins $ps/FIXED_IO]
    set_property name DDR [get_bd_intf_ports DDR_0]
    set_property name FIXED_IO [get_bd_intf_ports FIXED_IO_0]
    set rst [create_bd_cell -type ip -vlnv [ipv proc_sys_reset] rst_ps7_0_100M]
    connect_bd_net [get_bd_pins $ps/FCLK_CLK0] [get_bd_pins $rst/slowest_sync_clk]
    connect_bd_net [get_bd_pins $ps/FCLK_RESET0_N] [get_bd_pins $rst/ext_reset_in]
    return $ps
}

proc edge_clk {}   { return [get_bd_pins processing_system7_0/FCLK_CLK0] }
proc edge_rstn {}  { return [get_bd_pins rst_ps7_0_100M/peripheral_aresetn] }

# An AXI interrupt controller fed by the given interrupt pins, connected to the PS.
# PYNQ finds it in the .hwh and gives each block its interrupts. Returns the controller.
proc edge_interrupts {pins} {
    set cat [create_bd_cell -type ip -vlnv [ipv xlconcat] irq_concat]
    set_property CONFIG.NUM_PORTS [llength $pins] $cat
    set i 0
    foreach p $pins {
        connect_bd_net [get_bd_pins $p] [get_bd_pins $cat/In$i]
        incr i
    }
    set intc [create_bd_cell -type ip -vlnv [ipv axi_intc] system_interrupts]
    connect_bd_net [get_bd_pins $cat/dout] [get_bd_pins $intc/intr]
    connect_bd_net [get_bd_pins $intc/irq] [get_bd_pins processing_system7_0/IRQ_F2P]
    return $intc
}

# One AXI interconnect from M_AXI_GP0 to the AXI-Lite slave of every cell, all at 100 MHz.
proc edge_axi_lite {cells} {
    set ps [get_bd_cells processing_system7_0]
    set ic [create_bd_cell -type ip -vlnv [ipv axi_interconnect] ps7_0_axi_periph]
    set_property -dict [list CONFIG.NUM_MI [llength $cells] CONFIG.NUM_SI 1] $ic
    connect_bd_intf_net [get_bd_intf_pins $ps/M_AXI_GP0] [get_bd_intf_pins $ic/S00_AXI]
    set clk [edge_clk]
    set arstn [edge_rstn]
    connect_bd_net $clk [get_bd_pins $ps/M_AXI_GP0_ACLK] [get_bd_pins $ic/ACLK] [get_bd_pins $ic/S00_ACLK]
    connect_bd_net [get_bd_pins rst_ps7_0_100M/interconnect_aresetn] [get_bd_pins $ic/ARESETN]
    connect_bd_net $arstn [get_bd_pins $ic/S00_ARESETN]
    set i 0
    foreach c $cells {
        set sa [get_bd_intf_pins -of_objects [get_bd_cells $c] \
                    -filter {MODE == Slave && VLNV =~ "xilinx.com:interface:aximm_rtl:*" && NAME !~ "*S2MM*" && NAME !~ "*MM2S*"}]
        if {[llength $sa] != 1} { error "AXI-Lite slave of $c not found: $sa" }
        set m [format %02d $i]
        connect_bd_intf_net [get_bd_intf_pins $ic/M${m}_AXI] $sa
        connect_bd_net $clk [get_bd_pins $ic/M${m}_ACLK]
        connect_bd_net $arstn [get_bd_pins $ic/M${m}_ARESETN]
        incr i
    }
    return $ic
}

# Connect every unconnected clock and reset input of the given cells to FCLK0 / its reset.
proc edge_clock_cells {cells} {
    foreach c $cells {
        foreach p [get_bd_pins -of_objects [get_bd_cells $c] -filter {DIR == I && TYPE == clk}] {
            if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} { connect_bd_net [edge_clk] $p }
        }
        foreach p [get_bd_pins -of_objects [get_bd_cells $c] -filter {DIR == I && TYPE == rst}] {
            if {[llength [get_bd_nets -quiet -of_objects $p]] == 0} { connect_bd_net [edge_rstn] $p }
        }
    }
}

# Validate, synthesise, implement, and write <name>.bit, <name>.hwh and <name>.xsa.
proc edge_build {name outdir} {
    file mkdir $outdir
    set space [get_bd_addr_spaces processing_system7_0/Data]
    assign_bd_address
    foreach s [get_bd_addr_segs -quiet processing_system7_0/Data/*] {
        puts "EDGE_ADDR $s [get_property offset $s] [get_property range $s]"
    }
    validate_bd_design
    save_bd_design
    set wrapper [make_wrapper -files [get_files $name.bd] -top]
    add_files -norecurse $wrapper
    set_property top ${name}_wrapper [current_fileset]
    update_compile_order -fileset sources_1
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { puts "EDGE_RESULT FAIL implementation"; exit 1 }
    open_run impl_1
    set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
    report_utilization -file $outdir/utilization.txt
    set work [get_property DIRECTORY [current_project]]
    file copy -force [lindex [glob $work/$name.runs/impl_1/*.bit] 0] $outdir/$name.bit
    set hwh [lindex [get_files -all -of_objects [get_files $name.bd] -filter "NAME =~ *$name.hwh"] 0]
    if {$hwh eq ""} { set hwh [lindex [glob -nocomplain $work/$name.gen/sources_1/bd/$name/hw_handoff/$name.hwh] 0] }
    file copy -force $hwh $outdir/$name.hwh
    # the .xsa stays in the work folder: a .xsa next to the .bit makes PYNQ ignore the .hwh
    write_hw_platform -fixed -include_bit -force -file $work/$name.xsa
    if {$wns < 0} { puts "EDGE_RESULT FAIL timing wns=$wns"; exit 1 }
    puts "EDGE_RESULT OK $name wns=$wns"
}

# The PS settings an overlay with a DMA needs: the HP0 port to DDR memory.
set edge_hp0_config [list CONFIG.PCW_USE_S_AXI_HP0 1 CONFIG.PCW_S_AXI_HP0_DATA_WIDTH 64]

# An AXI DMA (simple mode) named axi_dma: memory -> M_AXIS_MM2S -> <to_pin> ... <from_pin>
# -> S_AXIS_S2MM -> memory, through the HP0 port. Transfers up to 64 MB. Returns the DMA cell.
proc edge_dma {to_pin from_pin} {
    set ps [get_bd_cells processing_system7_0]
    set dma [create_bd_cell -type ip -vlnv [ipv axi_dma] axi_dma]
    set_property -dict [list CONFIG.c_include_sg 0 CONFIG.c_sg_length_width 26 \
        CONFIG.c_m_axi_mm2s_data_width 64 CONFIG.c_m_axis_mm2s_tdata_width 32 \
        CONFIG.c_m_axi_s2mm_data_width 64 CONFIG.c_s_axis_s2mm_tdata_width 32 \
        CONFIG.c_mm2s_burst_size 32 CONFIG.c_s2mm_burst_size 32] $dma
    connect_bd_intf_net [get_bd_intf_pins $dma/M_AXIS_MM2S] [get_bd_intf_pins $to_pin]
    connect_bd_intf_net [get_bd_intf_pins $from_pin] [get_bd_intf_pins $dma/S_AXIS_S2MM]
    set hp [create_bd_cell -type ip -vlnv [ipv axi_interconnect] axi_mem_intercon]
    set_property -dict [list CONFIG.NUM_SI 2 CONFIG.NUM_MI 1] $hp
    connect_bd_intf_net [get_bd_intf_pins $dma/M_AXI_MM2S] [get_bd_intf_pins $hp/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins $dma/M_AXI_S2MM] [get_bd_intf_pins $hp/S01_AXI]
    connect_bd_intf_net [get_bd_intf_pins $hp/M00_AXI] [get_bd_intf_pins $ps/S_AXI_HP0]
    set clk [edge_clk]
    set arstn [edge_rstn]
    connect_bd_net $clk [get_bd_pins $ps/S_AXI_HP0_ACLK] [get_bd_pins $hp/ACLK] [get_bd_pins $hp/S00_ACLK] \
        [get_bd_pins $hp/S01_ACLK] [get_bd_pins $hp/M00_ACLK]
    connect_bd_net [get_bd_pins rst_ps7_0_100M/interconnect_aresetn] [get_bd_pins $hp/ARESETN]
    connect_bd_net $arstn [get_bd_pins $hp/S00_ARESETN] [get_bd_pins $hp/S01_ARESETN] [get_bd_pins $hp/M00_ARESETN]
    edge_clock_cells [list axi_dma]
    return $dma
}
