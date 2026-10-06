`timescale 1ns / 1ps
`default_nettype none

package minesweeper_pkg;

typedef struct packed {
    logic [3:0] value;      //Values 0 to 8
    logic visited;          //Visited in flood search
    logic flag;             //Tile has a flag
    logic is_mine;          //Tile has a mine
    logic is_open;          //Tile is open
    logic clicked;          //Clicked tile (to determine if the bomb was clicked)
} tile_t;

// Game Definition
localparam logic [3:0] BACKGROUND_COLOUR = 4'h4;
localparam int SCREEN_WIDTH = 640;
localparam int SCREEN_HEIGHT = 480;

// Board definition
localparam int BOARD_HEIGHT = 16;   //Can be any number
localparam int BOARD_WIDTH = 32;    //Keep as power of 2
localparam int N_TILES = BOARD_HEIGHT*BOARD_WIDTH;

// Coordinate definitions
typedef logic [$clog2(BOARD_WIDTH)-1:0] gridx_coord_t; 
typedef logic [$clog2(BOARD_HEIGHT)-1:0] gridy_coord_t;

typedef logic [3:0] colour_t;
typedef logic signed [10:0] screen_coord_t;
//typedef logic [9:0] u_screen_cord_t;

// Tiles Definitions
localparam int TILE_WIDTH = 16;
localparam int TILE_HEIGHT = 16;
localparam int N_TILE_SPRITES = 14;
typedef logic [3:0] tile_id_t;

// Face Definitions
localparam int FACE_WIDTH = 24;
localparam int FACE_HEIGHT = 24;
localparam int N_FACES_SPRITES = 5;
typedef logic [2:0] face_id_t; 

// LCD Number Definitions
localparam int NUM_WIDTH = 13;
localparam int NUM_HEIGHT = 23;
localparam int N_NUMS_SPRITES = 12;
typedef logic [3:0] digit_id_t;

// Mouse Definitions
localparam int MOUSE_WIDTH = 32;
localparam int MOUSE_HEIGHT = 32;

typedef logic [11:0] lcd_count_t; //BCD encoded 

// Setup grid offset
localparam int GRID_OFFSET_X = (640 - BOARD_WIDTH*TILE_WIDTH)/2;       // Grid is horizontlly in screen center 
localparam int GRID_OFFSET_Y = (480 - BOARD_HEIGHT*TILE_HEIGHT)/2 + 50; // Not in the center (due to the face)

// Setup face button offset
localparam int FACE_OFFSET_FROM_GRID = 50;                             // Number of pixels above top of grid
localparam int FACE_OFFSET_X = (640 - FACE_WIDTH)/2;                    
localparam int FACE_OFFSET_Y = GRID_OFFSET_Y - FACE_OFFSET_FROM_GRID;

// Setup 3 digit display offsets (note there are two)
localparam int DIGIT_OFFSET_Y = FACE_OFFSET_Y;
localparam int DIGIT1_OFFSET_X = GRID_OFFSET_X + TILE_WIDTH/2;
localparam int DIGIT2_OFFSET_X = GRID_OFFSET_X + (BOARD_WIDTH * TILE_WIDTH) - TILE_WIDTH/2 - 3*NUM_WIDTH;

// Game flags and control data bus
typedef struct packed {
    screen_coord_t mouse_x;
    screen_coord_t mouse_y;
    face_id_t face_id;
    lcd_count_t left_count_value;
    lcd_count_t right_count_value;
    logic show_mines;
} databus_t;

//This function decodes the tile into the sprite ID, to display the correct tile type
//Takes a tile as an argument, returns the ID of the sprite (sprite base address)
localparam logic DEBUG_OPEN_ALL = 1'b1;

function automatic tile_id_t get_tile_sprite_id(input tile_t tile, input logic show_mines);
    if (~(tile.is_open | DEBUG_OPEN_ALL)) begin
        if (show_mines) begin
            if (tile.is_mine) begin
                if (tile.clicked) return 4'd3;      //Clicked mine (red exploded mine)
                else if (tile.flag) return 4'd1;    //Correctly flagged mine stays a flag
                else return 4'd2;                   //Unflagged mine is revealed
            end else begin
                if (tile.flag) return 4'd4;         //Incorrect flag (crossed-out mine)
                else return 4'd0;                   //Unopened safe tile stays closed
            end
        end else begin
            if (tile.flag) return 4'd1;             //Return flag tile
            else return 4'd0;                       //Return closed tile
        end
    end else begin
        if (tile.is_mine) begin
            if (tile.clicked) return 4'd3;          //If clicked then this mine exploded
            else return 4'd2;                       //Otherwise standard mine
        end else begin
            if (tile.flag) return 4'd4;             //Incorrect flag if tile was opened
            else return (4'd5 + tile.value);        //Return number. tile.value = 0 is a blank (0) tile
        end
    end
endfunction

// Convert 4 bit BCD to a digit id for sprite (Only non 1-to-1 is the negative sign)
function automatic digit_id_t get_digit_sprite_id(input logic [3:0] nibble);
    digit_id_t out = nibble;
    
    if (nibble == 4'hD) out = 4'd10;

    return out;
endfunction

// BCD counter helper functions (used for timer and flag counter)
// Increment the count for the BCD counter
function automatic lcd_count_t increment_count(input lcd_count_t count);
    lcd_count_t out;

    // Bounds checking (prevent overflow)
    if (count == 12'h999) return 12'h999;

    // Check if number is negative one
    if (count == 12'b1101_0000_0001) return 12'd0;

    // If count is negative, decrement magnitude. Otherwise increase magnitude
    if (count[11:8] == 4'b1101) begin
        out = decrement_magnitude(count);
    end else begin
        out = increment_magnitude(count);
    end
    
    return out;
endfunction

// Decrement the count for the BCD counter
function automatic lcd_count_t decrement_count(input lcd_count_t count);
    lcd_count_t out;

    // Bounds checking (prevent overflow and borrow from sign)
    if (count == 12'hD99) return 12'hD99;

    // Check if number is zero
    if (count == 12'd0) return 12'b1101_0000_0001;

    // If count is negative, increment magnitude. Otherwise decrease magnitude
    if (count[11:8] == 4'b1101) begin
        out = increment_magnitude(count);
    end else begin
        out = decrement_magnitude(count);
    end
    
    return out;
endfunction

// Increment the magnitude of BCD encoded counter
function automatic lcd_count_t increment_magnitude(input lcd_count_t count);
    logic carry;
    lcd_count_t out;
    out = count;
    carry = 1'b1;

    for (int i = 0; i < 3; i++) begin
        // If there is a carry then add 1
        if (carry) begin
            if (out[i*4 +: 4] == 4'd9) begin
                // If nibble is at max bdc (9), then roll over and carry ouy
                out[i*4 +: 4] = 4'd0;
                carry = 1'b1;
            end else begin
                // Otherwise, add 1 with no carry out
                out[i*4 +: 4] = out[i*4 +: 4] + 1'b1;
                carry = 1'b0;
            end
        end
    end
    return out;
endfunction

// Decrement the magnitude of BCD encoded counter
function automatic lcd_count_t decrement_magnitude(input lcd_count_t count);
    logic carry;
    lcd_count_t out;
    out = count;
    carry = 1'b1;

    for (int i = 0; i < 3; i++) begin
        // If there is a carry then subtract 1
        if (carry) begin
            if (out[i*4 +: 4] == 4'd0) begin
                // If nibble is at min bdc (0), then roll over and borrow
                out[i*4 +: 4] = 4'd9;
                carry = 1'b1;
            end else begin
                // Otherwise, add 1 with no carry out
                out[i*4 +: 4] = out[i*4 +: 4] - 1'b1;
                carry = 1'b0;
            end
        end
    end
    return out;
endfunction


endpackage
