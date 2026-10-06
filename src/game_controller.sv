// Master game controller module
// Controls the minesweeper game, FSM based

module game_controller 
import minesweeper_pkg::*;
(

);

// Game States
// IDLE - game is in the reset state, displays are 0, no mines placed, ready to start game
// SETUP - player has clicked a tile, game is setting up (placing mines, calculating values, starting timer) 
// OPEN_TILES - a tile has been clicked, tiles are opening
// FLAG - a tile has been clicked to flag
// AWAIT_CLICK - idle state awaiting user input
// LOSE - player has lost - a mine was opened (open all mines) (possibly pass a flag to the display controller)
// WIN - player has won (all safe squares are open) - will need an open counter hidden from user
// RESET - clear board, stop timers, reset to IDLE
typedef enum logic [2:0] {
    IDLE,
    SETUP,
    OPEN_TILES,
    FLAG,
    AWAIT_CLICK,
    LOSE,
    WIN,
    RESET
} state_t;

state_t state;


endmodule