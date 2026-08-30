//Display timing generator module

module display #(
    parameter CORDW = 16,      // Signed coordinate width (bits)
    parameter H_RES = 640,      // Horizontal resolution (pixels)
    parameter V_RES = 480,     // Vertical resolution (pixels)
    parameter H_FP = 16,       // Horizontal front porch
    parameter H_SYNC = 96,     // Horizontal sync
    parameter H_BP = 48,       // Horizontal back porch
    parameter V_FP = 10,       // Vertical front porch
    parameter V_SYNC = 2,      // Vertical sync
    parameter V_BP = 33,       // Vertical back porch
    parameter H_POL = 0,       // Horizontal sync polarity (0 = negative, 1 = positive)
    parameter V_POL = 0       //  vertical sync polarity (0 = negative, 1 = positive)
) (
    input logic clk_pix,    // Pixel Clock
    input logic rst_pix,    // Reset in pixel clock domain
    output logic hsync,     // Horizontal sync
    output logic vsync,     // Vertical sync
    output logic de,        // Data enable, low in blanking interval
    output logic frame,     // High at frame start
    output logic line,      // High at line start
    output logic signed [CORDW-1:0] sx, // Horizontal screen position (0 is left)
    output logic signed [CORDW-1:0] sy  // Vertical screen position (0 is top)
);

// Horizontal timings - note that screen coordinates are signed, as blanking occurs before the draw area
localparam signed H_STA = 0 - H_FP - H_BP - H_SYNC;     // Horizontal start
localparam signed HS_STA = H_STA + H_FP;                // Sync start
localparam signed HS_END = HS_STA + H_SYNC;             // Sync end
localparam signed HA_STA = 0;                           // Active start
localparam signed HA_END = H_RES - 1;                   // Active end

// Vertical timings
localparam signed V_STA = 0 - V_FP - V_BP - V_SYNC;     // Vertical start
localparam signed VS_STA = V_STA + V_FP;                // Sync start
localparam signed VS_END = VS_STA + V_SYNC;             // Sync end
localparam signed VA_STA = 0;                           // Active start
localparam signed VA_END = V_RES - 1;                   // Active end

// Internal screen coordinate state
logic signed [CORDW-1:0] x, y;      

// Next coordinate state (combinational)
logic signed [CORDW-1:0] x_next, y_next;
logic hsync_next, vsync_next, de_next, line_next, frame_next;

//Calculate all signals on the next clock cycle
always_comb begin

    //Coordinate count
    if (x == HA_END) begin
        x_next = H_STA;
        y_next = (y == VA_END) ? V_STA : y + 1'b1;    // On last line, wrap back to first line
    end else begin
        x_next = x + 1'b1;                         // Otherwise, advance x
        y_next = y;
    end

    //Sync signals
    hsync_next = (H_POL) ? (x_next >= HS_STA && x_next < HS_END) : ~(x_next >= HS_STA && x_next < HS_END);
    vsync_next = (V_POL) ? (y_next >= VS_STA && y_next < VS_END) : ~(y_next >= VS_STA && y_next < VS_END);

    //Control signals
    de_next = (x_next >= HA_STA && y_next > VA_STA);      // de high in active region
    line_next = (x_next == H_STA);                   // line high at start of x line
    frame_next = (x_next == H_STA && y_next == V_STA);    // frame high at start of first line

end

//Register outputs
always_ff @(posedge clk_pix) begin
    if (rst_pix) begin
        //if reset then we set default values
        hsync <= (H_POL) ? 1'b0 : 1'b1;
        vsync <= (V_POL) ? 1'b0 : 1'b1;
        x <= HS_STA;
        y <= HS_END;
        sx <= H_STA;
        sy <= V_STA;
        de <= 1'b0;
        line <= 1'b0;
        frame <= 1'b0;
    end else begin
        // Update pixel location counter
        x <= x_next;
        y <= y_next;

        // Outputs
        sx <= x_next;
        sy <= y_next;
        de <= de_next;
        line <= line_next;
        frame_next <= frame_next;
        hsync <= hsync_next;
        vsync <= vsync_next;
    end
end



// Generate horizontal and vertical sync
// Note the polarity, if polarity is 0, then sync = 0 indicates we are in sync region
/*always_ff @(posedge clk_pix) begin
    hsync <= (H_POL) ? (x >= HS_STA && x < HS_END) : ~(x >= HS_STA && x < HS_END);
    vsync <= (V_POL) ? (y >= VS_STA && y < VS_END) : ~(y >= VS_STA && y < VS_END);
    if (rst_pix) begin
        hsync <= (H_POL) ? 0 : 1;
        vsync <= (V_POL) ? 0 : 1;
    end
end

// Calculate horizontal and vertical screen position
always_ff @(posedge clk_pix) begin
    if (x == HA_END) begin
        x <= H_STA;
        y <= (y == VA_END) ? V_STA : y + 1;    // On last line, wrap back to first line
    end else begin
        x <= x + 1;                         // Otherwise, advance x
    end
    if (rst_pix) begin
        x <= HS_STA;
        y <= HS_END;
    end
end

// Control Signals (de, frame, line)
always_ff @(posedge clk_pix) begin
    de <= (x >= HA_STA && y > VA_STA);      // de high in active region
    line <= (x == H_STA);                   // line high at start of x line
    frame <= (x == H_STA && y == V_STA);    // frame high at start of first line
    if (rst_pix) begin
        de <= 0;
        line <= 0;
        frame <= 0;
    end
end


// Delay screen position to match sync and control signals
// Otherwise the control signals will be one cycle late 
always_ff @(posedge clk_pix) begin
    sx <= x;
    sy <= y;
    if (rst_pix) begin
        sx <= H_STA;
        sy <= V_STA;
    end
end*/

endmodule
