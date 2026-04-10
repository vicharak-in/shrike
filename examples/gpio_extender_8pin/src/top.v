(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) input rst_n,

    
    (* iopad_external_pin *) input spi_ss_n,   
    (* iopad_external_pin *) input spi_sck,    
    (* iopad_external_pin *) input spi_mosi,   
    (* iopad_external_pin *) output spi_miso,  
    (* iopad_external_pin *) output spi_miso_en,

    // 8-bit GPIO Interface
    (* iopad_external_pin *) input  [7:0] i_gpio_pins,
    (* iopad_external_pin *) output [7:0] o_gpio_pins,
    (* iopad_external_pin *) output [7:0] o_gpio_en
);

    
    assign clk_en = 1'b1;

    // Wires for SPI Module
    wire [7:0] spi_rx_data;
    wire spi_rx_valid;
    wire [7:0] spi_tx_data;

    // Instantiate SPI Target
    spi_target #( .WIDTH(8) ) u_spi_target (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_enable(1'b1),
        .i_ss_n(spi_ss_n),
        .i_sck(spi_sck),
        .i_mosi(spi_mosi),
        .o_miso(spi_miso),
        .o_miso_oe(spi_miso_en),
        .o_rx_data(spi_rx_data),
        .o_rx_data_valid(spi_rx_valid),
        .i_tx_data(spi_tx_data),
        .o_tx_data_hold()
    );

    // GPIO Control Registers
    reg [7:0] gpio_dir_reg; // 1'b0 = Output, 1'b1 = Input
    reg [7:0] gpio_out_reg; // Data to be driven to pins

    // Logic to handle SPI Commands
    reg spi_rx_valid_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_rx_valid_d <= 1'b0;
            gpio_dir_reg   <= 8'hFF; // Default to all Inputs
            gpio_out_reg   <= 8'h00;
        end else begin
            spi_rx_valid_d <= spi_rx_valid;

            // Detect rising edge of spi_rx_valid
            if (spi_rx_valid && !spi_rx_valid_d) begin
                // Simple Command Protocol: {Addr[3:0], Data[3:0]}
                // This allows updating nibbles (4-bits) of the 8-bit registers
                case (spi_rx_data[7:4])
                    4'h1: gpio_dir_reg[3:0] <= spi_rx_data[3:0]; // Set lower nibble dir
                    4'h2: gpio_dir_reg[7:4] <= spi_rx_data[3:0]; // Set upper nibble dir
                    4'h3: gpio_out_reg[3:0] <= spi_rx_data[3:0]; // Set lower nibble data
                    4'h4: gpio_out_reg[7:4] <= spi_rx_data[3:0]; // Set upper nibble data
                endcase
            end
        end
    end
    
    // Readback: Always reflects the physical state of the 8 GPIO pins
    assign spi_tx_data = i_gpio_pins;

    // GPIO Output Assignments
    assign o_gpio_pins = gpio_out_reg;
    assign o_gpio_en   = ~gpio_dir_reg; // OE is high when DIR is Output (0)

endmodule
