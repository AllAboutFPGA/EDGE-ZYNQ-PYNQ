// EDGE ZYNQ buzzer tone generator for the PYNQ base overlay.
// Invent Logics / allaboutfpga.com
//
// ctrl (from AXI GPIO): [30:0] half period in 100 MHz clock cycles, [31] = on.
// Frequency = 100 MHz / (2 * half period); e.g. 1 kHz -> half period 50000.
`timescale 1ns / 1ps
module edge_tone (
    input  wire        clk,        // 100 MHz
    input  wire        resetn,
    input  wire [31:0] ctrl,
    output reg         buzzer
);
    reg [30:0] cnt = 31'd0;
    wire       en  = ctrl[31] && (ctrl[30:0] > 31'd1);
    always @(posedge clk) begin
        if (!resetn || !en) begin
            cnt    <= 31'd0;
            buzzer <= 1'b0;
        end else if (cnt >= ctrl[30:0] - 31'd1) begin
            cnt    <= 31'd0;
            buzzer <= ~buzzer;
        end else begin
            cnt    <= cnt + 31'd1;
        end
    end
endmodule
