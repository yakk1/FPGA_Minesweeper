`timescale 1ns / 1ps
`default_nettype none

//Board module
//The board is a dual port BRAM that stores every tile
//Port B is read only

module board 
import minesweeper_pkg::*;
(

    //PORT A (Game handler)
    input wire logic clk_a,
    input wire logic we_a,
    input wire gridx_coord_t coord_x_a,
    input wire gridy_coord_t coord_y_a,
    input tile_t din_a,
    output tile_t dout_a,

    //PORT B (VGA)
    input wire logic clk_b,
    //input logic we_b,
    input wire gridx_coord_t coord_x_b,
    input wire gridy_coord_t coord_y_b,
    //input tile_t din_b,
    output tile_t dout_b
);

localparam ADDR_BITS = $clog2(N_TILES);

tile_t mem [N_TILES-1:0];
logic [ADDR_BITS-1:0] porta_addr;
logic [ADDR_BITS-1:0] portb_addr;

initial begin

    for (int i = 0; i < N_TILES; i++) begin
        mem[i] = 9'b000001000;
    end
    
    mem[0] = 9'b000000010;
    mem[1] = 9'b000100010;
    mem[2] = 9'b001000010;
    mem[3] = 9'b001100010;
    mem[4] = 9'b010000010;
    mem[5] = 9'b010100010;
    mem[6] = 9'b011000010;
    mem[7] = 9'b011100010;
    mem[8] = 9'b100000010;
end

//Calculate memory addresses from coordinates. Note board width is a power of 2
//Concatenation is the equivalent of bit shifting the y coordinate and adding x coordinate
assign porta_addr = {coord_y_a, coord_x_a};
assign portb_addr = {coord_y_b, coord_x_b};

//BRAM Inference

//Port A
always_ff @(posedge clk_a) begin
    if (we_a) begin
        mem[porta_addr] <= din_a;
    end 
    dout_a <= mem[porta_addr];
end

//Port B (Read Only)
always_ff @(posedge clk_b) begin
    //if (we_b) begin
    //    mem[portb_addr] <= din_b;
    //end 
    dout_b <= mem[portb_addr];
end

endmodule
