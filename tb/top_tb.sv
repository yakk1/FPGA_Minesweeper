`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.09.2026 10:07:06
// Design Name: 
// Module Name: top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_tb();

bit clk;
logic rst;

top dut
(
    .clk_125m(clk),
    .btn_rst(rst)
);


initial begin
    forever #8 clk = ~clk;
end

initial begin
    rst = 1;
    # 100
    rst = 0;
end




endmodule
