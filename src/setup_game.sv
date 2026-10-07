// This module sets up the game by clearing the board, placing random mines, and calculating grid values

module setup_game
import minesweeper_pkg::*;
#(
    parameter N_MINES = 12'b0000_1001_1001
)
(
    input wire logic clk,
    input wire logic rst,
    input wire logic start,

    input wire gridx_coord_t start_x,
    input wire gridy_coord_t start_y,

    output logic busy,
    output logic done,
    output lcd_count_t mine_count,

    //BRAM Interface
    output logic we_a,
    output gridx_coord_t coord_x_a,
    output gridy_coord_t coord_y_a,
    input wire tile_t tile_r_a,
    output tile_t tile_w_a
);

// Grid coordinates
gridx_coord_t rand_x, sel_x, nx;
gridy_coord_t rand_y, sel_y, ny;

// Tile Neighbour Checks
logic [2:0] n_idx;
logic signed [1:0] dx, dy;
logic oob_x, oob_y, n_valid;

// Generates random coordinates
lfsr LFSR
(
    .clk(clk),
    .rand_x(rand_x),
    .rand_y(rand_y)
);

// State machine states
typedef enum logic [3:0] {
    IDLE,
    //CLEAR_BOARD,
    PICK_COORD,
    WAIT_TILE,
    PLACE,
    READ_NEIGHBOUR,
    WAIT_NEIGHBOUR,
    INCREMENT_NEIGHBOUR,
    DONE
} state_t;

state_t state;

// Neighbour offsets
always_comb begin
    case (n_idx)
        3'd0: begin dx = -1; dy = -1; end // (-1, -1)
        3'd1: begin dx =  0; dy = -1; end // ( 0, -1)
        3'd2: begin dx =  1; dy = -1; end // (+1, -1)
        3'd3: begin dx = -1; dy =  0; end // (-1,  0)
        3'd4: begin dx =  1; dy =  0; end // (+1,  0)
        3'd5: begin dx = -1; dy =  1; end // (-1, +1)
        3'd6: begin dx =  0; dy =  1; end // ( 0, +1)
        3'd7: begin dx =  1; dy =  1; end // (+1, +1)
    endcase
end

// Calculate and check if neighbour is valid
assign nx = $signed({1'b0, sel_x}) + dx;
assign ny = $signed({1'b0, sel_y}) + dy;
assign oob_x = (sel_x == 0 && dx == -1) || (sel_x == BOARD_WIDTH - 1  && dx == 1);
assign oob_y = (sel_y == 0 && dy == -1) || (sel_y == BOARD_HEIGHT - 1 && dy == 1);
assign n_valid = !oob_x && !oob_y;

// State Machine
always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        we_a <= 1'b0;
        coord_x_a <= '0;
        coord_y_a <= '0;
        sel_x <= '0;
        sel_y <= '0;
        tile_w_a <= '0;
        busy <= 1'b0;
        done <= 1'b0;
        mine_count <= '0;
        n_idx <= '0;
    end else begin

        // Defaults
        done <= 1'b0;
        we_a <= 1'b0;

        case (state)
            IDLE: begin
                busy <= 1'b0;
                if (start) begin
                    busy <= 1'b1;
                    mine_count <= '0;
                    sel_x <= '0;
                    sel_y <= '0;
                    //state <= CLEAR_BOARD;
                    state <= PICK_COORD;
                end
            end

            /*CLEAR_BOARD: begin
                // Write empty tile to board
                we_a <= 1'b1;
                coord_x_a <= sel_x;
                coord_y_a <= sel_y;
                tile_w_a <= '0; 
                
                // Increment board coordinate (row by row)
                // Supports non power of 2 board sizes
                if (sel_x == BOARD_WIDTH - 1) begin
                    sel_x <= '0;
                    if (sel_y == BOARD_HEIGHT - 1) state <= PICK_COORD;
                    else sel_y <= sel_y + 1'b1;
                end else begin
                    sel_x <= sel_x + 1'b1;
                end
            end*/

            PICK_COORD: begin
                // Pick a new coordinate if it is the start coordinate
                // Otherwise read the tile
                sel_x <= rand_x;
                sel_y <= rand_y;
                // TODO Add bounds checks (to support non power of 2 boards in the future)
                // TODO All x and y coords are valid because we have a power of 2 board width and height
                if (rand_x == start_x && rand_y == start_y) begin
                    state <= PICK_COORD;
                end else begin
                    // Request tile from BRAM
                    coord_x_a <= rand_x;
                    coord_y_a <= rand_y;
                    state <= WAIT_TILE;
                end
            end

            WAIT_TILE: begin
                state <= PLACE;
            end

            PLACE: begin
                // Check tile from BRAM (1 clock cycle delay)
                // If tile is a mine then try again, otherwise place the mine
                if (tile_r_a.is_mine) begin
                    state <= PICK_COORD;
                end else begin
                    we_a <= 1'b1;
                    tile_w_a <= tile_r_a;
                    tile_w_a.is_mine <= 1'b1;
                    mine_count <= increment_count(mine_count);
                    n_idx <= '0;
                    state <= READ_NEIGHBOUR;
                end
            end

            READ_NEIGHBOUR: begin
                // Request neighbour from BRAM (1 clk latency)
                // if not valid, then check the next neighbour
                if (n_valid) begin
                    coord_x_a <= nx;
                    coord_y_a <= ny;
                    state <= WAIT_NEIGHBOUR;
                end else begin
                    if (n_idx == 3'd7) begin
                        if (mine_count == N_MINES) state <= DONE;
                        else state <= PICK_COORD;
                    end else begin
                        n_idx <= n_idx + 1'b1;
                        state <= READ_NEIGHBOUR;
                    end
                end
            end

            WAIT_NEIGHBOUR: begin
                state <= INCREMENT_NEIGHBOUR;
            end

            INCREMENT_NEIGHBOUR: begin
                // Write to BRAM (guaranteed neighbour exists)
                we_a <= 1'b1;
                coord_x_a <= nx;
                coord_y_a <= ny;
                tile_w_a <= tile_r_a;
                tile_w_a.value <= tile_r_a.value + 1'b1;

                // If this is the last neighbour then check if we are done, otherwise continue updating neighbours
                if (n_idx == 3'd7) begin
                    if (mine_count == N_MINES) state <= DONE;
                    else state <= PICK_COORD;
                end else begin
                    n_idx <= n_idx + 1'b1;
                    state <= READ_NEIGHBOUR;
                end
            end

            DONE: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule