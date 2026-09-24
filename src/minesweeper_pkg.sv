package minesweeper_pkg;

typedef struct packed {
    logic [3:0] value;      //Values 0 to 8
    logic visited;          //Visited in flood search
    logic flag;             //Tile has a flag
    logic is_mine;          //Tile has a mine
    logic is_open;          //Tile is open
    logic clicked;          //Clicked tile (to determine if the bomb was clicked)
} tile_t;

localparam int BOARD_HEIGHT = 16;   //Can be any number
localparam int BOARD_WIDTH = 8;    //Keep as power of 2

typedef logic [$clog2(BOARD_WIDTH)-1:0] gridx_coord_t; 
typedef logic [$clog2(BOARD_HEIGHT)-1:0] gridy_coord_t;

typedef logic [3:0] colour_t;
typedef logic [3:0] sprite_t;

typedef logic signed [10:0] screen_coord_t;


//This function decodes the tile into the sprite ID, to display the correct tile type
//Takes a tile as an argument, returns the ID of the sprite (sprite base address)
function automatic sprite_t get_tile_sprite_id(input tile_t tile);
    if (~tile.is_open) begin
        if (tile.flag) begin
            return 4'd1;        //Return flag tile
        end else begin
            return 4'd0;        //Return closed tile
        end
    end else begin
        if (tile.is_mine) begin
            if (tile.clicked) return 4'd3;      //If clicked then this mine exploded
            else return 4'd2;                   //Otherwise standard mine
        end else begin
            if (tile.flag) return 4'd4;         //A tile can only be opened AND a flag at the end of the game. This is an incorrect flag 
            else return (4'd5 + tile.value);      //Return number. tile.value = 0 is a blank (0) tile
        end
    end
endfunction


endpackage
