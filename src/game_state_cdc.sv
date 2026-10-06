// Module to transfer game state to graphics module in slower clock domain

module game_state_cdc 
import minesweeper_pkg::*;
(
    //Fast clock domain
    input wire logic clk_125m,
    input wire logic rst_fast,
    input wire logic state_valid,
    input wire databus_t state_in,

    //Slow clock domain
    input wire logic clk_pix,
    input wire logic rst_pix,
    input wire logic frame,
    output databus_t state_out
);

// Fast domain
databus_t holding_r;
logic send_flag;
logic locked;
(* ASYNC_REG = "TRUE" *) logic ff1, reply_flag;

// Slow Domain
databus_t state_clk_pix_domain;
logic echo_flag;
logic copy_data;
(* ASYNC_REG = "TRUE" *) logic ff3, flag_now;

// Control signals (handshake)
assign locked = (send_flag != reply_flag);
assign copy_data = (flag_now != echo_flag);

// Fast clock domain (game logic)

always_ff @(posedge clk_125m) begin
    if (rst_fast) begin
        send_flag <= 1'b0;
        ff1 <= 1'b0;
        reply_flag <= 1'b0;
        holding_r <= '0;
    end else begin
        // Bring slow domain reply to fast domain
        ff1 <= echo_flag;
        reply_flag <= ff1;

        // Put new data into holding register and flip flag
        if (!locked && state_valid) begin
            holding_r <= state_in;
            send_flag <= ~send_flag;
        end
    end
end

// Slow clock domain (display driver)

always_ff @(posedge clk_pix) begin
    if (rst_pix) begin
        ff3 <= 1'b0;
        flag_now <= 1'b0;
        echo_flag <= 1'b0;
        state_clk_pix_domain <= '0;
        state_out <= '0;
    end else begin
        // Bring send flag to pixel clock domain
        ff3 <= send_flag;
        flag_now <= ff3;

        // Echo flag back to fast domain
        echo_flag <= flag_now;

        // Update staging register
        if (copy_data) begin
            state_clk_pix_domain <= holding_r;
        end

        // Update output with reference to frame rate
        if (frame) begin
            state_out <= (copy_data) ? holding_r : state_clk_pix_domain;
        end
    end
end

endmodule

