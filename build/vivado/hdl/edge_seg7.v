// EDGE ZYNQ 4-digit 7-segment display driver for the PYNQ base overlay.
// Invent Logics / allaboutfpga.com
//
// ctrl (from AXI GPIO channel 1):
//   [15:0]  four hex digits, digit 0 (leftmost) = ctrl[15:12], digit 3 (rightmost) = ctrl[3:0]
//   [19:16] decimal points, bit 16 = digit 3 (rightmost) ... bit 19 = digit 0 (leftmost)
//   [23:20] digit on (1 = shown), bit 20 = digit 3 ... bit 23 = digit 0
//   [24]    raw mode: show the segment patterns in 'raw' instead of hex digits
// raw (from AXI GPIO channel 2): one byte per digit, byte 0 (bits 7:0) = digit 3 (rightmost),
//   byte 3 = digit 0 (leftmost); in each byte bit 0 = a, 1 = b, 2 = c, 3 = d, 4 = e, 5 = f,
//   6 = g, 7 = dp (1 = lit).
//
// Board wiring (EDGE ZYNQ): digit enables an[0..3] active high, an[0] = leftmost digit (T11);
// segments active low, seg_n[0] = a (V13), [1] = b, [2] = c, [3] = d, [4] = e, [5] = f,
// [6] = g (R14), [7] = dp (Y16).
`timescale 1ns / 1ps
module edge_seg7 (
    input  wire        clk,        // 100 MHz
    input  wire        resetn,
    input  wire [31:0] ctrl,
    input  wire [31:0] raw,
    output reg  [3:0]  an,
    output reg  [7:0]  seg_n
);
    reg [17:0] cnt = 18'd0;        // 100 MHz / 2^16 = 1.5 kHz per digit, 380 Hz refresh
    always @(posedge clk) begin
        if (!resetn) cnt <= 18'd0;
        else         cnt <= cnt + 18'd1;
    end
    wire [1:0] sel = cnt[17:16];   // 0 = leftmost digit

    function [6:0] hex7;           // returns {g,f,e,d,c,b,a}, 1 = lit
        input [3:0] h;
        case (h)
            4'h0: hex7 = 7'b0111111;  4'h1: hex7 = 7'b0000110;
            4'h2: hex7 = 7'b1011011;  4'h3: hex7 = 7'b1001111;
            4'h4: hex7 = 7'b1100110;  4'h5: hex7 = 7'b1101101;
            4'h6: hex7 = 7'b1111101;  4'h7: hex7 = 7'b0000111;
            4'h8: hex7 = 7'b1111111;  4'h9: hex7 = 7'b1101111;
            4'hA: hex7 = 7'b1110111;  4'hB: hex7 = 7'b1111100;
            4'hC: hex7 = 7'b0111001;  4'hD: hex7 = 7'b1011110;
            4'hE: hex7 = 7'b1111001;  default: hex7 = 7'b1110001;   // F
        endcase
    endfunction

    reg [3:0] nib;
    reg       dp, on;
    reg [7:0] rawb;
    always @(*) begin
        case (sel)                 // digit 0 is the leftmost one
            2'd0: begin nib = ctrl[15:12]; dp = ctrl[19]; on = ctrl[23]; rawb = raw[31:24]; end
            2'd1: begin nib = ctrl[11:8];  dp = ctrl[18]; on = ctrl[22]; rawb = raw[23:16]; end
            2'd2: begin nib = ctrl[7:4];   dp = ctrl[17]; on = ctrl[21]; rawb = raw[15:8];  end
            default: begin nib = ctrl[3:0]; dp = ctrl[16]; on = ctrl[20]; rawb = raw[7:0]; end
        endcase
    end
    wire [7:0] lit = ctrl[24] ? rawb : {dp, hex7(nib)};   // {dp,g,f,e,d,c,b,a}

    always @(posedge clk) begin
        if (!resetn) begin
            an    <= 4'b0000;
            seg_n <= 8'hFF;
        end else begin
            an    <= on ? (4'b0001 << sel) : 4'b0000;
            seg_n <= ~lit;
        end
    end
endmodule
