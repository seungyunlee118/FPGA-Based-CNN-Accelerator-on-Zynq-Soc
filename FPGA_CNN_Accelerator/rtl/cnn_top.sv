`timescale 1ns / 1ps

module cnn_top #(
    parameter int DATA_WIDTH = 8,
    parameter int OUT_WIDTH  = 32,
    parameter int IMG_WIDTH  = 28  // Set this to 28 for MNIST
)(
    input  logic                   clk,
    input  logic                   rst_n,

    // ---------------------------------------------------------
    // Slave AXI-Stream Interface (Input from Zynq DMA)
    // ---------------------------------------------------------
    input  logic [DATA_WIDTH-1:0]  s_axis_tdata,   // Input Pixel
    input  logic                   s_axis_tvalid,  // Data Valid
    output logic                   s_axis_tready,  // Ready (We are always ready)

    // ---------------------------------------------------------
    // Master AXI-Stream Interface (Output to Zynq DMA)
    // ---------------------------------------------------------
    output logic [OUT_WIDTH-1:0]   m_axis_tdata,   // Result Pixel
    output logic                   m_axis_tvalid,  // Result Valid
    input  logic                   m_axis_tready,  // Downstream Ready (Ignored for simple version)
    output logic                   m_axis_tlast    // End of packet (Optional, tied to 0 for now)
);

    // Internal Signals
    logic                  win_valid;
    logic [DATA_WIDTH-1:0] win_data [0:8];
    logic signed [7:0]     weights  [0:8];

    // ---------------------------------------------------------
    // 1. AXI-Stream Control Logic
    // ---------------------------------------------------------
    // For this simple version, we assume we are always ready to receive data.
    // In a complex design, we would check if the pipeline is stalled.
    assign s_axis_tready = 1'b1; 
    assign m_axis_tlast  = 1'b0; // Not used for now

    // ---------------------------------------------------------
    // 2. Hard-coded Weights (Edge Detection Kernel)
    // ---------------------------------------------------------
    // -1 -1 -1
    // -1  8 -1
    // -1 -1 -1
    initial begin
        weights[0] = -8'sd1; weights[1] = -8'sd1; weights[2] = -8'sd1;
        weights[3] = -8'sd1; weights[4] =  8'sd8; weights[5] = -8'sd1;
        weights[6] = -8'sd1; weights[7] = -8'sd1; weights[8] = -8'sd1;
    end

    // ---------------------------------------------------------
    // 3. Instantiate Sliding Window (Line Buffer)
    // ---------------------------------------------------------
    sliding_window #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH(IMG_WIDTH)
    ) u_sliding_window (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(s_axis_tvalid),  // Connect directly to AXI Valid
        .i_data(s_axis_tdata),    // Connect directly to AXI Data
        .o_valid(win_valid),
        .o_window(win_data)
    );

    // ---------------------------------------------------------
    // 4. Instantiate Conv MAC (Calculation)
    // ---------------------------------------------------------
    conv_mac #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_conv_mac (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(win_valid),
        .i_window(win_data),
        .i_weights(weights),      // Use hard-coded weights
        .o_valid(m_axis_tvalid),  // Output Valid -> AXI Master Valid
        .o_result(m_axis_tdata)   // Output Result -> AXI Master Data
    );

endmodule