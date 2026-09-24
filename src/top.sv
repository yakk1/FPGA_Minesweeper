`timescale 1ns / 1ps
`default_nettype none

module top
import minesweeper_pkg::*;
(
    input wire clk_125m,
    input wire btn_rst,
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
    .de(de)          //Data enable (low in blanking)
);


//Read tile from BRAM
//We must divide the coordinate by 16 (remove lower 4 bits)
//Lookup tile in advance, to account for BRAM read latencies

localparam DISP_LATENCY = 3;

tile_t read_tile;
screen_coord_t sx_board_adjusted;
assign sx_board_adjusted = $signed(sx + DISP_LATENCY);

board board_memory (
    .clk_a(0),
    .we_a(0),
    .coord_x_a(0),
    .coord_y_a(0),
    .din_a(0),
    .dout_a(),
    .clk_b(clk_pix),
    .coord_x_b(sx_board_adjusted[8:4]),
    .coord_y_b(sy[8:4]),
    .dout_b(read_tile)
);

screen_coord_t sx_sprite_adjusted;
logic [11:0] sprite_address;
colour_t out_colour;

sprite_t sprite_id;

assign sprite_id = get_tile_sprite_id(read_tile);                                          //Combinationally calculate sprite ID
assign sx_sprite_adjusted = sx + $signed(DISP_LATENCY - 1);

//Get sprite from the ROM 
sprite_rom sprite_memory (
    .clk(clk_pix),
    .sprite_id(sprite_id),
    .sprite_x(sx_sprite_adjusted[3:0]),
    .sprite_y(sy[3:0]),
    .colour(out_colour)
);

logic [11:0] pixel_colour;

clut clut_table ( 
    .clk(clk_pix),                           
    .r_addr(out_colour), 
    .w_addr(0), 
    .w_value(0),   
    .we(0),        
    .dout(pixel_colour)   
);

//Pixel colour should be aligned to the current sx, sy due to the x coordinate latency compensation
//We lookup 3 clock cycles in advance (1 for board, 1 for sprite, 1 for colour)
//Drive display combinationally

//Are we within the grid? (for rendering background) (currently static, but grid position will be a parameter)
logic grid;
assign grid = (sx >= 0 && sx < 16 * BOARD_WIDTH && sy >= 0 && sy < 16 * BOARD_HEIGHT);  

/*
//Render the text
logic picture;
logic text_active;
logic[4:0] local_x;  //20 columns = 5 bits
logic[3:0] local_y;  //15 rows = 4 bits
always_comb begin
    text_active = (sx >= text_x_pos && (sx < text_x_pos + (BMAP_WIDTH << SCALE_BITS)) && sy >= text_y_pos && (sy < text_y_pos + (BMAP_HEIGHT << SCALE_BITS)));
    local_x = (sx - text_x_pos) >> SCALE_BITS;
    local_y = (sy - text_y_pos) >> SCALE_BITS;
    picture = (de & text_active) ? bmap[local_y][local_x] : 1'b0;
end
*/
colour_t paint_r, paint_g, paint_b;
always_comb begin
    if (grid) {paint_r, paint_g, paint_b} = pixel_colour;
    else if (sy >= 0 && sy <= 50) begin
        if (sx >= 0 && sx <= 200)  {paint_r, paint_g, paint_b} = 12'hF00;
        else {paint_r, paint_g, paint_b} = 12'h0F0;
    end
    else {paint_r, paint_g, paint_b} = 12'h00F;
end
//assign {paint_r, paint_g, paint_b} = (grid) ? pixel_colour : 12'h00F;

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

