//This module produces the colour and control signals to draw the flag counter and game timer

module counter_renderer 
import minesweeper_pkg::*;
(
    input wire logic clk_pix,
    input wire screen_coord_t sx,
    input wire screen_coord_t sy,
    input wire lcd_count_t left_disp_val,
    input wire lcd_count_t right_disp_val,

    output logic draw_left_disp,
    output logic draw_right_disp,
    output colour_t o_colour 
);
localparam DISP_LATENCY = 3;

screen_coord_t sx_disp_adjusted;
screen_coord_t sy_disp_adjusted;
logic in_left_display;
logic in_right_display;
logic [5:0] num_local_x;
logic [5:0] x_offset;
logic [3:0] digit_nibble;
digit_id_t digit_id;

//Adjust coordinates to account for latency and position
assign sx_disp_adjusted = $signed(sx + DISP_LATENCY - 1);
assign sy_disp_adjusted = $signed(sy - DIGIT_OFFSET_Y);

// Calculate the digit to display based on screen coordinates (left or right display)
always_comb begin
    in_left_display = (sx_disp_adjusted >= DIGIT1_OFFSET_X && sx_disp_adjusted < (DIGIT1_OFFSET_X + 3*NUM_WIDTH) && sy >= DIGIT_OFFSET_Y && sy < (DIGIT_OFFSET_Y + NUM_HEIGHT));  
    in_right_display = (sx_disp_adjusted >= DIGIT2_OFFSET_X && sx_disp_adjusted < (DIGIT2_OFFSET_X + 3*NUM_WIDTH) && sy >= DIGIT_OFFSET_Y && sy < (DIGIT_OFFSET_Y + NUM_HEIGHT));  
    num_local_x = in_right_display ? (sx_disp_adjusted - DIGIT2_OFFSET_X) : (sx_disp_adjusted - DIGIT1_OFFSET_X);

    digit_id = 4'hB;
    if (num_local_x < NUM_WIDTH) begin
        digit_nibble = in_right_display ? right_disp_val[11:8] : left_disp_val[11:8];
        x_offset = num_local_x;
    end 
    else if (num_local_x < 2*NUM_WIDTH) begin
        digit_nibble = in_right_display ? right_disp_val[7:4] : left_disp_val[7:4];
        x_offset = num_local_x - NUM_WIDTH;
    end 
    else begin
        digit_nibble = in_right_display ? right_disp_val[3:0] : left_disp_val[3:0];
        x_offset = num_local_x - (2*NUM_WIDTH);
    end

    digit_id = get_digit_sprite_id(digit_nibble);
end

// Draw left and right control signals pipelined to align with the output colour
always_ff @(posedge clk_pix) begin
    draw_left_disp <= in_left_display;
    draw_right_disp <= in_right_display;
end

// Calculate ROM address for pixel
// TODO: Optimisation - use a counter that increments when drawing, to avoid multiplication
logic [$clog2(N_NUMS_SPRITES*NUM_HEIGHT*NUM_WIDTH)-1 : 0] digit_sprite_address;
assign digit_sprite_address = (digit_id * NUM_HEIGHT * NUM_WIDTH) + (sy_disp_adjusted * NUM_WIDTH) + x_offset;

sprite_rom #(
    .SPRITE_W(NUM_WIDTH),
    .SPRITE_H(NUM_HEIGHT),
    .N_SPRITES(N_NUMS_SPRITES),
    .ADDR_W($clog2(N_NUMS_SPRITES*NUM_HEIGHT*NUM_WIDTH)),
    .MEM_FILE("./mem/numbers_sprite.mem")
)
display_sprite_memory (
    .clk(clk_pix),
    .addr(digit_sprite_address),
    .colour(o_colour)
);

endmodule
