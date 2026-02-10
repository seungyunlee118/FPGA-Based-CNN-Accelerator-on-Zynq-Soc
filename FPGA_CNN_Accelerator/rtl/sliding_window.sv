`timescale 1ns / 1ps

module sliding_window #(
    parameter int DATA_WIDTH = 8,   
    parameter int IMG_WIDTH  = 28    
)(
    input  logic                   clk,
    input  logic                   rst_n,    
    
    // Input Stream 
    input  logic                   i_valid,  
    input  logic [DATA_WIDTH-1:0]  i_data,   
    
    // Output Window (3x3 Flattened)
    output logic                   o_valid,  
    output logic [DATA_WIDTH-1:0]  o_window [0:8] 
);

    // ---------------------------------------------------------
    // 1. Line Buffers 
    // ---------------------------------------------------------
    // Use Packed Array to prevent simulation race conditions during shift.
    // Index [IMG_WIDTH-1] holds the oldest data, [0] holds the newest.
    logic [IMG_WIDTH-1:0][DATA_WIDTH-1:0] line_buf_0; // Row N-1
    logic [IMG_WIDTH-1:0][DATA_WIDTH-1:0] line_buf_1; // Row N-2

    // ---------------------------------------------------------
    // 2. Window Registers (3x3)
    // ---------------------------------------------------------
    logic [DATA_WIDTH-1:0] window [0:2][0:2];

    // Internal Counters
    logic [$clog2(IMG_WIDTH)-1:0] x_cnt;
    logic [$clog2(IMG_WIDTH)-1:0] y_cnt; 
    logic                         warmup_done; 

    // ---------------------------------------------------------
    // 3. Main Logic
    // ---------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0;
            y_cnt <= 0;
            o_valid <= 0;
            warmup_done <= 0;
            
            // Initialize buffers and window
            line_buf_0 <= '{default:0};
            line_buf_1 <= '{default:0};
            
            for (int r=0; r<3; r++) begin
                for (int c=0; c<3; c++) window[r][c] <= 0;
            end
        end
        else if (i_valid) begin
            // ------------------------------------
            // A. Line Buffer Shift (Concatenation)
            // ------------------------------------
            // Shift data: {Old Data[MSB-1:0], New Data}
            // This ensures atomic updates and prevents simulation glitches.
            
            // 1. Update Line Buffer 0 (Receive current input)
            line_buf_0 <= {line_buf_0[IMG_WIDTH-2:0], i_data};
            
            // 2. Update Line Buffer 1 (Receive oldest data from Buf 0)
            // line_buf_0[IMG_WIDTH-1] is the pixel leaving the previous row.
            line_buf_1 <= {line_buf_1[IMG_WIDTH-2:0], line_buf_0[IMG_WIDTH-1]};

            // ------------------------------------
            // B. Update Sliding Window (3x3)
            // ------------------------------------
            // [Row 0] Top Row <- Oldest data from Line Buffer 1
            window[0][0] <= line_buf_1[IMG_WIDTH-1]; 
            window[0][1] <= window[0][0];            
            window[0][2] <= window[0][1];

            // [Row 1] Mid Row <- Oldest data from Line Buffer 0
            window[1][0] <= line_buf_0[IMG_WIDTH-1]; 
            window[1][1] <= window[1][0];
            window[1][2] <= window[1][1];

            // [Row 2] Bot Row <- Current Input (i_data)
            window[2][0] <= i_data;
            window[2][1] <= window[2][0];
            window[2][2] <= window[2][1];

            // ------------------------------------
            // C. Coordinate Counter & Validity
            // ------------------------------------
            if (x_cnt == IMG_WIDTH - 1) begin
                x_cnt <= 0;
                y_cnt <= y_cnt + 1; 
                
                if (y_cnt >= 2) warmup_done <= 1; 
            end
            else begin
                x_cnt <= x_cnt + 1;
            end

            // Generate Valid Signal
            // Valid only when buffer is full (warmup done) OR reaching end of 3rd row,
            // AND x position is valid (shifted enough for 3x3 window).
            if ((warmup_done || y_cnt >= 2) && x_cnt >= 2) 
                o_valid <= 1;
            else
                o_valid <= 0;
        end 
        else begin
            o_valid <= 0;
        end
    end

    // ---------------------------------------------------------
    // 4. Output Assignment
    // ---------------------------------------------------------
    // Map 2D window to 1D output array.
    // Window[r][2] is the oldest pixel (Left), Window[r][0] is the newest (Right).
    always_comb begin
        o_window[0] = window[0][2]; o_window[1] = window[0][1]; o_window[2] = window[0][0];
        o_window[3] = window[1][2]; o_window[4] = window[1][1]; o_window[5] = window[1][0];
        o_window[6] = window[2][2]; o_window[7] = window[2][1]; o_window[8] = window[2][0];
    end

endmodule