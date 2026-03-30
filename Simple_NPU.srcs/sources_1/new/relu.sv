module relu #(
    parameter int DATA_W = 24 // for accumulator to avoid overflow 
)(
    input logic signed [DATA_W-1:0] in,
    output logic signed [DATA_W-1:0] out
);

    always_comb begin
        if (in < 0)
            out = '0;
        else
            out = in;
    end

endmodule