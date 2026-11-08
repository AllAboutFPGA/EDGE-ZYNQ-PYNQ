# PYNQ tutorial series for the EDGE ZYNQ SoC FPGA kit

Invent Logics / allaboutfpga.com. Notebooks for the PYNQ v3.1 image on the EDGE ZYNQ Z7-10 and Z7-20.

| Episode | Notebook | Needs |
| --- | --- | --- |
| 1 What is PYNQ? | 01_what_is_pynq.ipynb | board |
| 2 First boot and a Jupyter tour | 02_first_boot_jupyter.ipynb | board |
| 3 LEDs, switches and push buttons | 03_leds_switches_buttons.ipynb | board |
| 4 7-segment display and buzzer | 04_seven_segment_buzzer.ipynb | J10 jumper for the buzzer |
| 5 Button interrupts with asyncio | 05_interrupts_asyncio.ipynb | board |
| 6 XADC sensors and a data logger | 06_xadc_logger.ipynb | J15 jumpers, LM35, LDR |
| 7 Control panels with ipywidgets | 07_widgets_control_panel.ipynb | board |
| 8 HDMI output | 08_hdmi_graphics.ipynb | HDMI monitor |
| 9 USB webcam and OpenCV basics | 09_webcam_opencv_basics.ipynb | webcam on J3, J6/J7 fitted, HDMI |
| 10 Face and edge detection | 10a_face_detection_webcam.ipynb, 10b_edge_detection_webcam.ipynb | webcam, HDMI |
| 11 A web dashboard | 11_web_dashboard.ipynb | phone or PC on the same network |
| 12 Your first custom overlay | 12_first_overlay/ | Vivado 2022.2 |
| 13 Your own Verilog IP over AXI-Lite | 13_axi_lite_pwm/ | Vivado 2022.2 |
| 14 Writing a PYNQ driver | 14_driver_class/ (uses the episode 13 overlay) | Vivado 2022.2 |
| 15 AXI DMA | 15_axi_dma/ | Vivado 2022.2 |
| 16 HLS: C code to hardware | 16_hls_fir/ | Vitis HLS + Vivado 2022.2 |

Episodes 1-11 use the base overlay on the SD image. Episodes 12-16 each come with the sources
of their overlay; `common\build_part3.ps1` builds all of them for both chips (about an hour),
and each overlay's `.bit` and `.hwh` go to `<episode>/overlays/z10` and `z20`.
Only those two files go to the board: a `.xsa` beside the `.bit` stops PYNQ from reading the `.hwh`.

Copy this folder to the board (for example into `/home/xilinx/jupyter_notebooks/pynq_series`)
and open the notebooks in Jupyter.
