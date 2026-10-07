// Open tile module, opens tiles and does flood open if tile is 0

module open_tile 
import minesweeper_pkg::*;
(
    input wire logic clk,
    input wire logic rst,

    input wire gridx_coord_t start_x,
    input wire gridy_coord_t start_y,
    input wire logic open_tile_start,

    output logic open_tile_done,
    output logic open_mine,
    output logic [$clog2(N_TILES) - 1 : 0] tiles_opened,
    output logic busy,

    //BRAM Interface
    output logic we_a,
    output gridx_coord_t coord_x_a,
    output gridy_coord_t coord_y_a,
    input wire tile_t tile_r_a,
    output tile_t tile_w_a
);

logic push, pop;
logic empty, full;

gridx_coord_t wr_x, rd_x, curr_x, nx;
gridy_coord_t wr_y, rd_y, curr_y, ny;

// FIFO module for BFS
// LUTRAM (instant read, synchronous write)
bfs_fifo #(
    .DEPTH (64)
) u_bfs_fifo (
    .clk   (clk),
    .rst   (rst),

    // Push interface
    .push  (push),
    .wr_x  (wr_x),
    .wr_y  (wr_y),

    // Pop interface
    .pop   (pop),
    .rd_x  (rd_x),
    .rd_y  (rd_y),

    // Status flags
    .empty (empty),
    .full  (full)
);

// Tile Neighbour Checks
logic [2:0] n_idx;
logic signed [1:0] dx, dy;
logic oob_x, oob_y, n_valid;

// States

// BFS for tile open method: 
// 1. Add starting node to queue and mark as visited
// Loop (in FSM):
// A - Pop node
// B - Check if it is a mine then stop. Otherwise look at value.
// C - if 0, push all neighbours that are NOT open or visited
// D - terminate when empty flag is 1

// Only check if its a mine in the first tile, because thats the one that was clicked
typedef enum logic [2:0] {
    IDLE,
    AWAIT_FIRST,
    CHECK_FIRST,
    POP,
    READ_NEIGHBOUR,
    WAIT_NEIGHBOUR,
    CHECK_PUSH_NEIGHBOURS,
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
assign nx = $signed({1'b0, curr_x}) + dx;
assign ny = $signed({1'b0, curr_y}) + dy;
assign oob_x = (curr_x == 0 && dx == -1) || (curr_x == BOARD_WIDTH - 1  && dx == 1);
assign oob_y = (curr_y == 0 && dy == -1) || (curr_y == BOARD_HEIGHT - 1 && dy == 1);
assign n_valid = !oob_x && !oob_y;

always_ff @(posedge clk) begin
    if (rst) begin
        push <= 1'b0;
        pop <= 1'b0;
        we_a <= 1'b0; 
        coord_x_a <= '0; 
        coord_y_a <= '0; 
        curr_x <= '0;
        curr_y <= '0;
        wr_x <= '0;
        wr_y <= '0;
        n_idx <= '0;
        tiles_opened <= '0;
        open_tile_done <= '0;
        open_mine <= '0;
        busy <= 1'b0;
        state <= IDLE;
    end else begin
        // Defaults
        push <= 1'b0;
        pop <= 1'b0;
        we_a <= 1'b0;
        open_tile_done <= 1'b0;

        case (state)
            IDLE: begin
                // Read first tile to start
                // Prepare to write tile
                if (open_tile_start) begin
                    coord_x_a <= start_x;
                    coord_y_a <= start_y;
                    curr_x <= start_x;
                    curr_y <= start_y;
                    n_idx <= '0;
                    state <= AWAIT_FIRST;
                end
            end

            AWAIT_FIRST: begin
                // Await BRAM read for first tile
                state <= CHECK_FIRST;
            end

            CHECK_FIRST: begin
                if (tile_r_a.flag || tile_r_a.is_open) begin
                    // If the clicked tile is already open or flagged, then we are done
                    tiles_opened <= '0;
                    state <= DONE;
                end else begin
                    // Otherwise we proceed with opening the tile
                    we_a <= 1'b1;
                    tile_w_a <= tile_r_a;
                    tile_w_a.is_open <= 1'b1;
                    tile_w_a.clicked <= 1'b1;
                    tiles_opened <= 1;

                    if (tile_r_a.is_mine) begin
                        open_tile_done <= 1'b1;
                        open_mine <= 1'b1;
                        state <= IDLE;
                    end else if (tile_r_a.value == 0) begin
                        // if 0 push neighbours
                        state <= READ_NEIGHBOUR;
                    end else begin
                        state <= DONE;
                    end
                end
            end

            POP: begin
                // Pop tile if there are tiles in the fifo, otherwise we are done
                if (empty) begin
                    state <= DONE;
                end else begin
                    pop <= 1'b1;    
                    curr_x <= rd_x;
                    curr_y <= rd_y;
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
                        state <= POP;
                    end else begin
                        n_idx <= n_idx + 1'b1;
                        state <= READ_NEIGHBOUR;
                    end
                end
            end

            WAIT_NEIGHBOUR: begin
                state <= CHECK_PUSH_NEIGHBOURS;
            end

            CHECK_PUSH_NEIGHBOURS: begin
                // If neighbour exists open it
                // If neighbour is a 0 push it to queue
                if (n_valid) begin
                    // Open if theres no flag and tile is closed
                    if (!tile_r_a.is_open && !tile_r_a.flag) begin
                        we_a <= 1'b1;
                        tile_w_a <= tile_r_a;
                        tile_w_a.is_open <= 1'b1;
                        tiles_opened <= tiles_opened + 1'b1;


                        // push if neighbour has a value of 0
                        if (tile_r_a.value == 0) begin
                            push <= 1'b1;
                            wr_x <= nx;
                            wr_y <= ny;
                        end
                    end
                    
                    if (n_idx == 3'd7) begin
                        state <= POP;
                    end else begin
                        n_idx <= n_idx + 1'b1;
                        state <= READ_NEIGHBOUR;
                    end
                end else begin
                    if (n_idx == 3'd7) begin
                        state <= POP;
                    end else begin
                        n_idx <= n_idx + 1'b1;
                        state <= READ_NEIGHBOUR;
                    end
                end
            end

            DONE: begin
                open_tile_done <= 1'b1;
                open_mine <= 1'b0;
                busy <= 1'b0;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end
endmodule
