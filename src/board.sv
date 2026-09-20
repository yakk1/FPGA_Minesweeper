
//Board module
//The board is a dual port BRAM that stores every tile
//Port B is read only

module board 
import minesweeper_pkg::*;
(

    //PORT A (Game handler)
    input logic clk_a,
    input logic we_a,
    input x_coord_t coord_x_a,
    input y_coord_t coord_y_a,
    input tile_t din_a,
    output tile_t dout_a,

    //PORT B (VGA)
    input logic clk_b,
    //input logic we_b,
    input x_coord_t coord_x_b,
    input y_coord_t coord_y_b,
    //input tile_t din_b,
    output tile_t dout_b
);

localparam N_TILES = BOARD_HEIGHT*BOARD_WIDTH;
localparam ADDR_BITS = $clog2(N_TILES);

tile_t mem [0:N_TILES-1];
logic [ADDR_BITS-1:0] porta_addr;
logic [ADDR_BITS-1:0] portb_addr;

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

//Port B
always_ff @(posedge clk_b) begin
    //if (we_b) begin
    //    mem[portb_addr] <= din_b;
    //end 
    dout_b <= mem[portb_addr];
end

endmodule
