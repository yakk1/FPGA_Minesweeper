
module clut #(
    parameter COLOUR_W = 12,
    parameter COLOUR_IDX_W = 4,
    parameter COLOUR_FILE = "palette_rom.mem"
) ( 
    input logic clk,                           //Input clock
    input logic [COLOUR_IDX_W-1:0] r_addr,     //Read address
    input logic [COLOUR_IDX_W-1:0] w_addr,     //Write address
    input logic [COLOUR_W-1:0] w_value,        //Write value
    input logic we,                            //Write enable (high means write)
    output logic [COLOUR_W-1:0] dout            //Read value
);

logic [COLOUR_W-1:0] clut_mem [0:2**COLOUR_IDX_W-1];

//Initialise with the colour file, if there is one
initial begin
    if (COLOUR_FILE != "") begin
        $readmemh(COLOUR_FILE, clut_mem);
    end
end

//Write
always_ff @(posedge clk) begin
    if (we) begin
        clut_mem[w_addr] <= w_value;
    end
    dout <= clut_mem[r_addr];
end

endmodule