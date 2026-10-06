// Top renderer module
// Takes as input the board state and databus
// Outputs VGA control signals

module renderer
import minesweeper_pkg::*;
(
    input wire logic clk_pix,
    input wire logic clk_pix_locked,
    input wire logic btn_rst,
    
    // Game state controls
    input wire databus_t game_state,

    // Board BRAM interface
    output gridx_coord_t sx_board,
    output gridy_coord_t sy_board,
    input tile_t read_tile,

    // VGA control signals
    output logic [3:0] vga_r,
    output logic [3:0] vga_b,
    output logic [3:0] vga_g,
    output logic vga_hsync,
    output logic vga_vsync,

    // VGA frame signal
    output logic frame
);

// Display signal generator
screen_coord_t sx, sy;
logic hsync, vsync, de; 
display_timer disp_gen (
    .clk_pix(clk_pix),    //Pixel clock
    .rst_pix(!clk_pix_locked),    //Reset in pixel clock domain
    .sx(sx),   //Screen x position (horizontal)
    .sy(sy),   //Screen y position (vertical)
    .hsync(hsync),      //Horizontal sync
    .vsync(vsync),      //Vertical sync
    .de(de),          //Data enable (low in blanking)
    .frame(frame),       
    .line()
);


// Read tile from BRAM
// We must divide the coordinate by 16 (remove lower 4 bits)
// Lookup tile in advance, to account for BRAM read latencies
localparam DISP_LATENCY = 3;

screen_coord_t sx_plus_one;
screen_coord_t sx_board_adjusted;
screen_coord_t sy_board_adjusted;
logic grid;


// Calculate relative board position, determine if current coordinates renders a grid
// May be flag later for controller (master renderer)
assign sx_plus_one = sx + 1;
assign grid = (sx_plus_one >= GRID_OFFSET_X && sx_plus_one < (TILE_WIDTH * BOARD_WIDTH + GRID_OFFSET_X) && sy >= GRID_OFFSET_Y && sy < (TILE_HEIGHT * BOARD_HEIGHT + GRID_OFFSET_Y));  

// Calculate relative board coordinates, lookup x in advance due to BRAM read latency
// Divide board coordinates by 16 (as tile is 16x16)
assign sx_board_adjusted = $signed(sx + DISP_LATENCY - GRID_OFFSET_X);
assign sy_board_adjusted = $signed(sy - GRID_OFFSET_Y);
assign sx_board = sx_board_adjusted[4 +: $clog2(BOARD_WIDTH)];
assign sy_board = sy_board_adjusted[4 +: $clog2(BOARD_HEIGHT)];


screen_coord_t sx_sprite_adjusted;
logic [11:0] sprite_address;
colour_t tile_colour;
tile_id_t sprite_id;

assign sprite_id = get_tile_sprite_id(read_tile, game_state.show_mines);         //Combinationally calculate tile sprite ID
assign sx_sprite_adjusted = sx + $signed(DISP_LATENCY - 1);

//Sprite address equals spriteID * (16^2) + sprite y pos * 16 + x position
assign sprite_address = {sprite_id, sy_board_adjusted[3:0], sx_sprite_adjusted[3:0]};

//Create tile sprite ROM
sprite_rom #(
    .SPRITE_W(TILE_WIDTH),
    .SPRITE_H(TILE_HEIGHT),
    .N_SPRITES(N_TILE_SPRITES),
    .ADDR_W($clog2(N_TILE_SPRITES*TILE_HEIGHT*TILE_WIDTH)),
    .MEM_FILE("./mem/tiles_sprite.mem")
)
tile_sprite_memory (
    .clk(clk_pix),
    .addr(sprite_address),
    .colour(tile_colour)
);



//Create face sprite ROM
logic draw_face;
logic [$clog2(N_FACES_SPRITES*FACE_HEIGHT*FACE_WIDTH)-1 : 0] face_sprite_address;
colour_t face_colour;
screen_coord_t sx_face_adjusted;
screen_coord_t sy_face_adjusted;
assign sx_face_adjusted = $signed(sx + (DISP_LATENCY - 1 - FACE_OFFSET_X));
assign sy_face_adjusted = $signed(sy - FACE_OFFSET_Y);

assign face_sprite_address = (game_state.face_id * (FACE_WIDTH*FACE_HEIGHT)) + (sy_face_adjusted * FACE_WIDTH) + sx_face_adjusted;
assign draw_face = (sx_plus_one >= FACE_OFFSET_X && sx_plus_one < (FACE_OFFSET_X + FACE_WIDTH) && sy >= FACE_OFFSET_Y && sy < (FACE_OFFSET_Y + FACE_HEIGHT));  

sprite_rom #(
    .SPRITE_W(FACE_WIDTH),
    .SPRITE_H(FACE_HEIGHT),
    .N_SPRITES(N_FACES_SPRITES),
    .ADDR_W($clog2(N_FACES_SPRITES*FACE_HEIGHT*FACE_WIDTH)),
    .MEM_FILE("./mem/face_sprite.mem")
)
face_sprite_memory (
    .clk(clk_pix),
    .addr(face_sprite_address),
    .colour(face_colour)
);


//Create display sprite ROM
logic draw_right_disp;
logic draw_left_disp;
colour_t disp_colour;

counter_renderer digit_disp(
    .clk_pix(clk_pix),
    .sx(sx),
    .sy(sy),
    .left_disp_val(game_state.left_count_value),
    .right_disp_val(game_state.right_count_value),

    .draw_left_disp(draw_left_disp),
    .draw_right_disp(draw_right_disp),
    .o_colour(disp_colour) 
);


//Create mouse sprite ROM
colour_t mouse_colour;
logic draw_mouse;
logic [$clog2(MOUSE_HEIGHT*MOUSE_WIDTH)-1 : 0] mouse_sprite_address;

screen_coord_t sx_mouse_adjusted;
screen_coord_t sy_mouse_adjusted;

assign sx_mouse_adjusted = $signed(sx + DISP_LATENCY - 1 - game_state.mouse_x);
assign sy_mouse_adjusted = $signed(sy - game_state.mouse_y);

// Mouse is 32*32 pixels. So bit shift y coordinate by 5

assign mouse_sprite_address = {sy_mouse_adjusted[4:0], sx_mouse_adjusted[4:0]};
assign draw_mouse = (sx_plus_one >= game_state.mouse_x && sx_plus_one < (game_state.mouse_x + MOUSE_WIDTH)) && (sy >= game_state.mouse_y && sy < (game_state.mouse_y + MOUSE_HEIGHT));

sprite_rom #(
    .SPRITE_W(MOUSE_WIDTH),
    .SPRITE_H(MOUSE_HEIGHT),
    .N_SPRITES(1),
    .ADDR_W($clog2(MOUSE_HEIGHT*MOUSE_WIDTH)),
    .MEM_FILE("./mem/cursor_sprite.mem")
)
mouse_sprite_memory (
    .clk(clk_pix),
    .addr(mouse_sprite_address),
    .colour(mouse_colour)
);


//Paint colour
//Flags
//Grid - on the grid (use grid colour)
//Face - on the face (use face colour)
//Background - use background colour
//Mouse - use mouse colour
//Priority encoder - highest priority first (where transparent render the second most)

logic [11:0] pixel_colour;
colour_t draw_colour;

always_comb begin
    if (draw_mouse && mouse_colour != 4'hF) begin
        draw_colour = mouse_colour;
    end else if (grid) begin
        draw_colour = tile_colour;
    end else if (draw_face) begin
        draw_colour = face_colour;
    end else if (draw_left_disp | draw_right_disp) begin
        draw_colour = disp_colour;
    end else begin
        draw_colour = BACKGROUND_COLOUR;
    end
end

clut #(
    .COLOUR_W(12),
    .COLOUR_IDX_W(4),
    .COLOUR_FILE("palette_rom.mem")
)
clut_table ( 
    .clk(clk_pix),                           
    .r_addr(draw_colour), 
    .w_addr('0), 
    .w_value('0),   
    .we('0),        
    .dout(pixel_colour)   
);

colour_t paint_r, paint_g, paint_b;
assign {paint_r, paint_g, paint_b} = pixel_colour;

//Consider blanking, no colour within blanking region
colour_t display_r, display_g, display_b;
always_comb begin
    display_r = (de) ? paint_r : 4'h0;
    display_g = (de) ? paint_g : 4'h0;
    display_b = (de) ? paint_b : 4'h0;
end

//Register to VGA output
always_ff @(posedge clk_pix) begin
    vga_r <= display_r;
    vga_b <= display_b;
    vga_g <= display_g;
    vga_hsync <= hsync;
    vga_vsync <= vsync;
end

endmodule