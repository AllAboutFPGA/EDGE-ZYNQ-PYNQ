// Testbench for edge_pwm: AXI4-Lite reads and writes, duty cycles, shadow registers.
// Runs in Vivado xsim (run_sim.tcl) or Verilator 5 (--binary --timing).
`timescale 1ns / 1ps

module tb_edge_pwm;
    reg clk = 1'b0;
    reg rstn = 1'b0;
    always #5 clk = ~clk;                      // 100 MHz

    reg  [5:0]  awaddr = 0;  reg awvalid = 0;  wire awready;
    reg  [31:0] wdata = 0;   reg [3:0] wstrb = 0; reg wvalid = 0; wire wready;
    wire [1:0]  bresp;       wire bvalid;      reg bready = 0;
    reg  [5:0]  araddr = 0;  reg arvalid = 0;  wire arready;
    wire [31:0] rdata;       wire [1:0] rresp; wire rvalid; reg rready = 0;
    wire [3:0]  pwm;

    edge_pwm #(.CHANNELS(4)) dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rstn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .pwm(pwm));

    integer errors = 0;

    // Inputs change on the falling edge and outputs are sampled on the falling edge,
    // so the testbench never races the design's rising-edge logic.
    task automatic axi_write(input [5:0] addr, input [31:0] data, input [3:0] strb);
        integer n;
        begin
            @(negedge clk);
            awaddr = addr; awvalid = 1'b1; wdata = data; wstrb = strb; wvalid = 1'b1; bready = 1'b1;
            n = 0;
            while (!(awready && wready) && n < 20) begin @(negedge clk); n = n + 1; end
            @(negedge clk);                       // the handshake happened on the rising edge
            awvalid = 1'b0; wvalid = 1'b0;
            n = 0;
            while (!bvalid && n < 20) begin @(negedge clk); n = n + 1; end
            if (!bvalid || bresp != 2'b00) begin
                $display("ERROR: no write response for 0x%02h", addr); errors = errors + 1;
            end
            @(negedge clk);
            bready = 1'b0;
            if (bvalid) begin $display("ERROR: write response not cleared"); errors = errors + 1; end
        end
    endtask

    task automatic axi_read(input [5:0] addr, output [31:0] data);
        integer n;
        begin
            @(negedge clk);
            araddr = addr; arvalid = 1'b1; rready = 1'b1;
            n = 0;
            while (!arready && n < 20) begin @(negedge clk); n = n + 1; end
            @(negedge clk);
            arvalid = 1'b0;
            n = 0;
            while (!rvalid && n < 20) begin @(negedge clk); n = n + 1; end
            data = rdata;
            if (!rvalid) begin $display("ERROR: no read data for 0x%02h", addr); errors = errors + 1; end
            @(negedge clk);
            rready = 1'b0;
        end
    endtask

    task automatic expect_reg(input [5:0] addr, input [31:0] want);
        reg [31:0] got;
        begin
            axi_read(addr, got);
            if (got !== want) begin
                $display("ERROR: reg 0x%02h = 0x%08h, expected 0x%08h", addr, got, want);
                errors = errors + 1;
            end else
                $display("ok    reg 0x%02h = 0x%08h", addr, got);
        end
    endtask

    // count the high cycles of each channel over a number of whole periods
    task automatic measure(input integer cycles, input [31:0] w0, input [31:0] w1,
                           input [31:0] w2, input [31:0] w3);
        integer hi [0:3];
        integer c, ch;
        reg [31:0] want [0:3];
        begin
            want[0] = w0; want[1] = w1; want[2] = w2; want[3] = w3;
            for (ch = 0; ch < 4; ch = ch + 1) hi[ch] = 0;
            for (c = 0; c < cycles; c = c + 1) begin
                @(negedge clk);
                for (ch = 0; ch < 4; ch = ch + 1) if (pwm[ch]) hi[ch] = hi[ch] + 1;
            end
            for (ch = 0; ch < 4; ch = ch + 1) begin
                if (hi[ch] != want[ch]) begin
                    $display("ERROR: channel %0d high %0d of %0d cycles, expected %0d", ch, hi[ch], cycles, want[ch]);
                    errors = errors + 1;
                end else
                    $display("ok    channel %0d high %0d of %0d cycles", ch, hi[ch], cycles);
            end
        end
    endtask

    // wait until a new period starts (the counter is back at 0)
    task automatic sync_period;
        reg [31:0] c;
        begin
            @(negedge clk);
            while (dut.count != 0) @(negedge clk);
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rstn = 1'b1;
        repeat (2) @(posedge clk);

        $display("-- reset values and ID");
        expect_reg(6'h00, 32'h50574D31);
        expect_reg(6'h04, 32'h0);
        expect_reg(6'h08, 32'd100000);
        if (pwm !== 4'b0) begin $display("ERROR: outputs not low after reset"); errors = errors + 1; end

        $display("-- register writes and byte strobes");
        axi_write(6'h08, 32'd100, 4'hF);          // period 100 cycles
        axi_write(6'h10, 32'd25, 4'hF);           // 25 %
        axi_write(6'h14, 32'd50, 4'hF);           // 50 %
        axi_write(6'h18, 32'd0, 4'hF);            // 0 %
        axi_write(6'h1C, 32'd1000, 4'hF);         // more than the period: always on
        axi_write(6'h14, 32'hFFFF_FF32, 4'h1);    // only byte 0 written: still 50 (0x32)
        expect_reg(6'h08, 32'd100);
        expect_reg(6'h10, 32'd25);
        expect_reg(6'h14, 32'd50);
        expect_reg(6'h1C, 32'd1000);

        $display("-- duty cycles with all channels on");
        axi_write(6'h04, 32'hF, 4'hF);
        repeat (300) @(posedge clk);               // let the new period settle
        sync_period;
        measure(1000, 250, 500, 0, 1000);

        $display("-- channel enable");
        axi_write(6'h04, 32'h5, 4'hF);             // channels 0 and 2 only
        sync_period;
        measure(1000, 250, 0, 0, 0);

        $display("-- duty change applies at the next period");
        axi_write(6'h04, 32'hF, 4'hF);
        sync_period;
        repeat (10) @(posedge clk);
        axi_write(6'h10, 32'd75, 4'hF);            // during a period
        sync_period;
        measure(1000, 750, 500, 0, 1000);

        $display("-- counter is readable");
        begin : rd
            reg [31:0] a, b;
            axi_read(6'h20, a);
            axi_read(6'h20, b);
            if (a == b) begin $display("ERROR: counter not running"); errors = errors + 1; end
            else $display("ok    counter %0d -> %0d", a, b);
        end

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED: %0d errors", errors);
        $finish;
    end
endmodule
