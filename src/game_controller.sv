// Master game controller module
// Controls the minesweeper game, FSM based

module game_controller 
import minesweeper_pkg::*;
#(
    parameter N_MINES = 12'b0000_1001_1001
)
(
    input wire logic clk,
    input wire logic rst,

    // Button interface
    input wire logic face_clicked,
    input wire logic tile_clicked,
    input wire gridx_coord_t tile_x,
    input wire gridy_coord_t tile_y,

    input wire logic left_click,        // Debounced one clock cycle long
    input wire logic right_click,

    // Game state outputs
    output lcd_count_t flag_disp,
    output logic show_mines,
    output face_id_t face_id,
    output logic win,

    // Control signals
    output logic timer_reset,
    output logic stop_timer,

    // BRAM (board) interface
    output logic we_a,
    output gridx_coord_t coord_x_a,
    output gridy_coord_t coord_y_a,
    input wire tile_t tile_r_a,
    output tile_t tile_w_a
);

// Number of tiles to open for a win
localparam int N_OPEN_WIN = N_TILES - ((N_MINES[11:8] * 100) + (N_MINES[7:4] * 10) + N_MINES[3:0]);
logic [$clog2(N_TILES) - 1 : 0] open_tile_count;

// Game States
// IDLE - game is in the reset state, displays are 0, no mines placed, ready to start game
// SETUP - player has clicked a tile, game is setting up (placing mines, calculating values, starting timer) 
// OPEN_TILES - a tile has been clicked, tiles are opening
// AWAIT_FLAG - waiting stage as BRAM has 1 cycle latency for read
// FLAG - a tile has been clicked to flag
// AWAIT_CLICK - idle state awaiting user input
// LOSE - player has lost - a mine was opened (open all mines) (possibly pass a flag to the display controller)
// WIN - player has won (all safe squares are open) - will need an open counter hidden from user
// RESET - clear board, stop timers, reset to IDLE
typedef enum logic [3:0] {
    IDLE,
    SETUP,
    OPEN_TILES,
    AWAIT_FLAG,
    FLAG,
    AWAIT_CLICK,
    LOSE,
    WIN,
    RESET
} state_t;

state_t state;

gridx_coord_t click_x;
gridy_coord_t click_y;
logic game_started;
logic setup_busy;
logic setup_done;
lcd_count_t mine_count;
logic start_game;

// Tile opener signals
wire logic open_tile_done;
wire logic open_mine;
wire logic [$clog2(N_TILES) - 1 : 0] tiles_opened;
logic open_tile_start;
logic open_busy;

// BRAM wires from submodules
logic         setup_we_a, open_we_a, ctrl_we_a;
gridx_coord_t setup_x_a,  open_x_a,  ctrl_x_a;
gridy_coord_t setup_y_a,  open_y_a,  ctrl_y_a;
tile_t        setup_w_a,  open_w_a,  ctrl_w_a;

// Setup game module
setup_game #(
    .N_MINES    (N_MINES)
) u_setup_game (
    .clk        (clk),
    .rst        (rst || face_clicked),  // Reset if face clicked too (new setup)
    .start      (start_game),

    .start_x    (click_x),
    .start_y    (click_y),

    .busy       (setup_busy),
    .done       (setup_done),
    .mine_count (mine_count),

    // BRAM Interface
    .we_a       (setup_we_a),
    .coord_x_a  (setup_x_a),
    .coord_y_a  (setup_y_a),
    .tile_r_a   (tile_r_a),
    .tile_w_a   (setup_w_a)
);

// Open tile module
open_tile u_open_tile (
    .clk             (clk),
    .rst             (rst || face_clicked), // Reset if face clicked mid-open

    .start_x         (click_x),
    .start_y         (click_y),
    .open_tile_start (open_tile_start),

    .open_tile_done  (open_tile_done),
    .open_mine       (open_mine),
    .tiles_opened    (tiles_opened),
    .busy            (open_busy),

    // BRAM Interface
    .we_a            (open_we_a),
    .coord_x_a       (open_x_a),
    .coord_y_a       (open_y_a),
    .tile_r_a        (tile_r_a),
    .tile_w_a        (open_w_a)
);

// Game controller state machine
always_ff @(posedge clk) begin
    if (rst) begin
        timer_reset <= 1'b1;
        start_game <= 1'b0;
        game_started <= 1'b0;
        show_mines <= 1'b0;
        stop_timer <= 1'b1;
        ctrl_we_a <= 1'b0;
        click_x <= '0; 
        click_y <= '0;
        open_tile_count <= '0;
        open_tile_start <= 1'b0;
        win <= 1'b0;
        flag_disp <= N_MINES;
        state <= RESET; 
    end else begin
        // Signal defaults
        start_game <= 1'b0;
        show_mines <= 1'b0;
        ctrl_we_a <= 1'b0;
        open_tile_start <= 1'b0;
        win <= 1'b0;

        case(state)
            IDLE: begin
                // If a tile is clicked store the coordinate and begin game
                face_id <= 0;
                if (tile_clicked && left_click) begin
                    // Request tile and register click
                    ctrl_x_a <= tile_x;
                    ctrl_y_a <= tile_y;
                    click_x <= tile_x;
                    click_y <= tile_y;
                    start_game <= 1'b1;
                    game_started <= 1'b1;
                    stop_timer <= 1'b0;
                    timer_reset <= 1'b0;
                    state <= SETUP;
                end
            end

            SETUP: begin
                // Wait for game to setup
                if (setup_done) begin
                    open_tile_start <= 1'b1;
                    state <= OPEN_TILES;
                end
            end

            OPEN_TILES: begin
                if (open_tile_done) begin
                    if (open_mine) begin
                        state <= LOSE;
                    end else if (tiles_opened + open_tile_count >= N_OPEN_WIN) begin
                        state <= WIN;
                    end else begin
                        open_tile_count <= open_tile_count + tiles_opened;
                        state <= AWAIT_CLICK;
                    end
                end
            end

            AWAIT_FLAG: begin
                // Await BRAM read to do flag
                state <= FLAG;
            end

            FLAG: begin
                // Echo tile back
                ctrl_we_a <= 1'b1;
                ctrl_x_a <= click_x;
                ctrl_y_a <= click_y;
                ctrl_w_a <= tile_r_a;
                
                // Write flag and update mine counter if the tile isnt open
                if (!tile_r_a.is_open) begin
                    if (tile_r_a.flag) begin
                        ctrl_w_a.flag <= 1'b0;
                        flag_disp <= increment_count(flag_disp);
                    end else begin
                        ctrl_w_a.flag <= 1'b1;
                        flag_disp <= decrement_count(flag_disp);
                    end
                end
                
                // Return to waiting state
                state <= AWAIT_CLICK;
            end
            
            AWAIT_CLICK: begin
                if (tile_clicked) begin
                    // Request tile and register click
                    ctrl_x_a <= tile_x;
                    ctrl_y_a <= tile_y;
                    click_x <= tile_x;
                    click_y <= tile_y;
                    if (left_click) begin
                        open_tile_start <= 1'b1;
                        state <= OPEN_TILES;
                    end else if (right_click) begin
                        state <= AWAIT_FLAG;
                    end
                end
            end

            LOSE: begin
                // If game is lost, show all mines
                stop_timer <= 1'b1;
                show_mines <= 1'b1;
                face_id <= 4;
            end

            WIN: begin
                // Stop timer, flag all mines
                stop_timer <= 1'b1;
                face_id <= 3;
                flag_disp <= '0;
                win <= 1'b1;
            end

            RESET: begin
                // Reset game
                face_id <= 1;
                timer_reset <= 1'b1;
                flag_disp <= N_MINES;
                show_mines <= 1'b0;
                start_game <= 1'b0;
                open_tile_count <= '0;

                // Clear board
                // Write empty tile to board
                ctrl_we_a <= 1'b1;
                ctrl_x_a <= click_x;
                ctrl_y_a <= click_y;
                ctrl_w_a <= '0; 
                
                // Increment board coordinate (row by row)
                // Supports non power of 2 board sizes
                if (click_x == BOARD_WIDTH - 1) begin
                    click_x <= '0;
                    if (click_y == BOARD_HEIGHT - 1) state <= IDLE;
                    else click_y <= click_y + 1'b1;
                end else begin
                    click_x <= click_x + 1'b1;
                end
            end

            default: state <= IDLE;
        endcase

        //Always go to reset state if the face button is clicked
        if (face_clicked) begin
            click_x <= '0;
            click_y <= '0;
            game_started <= 1'b0;
            stop_timer <= 1'b1;
            state <= RESET;
        end
    end
end

// BRAM mux
// Route BRAM Port A based on current FSM state
always_comb begin
    case (state)
        SETUP: begin
            we_a      = setup_we_a;
            coord_x_a = setup_x_a;
            coord_y_a = setup_y_a;
            tile_w_a  = setup_w_a;
        end
        OPEN_TILES: begin
            we_a      = open_we_a;
            coord_x_a = open_x_a;
            coord_y_a = open_y_a;
            tile_w_a  = open_w_a;
        end
        default: begin // IDLE, AWAIT_FLAG, FLAG, AWAIT_CLICK, RESET
            we_a      = ctrl_we_a;
            coord_x_a = ctrl_x_a;
            coord_y_a = ctrl_y_a;
            tile_w_a  = ctrl_w_a;
        end
    endcase
end

endmodule