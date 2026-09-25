//This module is a BRAM that contains the sprite memory.
//The tiles sprites are 16x16 each, with a total of 14 unique tiles

module sprite_rom 
import minesweeper_pkg::*;
#(
    parameter SPRITE_W;
    parameter SPRITE_H;
    parameter N_SPRITES;
    parameter ADDR_W;
)
(
    input logic clk,
    input logic [ADDR_W-1 : 0] addr, 
    output colour_t colour
);

//Each address stores one 4-bit colour index

colour_t rom [0:SPRITE_H*SPRITE_W*N_SPRITES-1];

initial begin
    $readmemh("sprite_rom.mem", rom);
end

always_ff @(posedge clk) begin
    colour <= rom[{sprite_id, sprite_y, sprite_x}];
end

endmodule