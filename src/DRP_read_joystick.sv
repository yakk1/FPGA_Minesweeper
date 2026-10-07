// This module reads the 12 bit ADC value from the joystick (to act as a mouse)

module DRP_read_joystick (
    input wire logic clk_125m,
    input wire logic reset,
    input wire logic Vaux1_0_v_p,
    input wire logic Vaux1_0_v_n,
    input wire logic Vaux9_0_v_p,
    input wire logic Vaux9_0_v_n,

    output logic [11:0] joy_x,
    output logic [11:0] joy_y
);

//XADC signals
logic [6:0] daddr_in;
logic den_in;
logic drdy_out;
logic [15:0] do_out;

// Initialise XADC Module
xadc_wiz_0 XADC (
    .dclk_in     (clk_125m), 
    .reset_in    (reset),
    .daddr_in    (daddr_in), 
    .den_in      (den_in), 
    .di_in       (16'h0000),
    .do_out      (do_out),
    .drdy_out    (drdy_out),
    .dwe_in      (1'b0),
    .vauxp1      (Vaux1_0_v_p),
    .vauxn1      (Vaux1_0_v_n),               
    .vauxp9      (Vaux9_0_v_p),
    .vauxn9      (Vaux9_0_v_n),              
    .vp_in       (1'b0),
    .vn_in       (1'b0),
    .eoc_out     (),
    .channel_out (),
    .alarm_out   (),
    .eos_out     (),
    .busy_out    ()
);

//FSM to read X and Y coordinates of joystick
typedef enum logic [2:0] {
    INIT,
    REQ_X,
    WAIT_X,
    REQ_Y,
    WAIT_Y
} state_t;

state_t state;
logic [7:0] init_counter;

//ILA
/*
ila_0 ILA(
    .clk(clk_125m),
    .probe0(joy_x),
    .probe1(joy_y),
    .probe2(state),
    .probe3(drdy_out)
);
*/

// Read from the ADC in successive read requests (DRP)
// Request from address X/Y (1 clock cycle)
// Wait for valid out and then repeat
always_ff @(posedge clk_125m) begin
    if (reset) begin
        state <= INIT;
        init_counter <= 8'd0;
        den_in <= 1'b0;
        joy_x <= '0;
        joy_y <= '0; 
        daddr_in <= '0;
    end else begin
        den_in <= 1'b0;    // Default 0 (only meant to pulse for one clock cycle)
        case (state) 
            INIT: begin
                // Wait for XADC to wake up after reset
                if (init_counter == 8'hFF) begin
                    state <= REQ_X;
                end else begin
                    init_counter <= init_counter + 1'b1;
                end
            end
            
            REQ_X: begin
                daddr_in <= 7'h11;      // Set address to Vaux1 (A0)
                den_in <= 1'b1;
                state <= WAIT_X;
            end

            WAIT_X: begin
                if (drdy_out) begin
                    joy_x <= do_out[15:4];  // Capture 12 bit coordinate (left justified)
                    state <= REQ_Y;
                end
            end

            REQ_Y: begin
                daddr_in <= 7'h19;      // Set address to Vaux9 (A1)
                den_in <= 1'b1;
                state <= WAIT_Y;
            end

            WAIT_Y: begin
                if (drdy_out) begin
                    joy_y <= do_out[15:4];  // Capture 12 bit coordinate (left justified)
                    state <= REQ_X;
                end
            end
            
            default: state <= INIT;
        endcase
    end
end

endmodule
