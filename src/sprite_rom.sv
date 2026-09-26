`timescale 1ns / 1ps
`default_nettype none

//This module is a BRAM that contains the sprite memory.
//The tiles sprites are 16x16 each, with a total of 14 unique tiles

module sprite_rom 
import minesweeper_pkg::*;
#(
    parameter SPRITE_W,
    parameter SPRITE_H,
    parameter N_SPRITES,
    parameter ADDR_W
)
(
    input wire logic clk,
    input wire logic [ADDR_W-1 : 0] addr, 
    output colour_t colour
);

//Each address stores one 4-bit colour index

colour_t rom [0:SPRITE_H*SPRITE_W*N_SPRITES-1];

initial begin
    $readmemh("./mem/tiles_sprite.mem", rom);
end

always_ff @(posedge clk) begin
    colour <= rom[addr];
end

endmodule
