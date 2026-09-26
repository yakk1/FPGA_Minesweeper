`timescale 1ns / 1ps
`default_nettype none

module top
import minesweeper_pkg::*;
(
    input wire logic clk_125m,
    input wire logic btn_rst,
    output logic [3:0] vga_r,
    output logic [3:0] vga_b,
    output logic [3:0] vga_g,
    output logic vga_hsync,
    output logic vga_vsync
);
    
    
//Instanciate clock wizard IP to generate 25.2 MHz pixel clock
logic clk_pix;
logic clk_pix_locked;
clk_wiz_0 pixel_clock_generator
   (
    .clk_out1(clk_pix), 
    .reset(btn_rst), 
    .locked(clk_pix_locked),  
    .clk_in1(clk_125m) 
);

//Instanciate display signal generator
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
    .frame(),       
    .line()
);


//Read tile from BRAM
//We must divide the coordinate by 16 (remove lower 4 bits)
//Lookup tile in advance, to account for BRAM read latencies
localparam DISP_LATENCY = 3;

tile_t read_tile;
screen_coord_t sx_board_adjusted;
screen_coord_t sy_board_adjusted;
logic grid;

// Calculate relative board position, determine if current coordinates renders a grid
// May be flag later for controller (master renderer)
assign grid = (sx >= GRID_OFFSET_X && sx < (TILE_WIDTH * BOARD_WIDTH + GRID_OFFSET_X) && sy >= GRID_OFFSET_Y && sy < (TILE_HEIGHT * BOARD_HEIGHT + GRID_OFFSET_Y));  

// Calculate relative board coordinates, lookup x in advance due to BRAM read latency
assign sx_board_adjusted = $signed(sx + DISP_LATENCY - GRID_OFFSET_X);
assign sy_board_adjusted = $signed(sy - GRID_OFFSET_Y);

// Create board of tiles BRAM
board board_memory (
    .clk_a(0),
    .we_a(0),
    .coord_x_a(0),
    .coord_y_a(0),
    .din_a(0),
    .dout_a(),
    .clk_b(clk_pix),
    .coord_x_b(sx_board_adjusted[4 +: $clog2(BOARD_WIDTH)]),
    .coord_y_b(sy_board_adjusted[4 +: $clog2(BOARD_HEIGHT)]),
    .dout_b(read_tile)
);

screen_coord_t sx_sprite_adjusted;
logic [11:0] sprite_address;
colour_t out_colour;
tile_id_t sprite_id;

assign sprite_id = get_tile_sprite_id(read_tile);         //Combinationally calculate tile sprite ID
assign sx_sprite_adjusted = sx + $signed(DISP_LATENCY - 1);

//Sprite address equals spriteID * (16^2) + sprite y pos * 16 + x position
assign sprite_address = {sprite_id, sy_board_adjusted[3:0], sx_sprite_adjusted[3:0]};

//Instanciate tile sprite ROM
sprite_rom #(
    .SPRITE_W(TILE_WIDTH),
    .SPRITE_H(TILE_HEIGHT),
    .N_SPRITES(N_TILE_SPRITES),
    .ADDR_W($clog2(N_TILE_SPRITES*TILE_HEIGHT*TILE_WIDTH))
)
tile_sprite_memory (
    .clk(clk_pix),
    .addr(sprite_address),
    .colour(out_colour)
);

//Paint colour
//Flags
//Grid - on the grid (use grid colour)
//Face - on the face (use face colour)
//Background - use background colour
//Mouse - use mouse colour
//Priority encoder - highest priority first (where transparent render the second most )

logic [11:0] pixel_colour;

clut clut_table ( 
    .clk(clk_pix),                           
    .r_addr(out_colour), 
    .w_addr(0), 
    .w_value(0),   
    .we(0),        
    .dout(pixel_colour)   
);

colour_t paint_r, paint_g, paint_b;
always_comb begin
    if (grid) {paint_r, paint_g, paint_b} = pixel_colour;
    else if (sy >= 0 && sy <= 50) begin
        if (sx >= 0 && sx <= 200)  {paint_r, paint_g, paint_b} = 12'hF00;
        else {paint_r, paint_g, paint_b} = 12'h0F0;
    end
    else {paint_r, paint_g, paint_b} = 12'h00F;
end

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

