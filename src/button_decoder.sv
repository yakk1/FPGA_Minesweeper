// Button decoder module
// Determines if the mouse is on a button (tile, or face button)

module button_decoder
import minesweeper_pkg::*;
(
    input wire logic left_click,
    input wire logic right_click,
    input wire screen_coord_t mouse_x,
    input wire screen_coord_t mouse_y,
    
    output logic face_clicked,
    output logic tile_clicked,
    output gridx_coord_t tile_x,
    output gridy_coord_t tile_y
);

logic mouse_click;
screen_coord_t mouse_x_adjusted, mouse_y_adjusted;

always_comb begin
    mouse_click = left_click || right_click;
    face_clicked = (mouse_click) && (mouse_x >= FACE_OFFSET_X && mouse_x < (FACE_OFFSET_X + FACE_WIDTH) && mouse_y >= FACE_OFFSET_Y && mouse_y < (FACE_OFFSET_Y + FACE_HEIGHT));  
    tile_clicked = (mouse_click) && (mouse_x >= GRID_OFFSET_X && mouse_x < (TILE_WIDTH * BOARD_WIDTH + GRID_OFFSET_X) && mouse_y >= GRID_OFFSET_Y && mouse_y < (TILE_HEIGHT * BOARD_HEIGHT + GRID_OFFSET_Y));
    mouse_x_adjusted = mouse_x - GRID_OFFSET_X;
    mouse_y_adjusted = mouse_y - GRID_OFFSET_Y;
    tile_x = mouse_x_adjusted[4 +: $clog2(BOARD_WIDTH)];
    tile_y = mouse_y_adjusted[4 +: $clog2(BOARD_HEIGHT)]; 
end

endmodule