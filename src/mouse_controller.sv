
module mouse_controller
import minesweeper_pkg::*;
(
    input wire logic clk_125m,
    input wire logic rst,
    input wire logic mouse_btn_left,
    input wire logic mouse_btn_right,
    input wire logic Vaux1_0_v_p,
    input wire logic Vaux1_0_v_n,
    input wire logic Vaux9_0_v_p,
    input wire logic Vaux9_0_v_n,

    output wire logic btn_debounce_left,
    output wire logic btn_debounce_right,
    output screen_coord_t mouse_x,
    output screen_coord_t mouse_y
);

// Mouse sensitivity parameters
localparam int DEADBAND_LOW = 700;
localparam int DEADBAND_HIGH = 1300;
localparam int SENSITIVITY = 6; 
localparam int MAX_X = SCREEN_WIDTH - 1;
localparam int MAX_Y = SCREEN_HEIGHT - 1;

// Update mouse position 60 times per second
localparam int TICK_MAX = 2083333;
logic [$clog2(TICK_MAX)-1:0] tick_counter;
logic move_tick;
always_ff @(posedge clk_125m) begin
    if (rst) begin
        tick_counter <= '0;
        move_tick <= 1'b0;
    end else if (tick_counter == TICK_MAX - 1) begin
        tick_counter <= '0;
        move_tick <= 1'b1;
    end else begin
        tick_counter <= tick_counter + 1'b1;
        move_tick <= 1'b0;
    end
end

// Initialise ADC for mouse joystick position
logic [11:0] joy_x, joy_y;
DRP_read_joystick ADC_Read (
    .clk_125m(clk_125m),
    .reset(rst),
    .Vaux1_0_v_p(Vaux1_0_v_p),
    .Vaux1_0_v_n(Vaux1_0_v_n),
    .Vaux9_0_v_p(Vaux9_0_v_p),
    .Vaux9_0_v_n(Vaux9_0_v_n),
    .joy_x(joy_x),
    .joy_y(joy_y)
);

// Debounce left button
debounce #(
    .WAIT_TIME_MS(100),
    .CLK_FREQ(125_000_000)
) Debounce_Left (
    .clk(clk_125m),
    .reset(rst),
    .btn_in(mouse_btn_left),
    .out(btn_debounce_left)
);

// Debounce right button
debounce #(
    .WAIT_TIME_MS(100),
    .CLK_FREQ(125_000_000)
) Debounce_Right (
    .clk(clk_125m),
    .reset(rst),
    .btn_in(mouse_btn_right),
    .out(btn_debounce_right)
);

// Map joy_x and joy_y values to increment values
logic signed [12:0] off_x, off_y;
always_comb begin
    // Horizontal axis
    if (joy_x > DEADBAND_HIGH) begin
        off_x = $signed({1'b0, joy_x} - DEADBAND_HIGH) >>> SENSITIVITY;
    end else if (joy_x < DEADBAND_LOW) begin
        off_x = -$signed(DEADBAND_LOW - {1'b0, joy_x}) >>> SENSITIVITY;
    end else begin
        off_x = '0;
    end
    // Vertical axis
    if (joy_y > DEADBAND_HIGH) begin
        off_y = $signed({1'b0, joy_y} - DEADBAND_HIGH) >>> SENSITIVITY;
    end else if (joy_y < DEADBAND_LOW) begin
        off_y = -$signed(DEADBAND_LOW - {1'b0, joy_y}) >>> SENSITIVITY;
    end else begin
        off_y = '0;
    end
end

// Boundary clamp
screen_coord_t mouse_x_next, mouse_y_next;
always_comb begin
    mouse_x_next = mouse_x + off_x;
    mouse_y_next = mouse_y + off_y;
    // Clamp X
    if (mouse_x_next < 0) mouse_x_next = 0;
    else if (mouse_x_next > MAX_X) mouse_x_next = MAX_X;
    // Clamp Y
    if (mouse_y_next < 0) mouse_y_next = 0;
    else if (mouse_y_next > MAX_Y) mouse_y_next = MAX_Y;
end

// Update mouse position
always_ff @(posedge clk_125m) begin
    if (rst) begin
        // Start in top left of screen
        mouse_x <= '0;
        mouse_y <= '0;
    end else if (move_tick) begin
        mouse_x <= mouse_x_next;
        mouse_y <= mouse_y_next;
    end
end

endmodule
