# Vitis HLS 2022.2: C simulation, synthesis and IP export of the FIR filter.
#   vitis_hls -f run_hls.tcl
# Output: fir_prj/solution1/impl/ip  (add this folder to the Vivado IP repository)
open_project -reset fir_prj
set_top fir
add_files fir.cpp
add_files -tb fir_tb.cpp
open_solution -reset solution1 -flow_target vivado
set_part xc7z010clg400-1
create_clock -period 10 -name default
csim_design
csynth_design
export_design -format ip_catalog -vendor allaboutfpga.com -library hls -version 1.0 -display_name "FIR filter (31 taps)"
exit
