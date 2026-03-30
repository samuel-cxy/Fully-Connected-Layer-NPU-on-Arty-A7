`timescale 1ns/1ps

module npu_top (
    input logic CLK100MHZ,
    input logic [1:0] btn,   // btn[0]=reset, btn[1]=start
    output logic [3:0] led
);

    parameter int DATA_W = 8;
    parameter int PROD_W = 2 * DATA_W;
    parameter int SUM_W = PROD_W + 2;
    parameter int ACC_W = SUM_W + 2;
    parameter int N_IN = 8;
    parameter int N_OUT = 4;

    logic clk;
    logic rst_n;

    logic btn_start_ff0, btn_start_ff1, btn_start_ff1_d;
    logic start_pulse;

    logic done;
    logic done_latched;

    logic signed [ACC_W-1:0] y0;
    logic signed [ACC_W-1:0] y1;
    logic signed [ACC_W-1:0] y2;
    logic signed [ACC_W-1:0] y3;

    logic [3:0] sig_now;
    logic [3:0] sig_latched;

    assign clk = CLK100MHZ;
    assign rst_n = ~btn[0];

    // Synchronize start button and create 1-cycle pulse
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_start_ff0 <= 1'b0;
            btn_start_ff1 <= 1'b0;
            btn_start_ff1_d <= 1'b0;
        end
        else begin
            btn_start_ff0 <= btn[1];
            btn_start_ff1 <= btn_start_ff0;
            btn_start_ff1_d <= btn_start_ff1;
        end
    end

    assign start_pulse = btn_start_ff1 & ~btn_start_ff1_d;

    fc_layer #(
        .DATA_W(DATA_W),
        .PROD_W(PROD_W),
        .SUM_W(SUM_W),
        .ACC_W(ACC_W),
        .N_IN(N_IN),
        .N_OUT(N_OUT)
    ) u_fc_layer (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start_pulse),
        .done (done),
        .y0(y0),
        .y1(y1),
        .y2(y2),
        .y3(y3)
    );

    // Small signature so all outputs affect LEDs
    assign sig_now[0] = ^y0;
    assign sig_now[1] = ^y1;
    assign sig_now[2] = ^y2;
    assign sig_now[3] = ^y3;

    // Latch done and LED pattern so result stays visible
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_latched <= 1'b0;
            sig_latched  <= 4'b0000;
        end
        else begin
            if (start_pulse) begin
                done_latched <= 1'b0;
                sig_latched  <= 4'b0000;
            end
            else if (done) begin
                done_latched <= 1'b1;
                sig_latched  <= sig_now;
            end
        end
    end

    assign led = done_latched ? sig_latched : 4'b0000;

endmodule