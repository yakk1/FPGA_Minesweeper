`timescale 1ns / 1ps
`default_nettype none

module top
import minesweeper_pkg::*;
(
    input wire logic clk_125m,
    input wire logic btn_rst,
    input wire logic btn_left,
    input wire logic btn_right,
    input wire logic Vaux1_0_v_p,
    input wire logic Vaux1_0_v_n,
    input wire logic Vaux9_0_v_p,
    input wire logic Vaux9_0_v_n,
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

//TODO: 2FF synchroniser for clk_pix_locked

databus_t game_state_fast;
logic start;
//Mouse controller
mouse_controller Mouse
(
    .clk_125m(clk_125m),
    .rst(btn_rst),
    .mouse_btn_left(btn_left),
    .mouse_btn_right(btn_right),
    .Vaux1_0_v_p(Vaux1_0_v_p),
    .Vaux1_0_v_n(Vaux1_0_v_n),
    .Vaux9_0_v_p(Vaux9_0_v_p),
    .Vaux9_0_v_n(Vaux9_0_v_n),

    .btn_debounce_left(start),
    .btn_debounce_right(),
    .mouse_x(game_state_fast.mouse_x),
    .mouse_y(game_state_fast.mouse_y)
);

game_timer Timer
(
    .clk(clk_125m),
    .rst(!clk_pix_locked),
    .timer(game_state_fast.right_count_value)
);

// Cross logic and display clock domains
//assign game_state_fast.mouse_x = 100;
//assign game_state_fast.mouse_y = 150;
assign game_state_fast.face_id = 2;
//assign game_state_fast.left_count_value = 12'b0001_0000_0001;
//assign game_state_fast.right_count_value = 12'b0001_0001_0011;
assign game_state_fast.show_mines = 1'b1;


gridx_coord_t start_x, start_y, coord_x_a, coord_y_a;
tile_t tile_r_a, tile_w_a;
logic we_a;

assign start_x = '0;
assign start_y = '0;

setup_game u_setup_game (
    .clk        (clk_125m),
    .rst        (btn_rst),
    .start      (start),

    .start_x    (start_x),
    .start_y    (start_y),

    .busy       (),
    .done       (),
    .mine_count (game_state_fast.left_count_value),

    // BRAM Interface
    .we_a       (we_a),
    .coord_x_a  (coord_x_a),
    .coord_y_a  (coord_y_a),
    .tile_r_a   (tile_r_a),
    .tile_w_a   (tile_w_a)
);

logic frame;
databus_t game_state_pix;

game_state_cdc Game_state_cdc
(
    //Fast clock domain
    .clk_125m(clk_125m),
    .rst_fast(btn_rst),
    .state_valid(1'b1),
    .state_in(game_state_fast),

    //Slow clock domain
    .clk_pix(clk_pix),
    .rst_pix(!clk_pix_locked),
    .frame(frame),
    .state_out(game_state_pix)
);

// Board state BRAM
gridx_coord_t sx_board;
gridy_coord_t sy_board;
tile_t read_tile;

board board_memory (
    .clk_a(clk_125m),
    .we_a(we_a),
    .coord_x_a(coord_x_a),
    .coord_y_a(coord_y_a),
    .din_a(tile_w_a),
    .dout_a(tile_r_a),
    .clk_b(clk_pix),
    .coord_x_b(sx_board),
    .coord_y_b(sy_board),
    .dout_b(read_tile)
);

// Render Game
renderer Renderer (
    .clk_pix(clk_pix),
    .clk_pix_locked(clk_pix_locked),
    .btn_rst(btn_rst),
    
    // Game state controls
    .game_state(game_state_pix),

    // Board BRAM interface (read only)
    .sx_board(sx_board),
    .sy_board(sy_board),
    .read_tile(read_tile),

    // VGA control signals
    .vga_r(vga_r),
    .vga_b(vga_b),
    .vga_g(vga_g),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .frame(frame)
);

endmodule
