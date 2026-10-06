// Debounce module for button clicks
// Generates a 1 clock cycle pulse on click (rising edge)
module debounce #(
    parameter WAIT_TIME_MS = 100,
    parameter CLK_FREQ = 125_000_000
)
(
    input wire logic clk,
    input wire logic btn_in,
    input wire logic reset,
    output logic out
);

localparam longint COUNT_WAIT = (64'(CLK_FREQ)*WAIT_TIME_MS)/1000;

// State machine states
typedef enum logic [1:0] {
    IDLE,
    PRESS,
    WAIT
} state_t;

state_t state;

// Counter register
logic [$clog2(COUNT_WAIT + 1) - 1: 0] counter;

// Double ff synchroniser for input
(* ASYNC_REG = "TRUE" *) logic ff1, ff2;
always_ff @(posedge clk) begin
    if (reset) begin
        ff1 <= 0;
        ff2 <= 0;
    end else begin
        ff1 <= btn_in;
        ff2 <= ff1;
    end
end

// State register, transition logic, and output logic
always_ff @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        counter <= '0;
        out <= 1'b0;
    end else begin
        out <= 1'b0;
        case (state)
            IDLE: begin
                if (ff2) state <= PRESS;
            end

            PRESS: begin
                out <= 1'b1;
                state <= WAIT;
            end

            WAIT: begin
                if (ff2) begin
                    // Button still pressed
                    counter <= '0;
                end else if (counter == COUNT_WAIT - 1) begin
                    // Button has been released for entire wait time
                    state <= IDLE;
                    counter <= '0;
                end else begin
                    counter <= counter + 1'b1;
                end
            end
            default: begin
                state <= IDLE;
                counter <= '0;
            end
        endcase
    end
end

`ifdef COCOTB_SIM
initial begin
    string wave_name;
    // Search for the +WAVE_FILE flag passed by the Python runner
    if ($value$plusargs("WAVE_FILE=%s", wave_name)) begin
        $dumpfile(wave_name);$dumpvars(0, debounce); // 0 dumps all hierarchies underneath
    end
end
`endif

endmodule
