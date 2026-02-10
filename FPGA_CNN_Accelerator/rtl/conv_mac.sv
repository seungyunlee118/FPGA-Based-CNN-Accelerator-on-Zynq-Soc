`timescale 1ns / 1ps

module conv_mac #(
    parameter int DATA_WIDTH = 8,
    parameter int OUT_WIDTH  = 32 // Output width (accumulated result can be large)
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   i_valid, // Valid signal from sliding window
    
    // 9 Pixels from Sliding Window (Flattened 3x3)
    input  logic [DATA_WIDTH-1:0]  i_window [0:8],
    
    // 9 Weights (Signed 8-bit)
    // For a real design, these might come from a register file or memory.
    input  logic signed [7:0]      i_weights [0:8], 

    output logic                   o_valid,
    output logic signed [OUT_WIDTH-1:0] o_result
);

    // ------------------------------------------------
    // Pipeline Stage 1: Multiplication
    // ------------------------------------------------
    // Perform 9 multiplications in parallel (Hardware Parallelism).
    // This typically maps to DSP slices in FPGA.
    logic signed [OUT_WIDTH-1:0] mult_results [0:8];
    logic                        valid_stage1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage1 <= 0;
            for(int i=0; i<9; i++) mult_results[i] <= 0;
        end
        else begin
            valid_stage1 <= i_valid;
            
            if (i_valid) begin
                // Multiply Unsigned Pixel * Signed Weight
                for(int i=0; i<9; i++) begin
                    // Convert unsigned pixel to signed by prepending 0, then multiply.
                    mult_results[i] <= $signed({1'b0, i_window[i]}) * i_weights[i];
                end
            end
        end
    end

    // ------------------------------------------------
    // Pipeline Stage 2: Accumulation (Adder Tree)
    // ------------------------------------------------
    // Sum all 9 multiplication results.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_valid <= 0;
            o_result <= 0;
        end
        else begin
            o_valid <= valid_stage1;
            
            if (valid_stage1) begin
                // Simple addition of all 9 values.
                // For higher clock speeds, this can be split into more pipeline stages (Adder Tree).
                o_result <= mult_results[0] + mult_results[1] + mult_results[2] +
                            mult_results[3] + mult_results[4] + mult_results[5] +
                            mult_results[6] + mult_results[7] + mult_results[8];
            end
        end
    end

endmodule