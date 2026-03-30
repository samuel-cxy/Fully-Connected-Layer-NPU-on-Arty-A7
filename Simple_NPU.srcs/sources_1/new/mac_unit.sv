// supports sum(i=0)^(3) w_i * x_i

(* use_dsp = "yes" *)
module mac_unit #(
    parameter int DATA_W = 8,          // 8 bits input and weight (Q4.4)
    parameter int PROD_W = 2 * DATA_W, // 8 bits x 8 bits = 16 bits (Q8.8)
    parameter int SUM_W = PROD_W + 2   // 4 numbers addtion +2 bits (Q10.8)
)(
    input logic signed [DATA_W-1:0] x0,
    input logic signed [DATA_W-1:0] w0,
    input logic signed [DATA_W-1:0] x1,
    input logic signed [DATA_W-1:0] w1,
    input logic signed [DATA_W-1:0] x2,
    input logic signed [DATA_W-1:0] w2,
    input logic signed [DATA_W-1:0] x3,
    input logic signed [DATA_W-1:0] w3,
    
    output logic signed [SUM_W-1:0] partial_sum
);

    logic signed [PROD_W-1:0] p0, p1, p2, p3;
    logic signed [SUM_W-1:0] s0, s1;
    
    always_comb begin
        p0 = w0 * x0;
        p1 = w1 * x1;
        p2 = w2 * x2;
        p3 = w3 * x3;
       
        s0 = p0 + p1;
        s1 = p2 + p3;
        
        partial_sum = s0 + s1;
    end 

endmodule
