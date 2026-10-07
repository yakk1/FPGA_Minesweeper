
module game_timer
import minesweeper_pkg::*;
#(
    parameter CLK_FREQ = 125_000_000,
    parameter TIMER_PERIOD = 1000 // Miliseconds
) 
(
    input wire logic clk,
    input wire logic rst,
    input wire logic stop_timer,
    output lcd_count_t timer
);

localparam CLKS_PER_TICK = (CLK_FREQ/1000) * TIMER_PERIOD;
logic [$clog2(CLKS_PER_TICK) - 1 : 0] tick_counter;

always_ff @(posedge clk) begin
    if (rst) begin
        tick_counter <= '0;
        timer <= '0;
    end else if (tick_counter == CLKS_PER_TICK - 1) begin
        tick_counter <= '0;
        timer <= increment_count(timer);
    end else begin
        if (!stop_timer) tick_counter <= tick_counter + 1'b1;
    end
end

endmodule
