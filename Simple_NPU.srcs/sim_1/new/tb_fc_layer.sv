`timescale 1ns/1ps

module tb_fc_layer;

    parameter int DATA_W = 8;
    parameter int PROD_W = 2 * DATA_W;
    parameter int SUM_W  = PROD_W + 2;
    parameter int ACC_W  = SUM_W + 2;
    parameter int N_IN   = 8;
    parameter int N_OUT  = 4;

    logic clk;
    logic rst_n;
    logic start;
    logic done;

    logic signed [ACC_W-1:0] y0;
    logic signed [ACC_W-1:0] y1;
    logic signed [ACC_W-1:0] y2;
    logic signed [ACC_W-1:0] y3;

    fc_layer #(
        .DATA_W(DATA_W),
        .PROD_W(PROD_W),
        .SUM_W (SUM_W),
        .ACC_W (ACC_W),
        .N_IN  (N_IN),
        .N_OUT (N_OUT)
    ) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start),
        .done (done),
        .y0   (y0),
        .y1   (y1),
        .y2   (y2),
        .y3   (y3)
    );

    // 10 ns clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_outputs(
        input logic signed [ACC_W-1:0] exp_y0,
        input logic signed [ACC_W-1:0] exp_y1,
        input logic signed [ACC_W-1:0] exp_y2,
        input logic signed [ACC_W-1:0] exp_y3
    );
    begin
        if (y0 !== exp_y0) begin
            $display("FAIL: y0 expected %0d, got %0d", exp_y0, y0);
            $fatal;
        end
        if (y1 !== exp_y1) begin
            $display("FAIL: y1 expected %0d, got %0d", exp_y1, y1);
            $fatal;
        end
        if (y2 !== exp_y2) begin
            $display("FAIL: y2 expected %0d, got %0d", exp_y2, y2);
            $fatal;
        end
        if (y3 !== exp_y3) begin
            $display("FAIL: y3 expected %0d, got %0d", exp_y3, y3);
            $fatal;
        end

        $display("PASS: outputs matched expected values");
    end
    endtask

    initial begin
        $display("Starting tb_fc_layer...");

        start = 1'b0;
        rst_n = 1'b0;

        // Hold reset for a few cycles
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // Pulse start for 1 cycle
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for done
        wait (done == 1'b1);
        @(posedge clk);

        $display("done asserted");
        $display("y0 = %0d", y0);
        $display("y1 = %0d", y1);
        $display("y2 = %0d", y2);
        $display("y3 = %0d", y3);

        // Expected values based on the current hardcoded x[] and w[] in fc_layer
        //
        // x = [16, 8, -16, 4, 12, -8, 20, 16]
        //
        // neuron 0 weights all 16:
        // sum = 16*16 + 8*16 + (-16)*16 + 4*16 + 12*16 + (-8)*16 + 20*16 + 16*16
        //     = 832
        // ReLU -> 832
        //
        // neuron 1 weights [8,-8,8,-8,8,-8,8,-8]:
        // sum = 16*8 + 8*(-8) + (-16)*8 + 4*(-8) + 12*8 + (-8)*(-8) + 20*8 + 16*(-8)
        //     = 96
        // ReLU -> 96
        //
        // neuron 2 weights all 4:
        // sum = 16*4 + 8*4 + (-16)*4 + 4*4 + 12*4 + (-8)*4 + 20*4 + 16*4
        //     = 208
        // ReLU -> 208
        //
        // neuron 3 weights [-16,16,-16,16,-16,16,-16,16]:
        // sum = 16*(-16) + 8*16 + (-16)*(-16) + 4*16 + 12*(-16) + (-8)*16 + 20*(-16) + 16*16
        //     = -192
        // ReLU -> 0

        check_outputs(20'sd832, 20'sd96, 20'sd208, 20'sd0);

        $display("All tb_fc_layer tests passed.");
        $finish;
    end

endmodule