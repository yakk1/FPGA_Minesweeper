//This module is a BRAM that contains the sprite memory.
//The tiles sprites are 16x16 each, with a total of 14 unique tiles

module sprite_rom 
import minesweeper_pkg::*;
(
    input logic clk,
    input sprite_t sprite_id,
    input logic [3:0] sprite_x,
    input logic [3:0] sprite_y,
    output colour_t colour
);

//Each address stores one 4-bit colour index
//The sprite ID represents the base address for the specific tile sprite

colour_t rom [0:4095];

initial begin
    $readmemh("sprite_rom.mem", rom);
end

always_ff @(posedge clk) begin
    colour <= rom[{sprite_id, sprite_y, sprite_x}];
end

endmodule