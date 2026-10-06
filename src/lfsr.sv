
module lfsr
import minesweeper_pkg::*;
(
    input wire logic clk,
    output gridx_coord_t rand_x,
    output gridy_coord_t rand_y
);

    // Parameters for variable bit selects
    localparam X_BITS = $clog2(BOARD_WIDTH);
    localparam Y_BITS = $clog2(BOARD_HEIGHT);

    // Initial seed
    logic [31:0] lfsr = 32'hACE1_CAFE;

    // Shift LFSR
    // No reset, so that the time of placement is random
    always_ff @(posedge clk) begin
        lfsr <= {1'b0, lfsr[31:1]} ^ (lfsr[0] ? 32'h8020_0003 : 32'h0);
    end

    // Bit selection (selecting spaced bits for added randomisation)
    integer i;
    always_comb begin
        for (i = 0; i < X_BITS; i = i + 1) begin
            rand_x[i] = lfsr[i * 3];       // Select bits 0,3,6...
        end
        for (i = 0; i < Y_BITS; i = i + 1) begin
            rand_y[i] = lfsr[(i * 3) + 1]; // Select bits 1,4,7.....
        end
    end

endmodule