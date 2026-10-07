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
    

databus_t game_state_fast;
logic start;

logic left_click;
logic right_click;


logic face_clicked;
logic tile_clicked;
gridx_coord_t tile_x, coord_x_a;
gridy_coord_t tile_y, coord_y_a;
tile_t tile_r_a, tile_w_a;
logic we_a;

logic frame;
databus_t game_state_pix;


logic timer_reset, stop_timer;


// Board state BRAM
gridx_coord_t sx_board;
gridy_coord_t sy_board;
tile_t read_tile;

// Instanciate clock wizard IP to generate 25.2 MHz pixel clock
logic clk_pix;
logic clk_pix_locked;
clk_wiz_0 pixel_clock_generator
   (
    .clk_out1(clk_pix), 
    .reset(btn_rst), 
    .locked(clk_pix_locked),  
    .clk_in1(clk_125m) 
);

// 2FF synchronizer for clk_pix_locked
logic locked_sync_1, locked_sync_2;
logic rst_pix; // Synchronized active-high reset for the pixel clock domain

always_ff @(posedge clk_pix) begin
    // If the clock is unstable or the user presses btn_rst, this pulls low
    locked_sync_1 <= clk_pix_locked;
    locked_sync_2 <= locked_sync_1;
end

// Invert so that a loss of lock becomes an active reset
assign rst_pix = ~locked_sync_2;

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

    .btn_debounce_left(left_click),
    .btn_debounce_right(right_click),
    .mouse_x(game_state_fast.mouse_x),
    .mouse_y(game_state_fast.mouse_y)
);

button_decoder u_button_decoder (
    // Mouse click inputs
    .left_click   (left_click),
    .right_click  (right_click),

    // Mouse coordinate inputs
    .mouse_x      (game_state_fast.mouse_x),
    .mouse_y      (game_state_fast.mouse_y),
    
    // Decoded button outputs
    .face_clicked (face_clicked),
    .tile_clicked (tile_clicked),
    .tile_x       (tile_x),
    .tile_y       (tile_y)
);

game_controller #(
    .N_MINES      (N_MINES)
) u_game_controller (
    .clk          (clk_125m),
    .rst          (btn_rst),

    // Button interface
    .face_clicked (face_clicked),
    .tile_clicked (tile_clicked),
    .tile_x       (tile_x),
    .tile_y       (tile_y),
    .left_click   (left_click),
    .right_click  (right_click),

    // Game state outputs
    .flag_disp    (game_state_fast.left_count_value),
    .show_mines   (game_state_fast.show_mines),
    .face_id      (game_state_fast.face_id),
    .win          (game_state_fast.win),
    // Control signals
    .timer_reset  (timer_reset),
    .stop_timer   (stop_timer),

    // BRAM (board) interface
    .we_a         (we_a),
    .coord_x_a    (coord_x_a),
    .coord_y_a    (coord_y_a),
    .tile_r_a     (tile_r_a),
    .tile_w_a     (tile_w_a)
);

game_timer Timer
(
    .clk(clk_125m),
    .rst(timer_reset),
    .stop_timer(stop_timer),
    .timer(game_state_fast.right_count_value)
);

game_state_cdc Game_state_cdc
(
    // Fast clock domain
    .clk_125m(clk_125m),
    .rst_fast(btn_rst),
    .state_valid(1'b1),
    .state_in(game_state_fast),

    // Slow clock domain
    .clk_pix(clk_pix),
    .rst_pix(rst_pix),
    .frame(frame),
    .state_out(game_state_pix)
);

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
    .clk_pix_locked(locked_sync_2),
    .btn_rst(rst_pix),
    
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
