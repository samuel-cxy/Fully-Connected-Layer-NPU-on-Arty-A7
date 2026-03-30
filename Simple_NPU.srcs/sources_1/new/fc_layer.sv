`timescale 1ns/1ps

module fc_layer #(
    // Basic datapath parameters
    parameter int DATA_W = 8,              // width of x, w, b
    parameter int PROD_W = 2 * DATA_W,     // width of x * w
    parameter int SUM_W  = PROD_W + 2,     // width of sum of 4 products
    parameter int ACC_W  = SUM_W + 2,      // width of accumulator
    parameter int N_IN   = 8,              // number of input features
    parameter int N_OUT  = 4               // number of output neurons
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,

    output logic done,

    // Final outputs of the 4-neuron fully connected layer
    output logic signed [ACC_W-1:0] y0,
    output logic signed [ACC_W-1:0] y1,
    output logic signed [ACC_W-1:0] y2,
    output logic signed [ACC_W-1:0] y3
);

    // =========================================================
    // FSM state encoding
    // =========================================================
    //
    // IDLE          : wait for start pulse
    // CLEAR_ACC     : clear accumulator before computing a neuron
    // LOAD_OPS      : read x/w values from memory into operand registers
    // MAC_CAPTURE   : compute 4-lane partial sum and register it
    // MAC_ACCUM     : add the partial sum into the running accumulator
    // ADD_BIAS      : add neuron bias
    // ACTIVATE_STORE: apply ReLU and store output
    // FINISH        : pulse done for one cycle
    //
    typedef enum logic [3:0] {
        IDLE,
        CLEAR_ACC,
        LOAD_OPS,
        MAC_CAPTURE,
        MAC_ACCUM,
        ADD_BIAS,
        ACTIVATE_STORE,
        FINISH
    } state_t;

    state_t state, next_state;

    // =========================================================
    // Main control/data registers
    // =========================================================

    logic [$clog2(N_OUT)-1:0] out_idx;  // which output neuron is being computed
    logic                     chunk_idx; // 0 -> inputs [0:3], 1 -> inputs [4:7]

    logic signed [ACC_W-1:0] acc_reg;          // running accumulated value
    logic signed [ACC_W-1:0] bias_ext;         // sign-extended bias
    logic signed [ACC_W-1:0] relu_in, relu_out;

    logic signed [SUM_W-1:0] partial_sum;      // raw 4-lane MAC result
    logic signed [SUM_W-1:0] partial_sum_reg;  // registered MAC result

    // =========================================================
    // Memory-based storage
    // =========================================================
    //
    // x_mem : 8 input values
    // w_mem : 32 weights, flattened as:
    //         neuron0[0:7], neuron1[0:7], neuron2[0:7], neuron3[0:7]
    // b_mem : 4 biases
    //
    logic signed [DATA_W-1:0] x_mem [0:N_IN-1];
    logic signed [DATA_W-1:0] w_mem [0:(N_OUT*N_IN)-1];
    logic signed [DATA_W-1:0] b_mem [0:N_OUT-1];

    // Output storage for the 4 neurons
    logic signed [ACC_W-1:0] y [0:N_OUT-1];

    // =========================================================
    // Operand pipeline registers
    // =========================================================
    //
    // These are used to break the timing path:
    // memory read -> MAC -> accumulator
    //
    // Stage 1: LOAD_OPS     -> load x/w into these registers
    // Stage 2: MAC_CAPTURE  -> compute partial_sum and register it
    // Stage 3: MAC_ACCUM    -> acc_reg += partial_sum_reg
    //
    logic signed [DATA_W-1:0] x0_reg, x1_reg, x2_reg, x3_reg;
    logic signed [DATA_W-1:0] w0_reg, w1_reg, w2_reg, w3_reg;

    // Base address into flattened weight memory for current neuron
    logic [$clog2(N_OUT*N_IN)-1:0] w_base;

    integer i;

    // =========================================================
    // Load input / weight / bias memories from external .mem files
    // =========================================================
    //
    // These files should be added to the Vivado project:
    // - x.mem
    // - w.mem
    // - b.mem
    //
    initial begin
        $readmemh("x.mem", x_mem);
        $readmemh("w.mem", w_mem);
        $readmemh("b.mem", b_mem);
    end

    // =========================================================
    // Compute starting weight address for current neuron
    // =========================================================
    //
    // Since N_IN = 8, each neuron owns 8 consecutive weights.
    // So the base address is out_idx * 8.
    //
    always_comb begin
        w_base = out_idx << 3;
    end

    // =========================================================
    // 4-lane MAC block
    // =========================================================
    //
    // This computes:
    // partial_sum = x0*w0 + x1*w1 + x2*w2 + x3*w3
    //
    // Inputs come from the registered operand stage.
    //
    mac_unit #(
        .DATA_W(DATA_W),
        .PROD_W(PROD_W),
        .SUM_W (SUM_W)
    ) u_mac (
        .x0(x0_reg), .w0(w0_reg),
        .x1(x1_reg), .w1(w1_reg),
        .x2(x2_reg), .w2(w2_reg),
        .x3(x3_reg), .w3(w3_reg),
        .partial_sum(partial_sum)
    );

    // =========================================================
    // ReLU activation
    // =========================================================
    //
    // relu_out = max(acc_reg, 0)
    //
    relu #(
        .DATA_W(ACC_W)
    ) u_relu (
        .in (relu_in),
        .out(relu_out)
    );

    // Bias comes from b_mem and is sign-extended to accumulator width
    assign bias_ext = b_mem[out_idx];

    // ReLU input is just the current accumulator
    assign relu_in = acc_reg;

    // =========================================================
    // Next-state logic
    // =========================================================
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start)
                    next_state = CLEAR_ACC;
            end

            CLEAR_ACC: begin
                next_state = LOAD_OPS;
            end

            LOAD_OPS: begin
                next_state = MAC_CAPTURE;
            end

            MAC_CAPTURE: begin
                next_state = MAC_ACCUM;
            end

            MAC_ACCUM: begin
                // After chunk 0, do chunk 1
                // After chunk 1, move on to bias add
                if (chunk_idx == 1'b1)
                    next_state = ADD_BIAS;
                else
                    next_state = LOAD_OPS;
            end

            ADD_BIAS: begin
                next_state = ACTIVATE_STORE;
            end

            ACTIVATE_STORE: begin
                if (out_idx == N_OUT-1)
                    next_state = FINISH;
                else
                    next_state = CLEAR_ACC;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // =========================================================
    // Main sequential logic
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= IDLE;
            out_idx         <= '0;
            chunk_idx       <= 1'b0;
            acc_reg         <= '0;
            partial_sum_reg <= '0;
            done            <= 1'b0;

            // Clear operand pipeline registers
            x0_reg <= '0; x1_reg <= '0; x2_reg <= '0; x3_reg <= '0;
            w0_reg <= '0; w1_reg <= '0; w2_reg <= '0; w3_reg <= '0;

            // Clear final outputs
            for (i = 0; i < N_OUT; i = i + 1) begin
                y[i] <= '0;
            end
        end
        else begin
            state <= next_state;
            done  <= 1'b0;  // only pulse done in FINISH

            case (state)
                IDLE: begin
                    // Keep datapath cleared while waiting for start
                    acc_reg   <= '0;
                    chunk_idx <= 1'b0;

                    // Start always begins from neuron 0
                    if (start)
                        out_idx <= '0;
                end

                CLEAR_ACC: begin
                    // Start a new neuron computation
                    acc_reg   <= '0;
                    chunk_idx <= 1'b0;
                end

                LOAD_OPS: begin
                    // Load the 4 inputs + 4 weights for the current chunk
                    if (chunk_idx == 1'b0) begin
                        // First chunk: inputs 0..3
                        x0_reg <= x_mem[0];  w0_reg <= w_mem[w_base + 0];
                        x1_reg <= x_mem[1];  w1_reg <= w_mem[w_base + 1];
                        x2_reg <= x_mem[2];  w2_reg <= w_mem[w_base + 2];
                        x3_reg <= x_mem[3];  w3_reg <= w_mem[w_base + 3];
                    end
                    else begin
                        // Second chunk: inputs 4..7
                        x0_reg <= x_mem[4];  w0_reg <= w_mem[w_base + 4];
                        x1_reg <= x_mem[5];  w1_reg <= w_mem[w_base + 5];
                        x2_reg <= x_mem[6];  w2_reg <= w_mem[w_base + 6];
                        x3_reg <= x_mem[7];  w3_reg <= w_mem[w_base + 7];
                    end
                end

                MAC_CAPTURE: begin
                    // Capture the 4-lane MAC result into a register
                    partial_sum_reg <= partial_sum;
                end

                MAC_ACCUM: begin
                    // Add this chunk's MAC result into the accumulator
                    acc_reg <= acc_reg + partial_sum_reg;

                    // Move from chunk 0 to chunk 1
                    if (chunk_idx == 1'b0)
                        chunk_idx <= 1'b1;
                end

                ADD_BIAS: begin
                    // Add the bias for the current neuron
                    acc_reg <= acc_reg + bias_ext;
                end

                ACTIVATE_STORE: begin
                    // Apply ReLU and store the completed neuron output
                    y[out_idx] <= relu_out;

                    // Move to next output neuron if not finished
                    if (out_idx != N_OUT-1)
                        out_idx <= out_idx + 1'b1;
                end

                FINISH: begin
                    // Signal that all 4 outputs are done
                    done <= 1'b1;
                end

                default: begin
                    ;
                end
            endcase
        end
    end

    // =========================================================
    // Output port mapping
    // =========================================================
    assign y0 = y[0];
    assign y1 = y[1];
    assign y2 = y[2];
    assign y3 = y[3];

endmodule