`timescale 1ns/1ps

module tb_mac_unit;

    parameter int DATA_W = 8;
    parameter int FRAC_W = 4;
    parameter int PROD_W = 2 * DATA_W;
    parameter int SUM_W = PROD_W + 2;

    logic signed [DATA_W-1:0] x0;
    logic signed [DATA_W-1:0] w0;
    logic signed [DATA_W-1:0] x1;
    logic signed [DATA_W-1:0] w1;
    logic signed [DATA_W-1:0] x2;
    logic signed [DATA_W-1:0] w2;
    logic signed [DATA_W-1:0] x3;
    logic signed [DATA_W-1:0] w3;

    logic signed [SUM_W-1:0] partial_sum;
    logic signed [SUM_W-1:0] expected;

    mac_unit #(
        .DATA_W(DATA_W),
        .PROD_W(PROD_W),
        .SUM_W(SUM_W)
    ) dut (
        .x0(x0), 
        .w0(w0),
        .x1(x1), 
        .w1(w1),
        .x2(x2), 
        .w2(w2),
        .x3(x3), 
        .w3(w3),
        .partial_sum(partial_sum)
    );

    task automatic run_test( // function (automatic: every call is independent)
        input logic signed [DATA_W-1:0] tx0,
        input logic signed [DATA_W-1:0] tw0,
        input logic signed [DATA_W-1:0] tx1,
        input logic signed [DATA_W-1:0] tw1,
        input logic signed [DATA_W-1:0] tx2,
        input logic signed [DATA_W-1:0] tw2,
        input logic signed [DATA_W-1:0] tx3,
        input logic signed [DATA_W-1:0] tw3,
        input logic signed [SUM_W-1:0] exp,
        input string test_name
    );
    begin
        x0 = tx0; 
        w0 = tw0;
        x1 = tx1; 
        w1 = tw1;
        x2 = tx2; 
        w2 = tw2;
        x3 = tx3; 
        w3 = tw3;
        expected = exp;

        #1; // give a short delay for combination logic

        if (partial_sum !== expected) begin
            $display("FAIL: %s", test_name);
            $display("  x = [%0d, %0d, %0d, %0d]", x0, x1, x2, x3);
            $display("  w = [%0d, %0d, %0d, %0d]", w0, w1, w2, w3);
            $display("  expected = %0d, got = %0d", expected, partial_sum);
            $fatal; // terminate if failed
        end
        else begin
            $display("PASS: %s -> partial_sum = %0d", test_name, partial_sum);
        end
    end
    endtask

    // passing sign(#1)'sd(#2) 
    // #1: bit wide, s: signed, d: decimal, #2: value
    initial begin 
        $display("Starting tb_mac_unit...");

        // Test 1: 1*1 + 2*1 + 3*1 + 4*1 = 10
        run_test(
            8'sd1, 8'sd1,
            8'sd2, 8'sd1,
            8'sd3, 8'sd1,
            8'sd4, 8'sd1,
            18'sd10,
            "all positive integers"
        );

        // Test 2: 3*(-2) + 4*5 + (-1)*7 + 2*(-3) = 1
        run_test(
            8'sd3,  -8'sd2,
            8'sd4,  8'sd5,
            -8'sd1, 8'sd7,
            8'sd2,  -8'sd3,
            18'sd1,
            "mixed signs"
        );

        // Test 3: (-2)*(-3) + (-4)*(-1) + (-1)*(-5) + (-3)*(-2) = 21
        run_test(
            -8'sd2, -8'sd3,
            -8'sd4, -8'sd1,
            -8'sd1, -8'sd5,
            -8'sd3, -8'sd2,
            18'sd21,
            "negative times negative"
        );

        // Test 4: Q4.4-style fractional values
        // 1.5*0.5 + (-1.0)*2.0 + 0.5*0.5 + 1.0*(-0.5) = -1.5
        // Q8.8 result => -1.5 * 256 = -384
        run_test(
            8'sd24,  8'sd8,
            -8'sd16, 8'sd32,
            8'sd8,   8'sd8,
            8'sd16,  -8'sd8,
            -18'sd384,
            "Q4.4 fractional values"
        );

        // Test 5: 50*2 + 40*2 + 30*2 + 20*2 = 280
        run_test(
            8'sd50, 8'sd2,
            8'sd40, 8'sd2,
            8'sd30, 8'sd2,
            8'sd20, 8'sd2,
            18'sd280,
            "larger positive sum"
        );

        $display("All tb_mac_unit tests passed.");
        $finish;
    end

endmodule