package minesweeper_pkg;

typedef struct packed {
    logic [2:0] value;      //Values 0 to 8
    logic visited;          //Visited in flood search
    logic flag;             //Tile has a flag
    logic is_mine;          //Tile has a mine
    logic is_open;          //Tile is open
} tile_t;

localparam int BOARD_HEIGHT = 16;   //Can be any number
localparam int BOARD_WIDTH = 16;    //Keep as power of 2

typedef logic [$clog2(BOARD_WIDTH)-1:0] x_coord_t; 
typedef logic [$clog2(BOARD_HEIGHT)-1:0] y_coord_t; 

endpackage
