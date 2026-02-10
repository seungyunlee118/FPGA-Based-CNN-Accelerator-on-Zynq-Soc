`timescale 1ns / 1ps

module tb_sliding_window();

    logic clk = 0;
    logic rst_n = 0;
    logic i_valid = 0;
    logic [7:0] i_data = 0;
    logic o_valid;
    logic [7:0] o_window [0:8]; // packed array

    sliding_window #(.IMG_WIDTH(5), .DATA_WIDTH(8)) uut (
        .clk(clk), .rst_n(rst_n),
        .i_valid(i_valid), .i_data(i_data),
        .o_valid(o_valid), .o_window(o_window)
    );

    always #5 clk = ~clk; // 10ns Clock

    initial begin
        rst_n = 0;
        #20 rst_n = 1;

        
        for (int i=1; i<=25; i++) begin
            @(posedge clk);
            i_valid = 1;
            i_data = i;
        end
        
        @(posedge clk);
        i_valid = 0;
        #50;
        $finish;
    end

endmodule