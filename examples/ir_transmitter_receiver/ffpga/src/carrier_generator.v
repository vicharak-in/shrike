// -----------------------------------------------------------------------------
// Module: carrier_generator
// Description: Generates a 38kHz square wave carrier from a 50MHz input clock.
//              This carrier is only active when 'enable' is high. It is used
//              for modulating the IR transmission signals.
// -----------------------------------------------------------------------------
module carrier_generator (
    input i_clk,
    input enable,
    output reg carrier = 1'b0
);

    reg [9:0] counter = 10'd0;
    reg enable_prev = 1'b0;

    always @(posedge i_clk) begin
        enable_prev <= enable;
        
        if (!enable) begin
            // Reset counter and carrier when disabled
            counter <= 10'd0;
            carrier <= 1'b0;
        end else if (!enable_prev) begin
            // On the rising edge of enable, immediately start the carrier high
            counter <= 10'd0;
            carrier <= 1'b1;
        end else if (counter == 10'd661) begin
            // Toggle carrier every 662 clock cycles (50MHz / (662 * 2) ~= 37.76 kHz)
            // This is close enough to the standard 38kHz IR frequency.
            counter <= 10'd0;
            carrier <= ~carrier;
        end else begin
            // Increment counter
            counter <= counter + 10'd1;
        end
    end

endmodule