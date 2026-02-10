`timescale 1ns / 1ps

module tb_top_cnn();

    // Simulation Signals
    logic clk = 0;
    logic rst_n = 0;
    logic i_valid = 0;
    logic [7:0] i_data = 0;
    
    // Internal Interconnect Signals
    logic win_valid;
    logic [7:0] win_data [0:8];      // Output from Sliding Window -> Input to MAC
    logic signed [7:0] weights [0:8];
    logic out_valid;
    logic signed [31:0] out_result;  // Final Convolution Result

    // ------------------------------------------------
    // 1. Instantiate Sliding Window (Line Buffer)
    // ------------------------------------------------
    // Set IMG_WIDTH to 5 for easier simulation waveform analysis.
    sliding_window #(.IMG_WIDTH(5), .DATA_WIDTH(8)) u_window (
        .clk(clk), 
        .rst_n(rst_n),
        .i_valid(i_valid), 
        .i_data(i_data),
        .o_valid(win_valid), 
        .o_window(win_data)
    );

    // ------------------------------------------------
    // 2. Instantiate Convolution MAC Unit
    // ------------------------------------------------
    conv_mac u_mac (
        .clk(clk), 
        .rst_n(rst_n),
        .i_valid(win_valid), // Start calculation when window is ready
        .i_window(win_data),
        .i_weights(weights),
        .o_valid(out_valid),
        .o_result(out_result)
    );

    // Clock Generation (10ns period -> 100MHz)
    always #5 clk = ~clk;

    initial begin
        // ------------------------------------------------
        // Initialize Weights (Edge Detection Filter)
        // Kernel:
        // -1 -1 -1
        // -1  8 -1
        // -1 -1 -1
        // This filter highlights changes in pixel intensity (edges).
        // ------------------------------------------------
        for(int k=0; k<9; k++) weights[k] = -1;
        weights[4] = 8; // Center weight

        // Reset Sequence
        rst_n = 0;
        #20 rst_n = 1;

        // ------------------------------------------------
        // Test Case 1: Flat Area (No Edge)
        // Input constant value 10.
        // Expected Result: (10*8) - (10*8) = 0 (or close to 0)
        // ------------------------------------------------
        $display("Starting Test 1: Flat Input...");
        for (int i=1; i<=50; i++) begin
            @(posedge clk);
            i_valid = 1;
            i_data = 10; 
        end
        
        // ------------------------------------------------
        // Test Case 2: Vertical Edge
        // Input sudden change to 255.
        // Expected Result: High positive or negative value due to the edge.
        // ------------------------------------------------
        $display("Starting Test 2: Edge Input (255)...");
        for (int i=1; i<=10; i++) begin
            @(posedge clk);
            i_valid = 1;
            i_data = 255; 
        end

        // End Simulation
        @(posedge clk);
        i_valid = 0;
        #100;
        $finish;
    end

endmodule