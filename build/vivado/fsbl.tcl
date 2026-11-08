# Build the Zynq FSBL from an XSA (xsct, Vitis 2022.2)
set xsa [lindex $argv 0]
set out [lindex $argv 1]
file delete -force $out
file mkdir $out
hsi::open_hw_design $xsa
hsi::generate_app -hw [hsi::current_hw_design] -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -sw fsbl -dir $out
hsi::close_hw_design [hsi::current_hw_design]
puts "EDGE_FSBL [file exists $out/executable.elf]"
