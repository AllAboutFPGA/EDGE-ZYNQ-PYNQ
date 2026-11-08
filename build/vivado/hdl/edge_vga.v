// EDGE ZYNQ VGA output for the PYNQ base overlay: the HDMI picture, also sent to the
// 12-bit VGA connector P1 (4 bits per colour, resistor DAC on the board).
// Invent Logics / allaboutfpga.com
//
// Taps the pixel stream that goes into rgb2dvi, so the VGA monitor shows the same mode
// (640x480 ... 1920x1080) with the sync polarities PYNQ sets for that mode. The colours
// are blanked outside the active picture, as VGA monitors need.
`timescale 1ns / 1ps
module edge_vga (
    input  wire        clk,       // pixel clock (axi_dynclk PXL_CLK_O)
    /* verilator lint_off UNUSEDSIGNAL */
    input  wire [23:0] pixel,     // rgb2dvi order: [23:16] red, [15:8] blue, [7:0] green
    /* verilator lint_on UNUSEDSIGNAL */
    input  wire        vde,       // 1 = active picture
    input  wire        hsync,
    input  wire        vsync,
    output reg  [3:0]  vga_r  = 4'd0,
    output reg  [3:0]  vga_g  = 4'd0,
    output reg  [3:0]  vga_b  = 4'd0,
    output reg         vga_hs = 1'b0,
    output reg         vga_vs = 1'b0
);
    always @(posedge clk) begin
        vga_r  <= vde ? pixel[23:20] : 4'd0;
        vga_b  <= vde ? pixel[15:12] : 4'd0;
        vga_g  <= vde ? pixel[7:4]   : 4'd0;
        vga_hs <= hsync;
        vga_vs <= vsync;
    end
endmodule
