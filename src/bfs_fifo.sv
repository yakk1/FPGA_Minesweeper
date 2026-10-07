
module bfs_fifo
import minesweeper_pkg::*;
#(
    parameter DEPTH = 64
)(
    input wire logic clk,
    input wire logic rst,

    // Push interface (enqueue a neighbor)
    input wire logic push,
    input wire gridx_coord_t wr_x,
    input wire gridy_coord_t wr_y,

    // Pop interface (advance to next coordinate)
    input wire logic pop,
    output gridx_coord_t rd_x,
    output gridy_coord_t rd_y,

    // Status flags
    output logic empty,
    output logic full
);

localparam PTR_BITS = $clog2(DEPTH);
localparam COORD_BITS = $bits(gridx_coord_t) + $bits(gridy_coord_t);

// LUTRAM
logic [COORD_BITS-1:0] ram [DEPTH-1:0];

// Pointers
logic [PTR_BITS:0] head_ptr, tail_ptr;

assign empty = (head_ptr == tail_ptr);
assign full = (head_ptr[PTR_BITS] != tail_ptr[PTR_BITS]) && (head_ptr[PTR_BITS-1:0] == tail_ptr[PTR_BITS-1:0]);

// Write (Synchronous)
always_ff @(posedge clk) begin
    if (push && !full) begin
        ram[tail_ptr[PTR_BITS-1:0]] <= {wr_y, wr_x};
    end
end

// Read
assign {rd_y, rd_x} = ram[head_ptr[PTR_BITS-1:0]];

// Control pointers
always_ff @(posedge clk) begin
    if (rst) begin
        tail_ptr <= '0;
        head_ptr <= '0;
    end else begin
        if (push && !full) tail_ptr <= tail_ptr + 1'b1;
        if (pop && !empty) head_ptr <= head_ptr + 1'b1;
    end
end

endmodule
