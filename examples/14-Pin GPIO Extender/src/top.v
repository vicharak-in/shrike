(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) input rst_n,

    (* iopad_external_pin *) input spi_ss_n,   
    (* iopad_external_pin *) input spi_sck,    
    (* iopad_external_pin *) input spi_mosi,   
    (* iopad_external_pin *) output spi_miso,  
    (* iopad_external_pin *) output spi_miso_en,

    // 14-bit GPIO Interface
    (* iopad_external_pin *) input  [13:0] i_gpio_pins,
    (* iopad_external_pin *) output [13:0] o_gpio_pins,
    (* iopad_external_pin *) output [13:0] o_gpio_en
);

    assign clk_en = 1'b1;

    // SPI module connections
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

    // 14-bit GPIO Control Registers
    reg [13:0] gpio_dir_reg; // 1=Input, 0=Output
    reg [13:0] gpio_out_reg; // Output data
    
    // Byte selector for 14-bit reads
    reg byte_select; // 0=high byte, 1=low byte
    
    // Command state machine
    reg [7:0] cmd_byte;
    reg state; // 0=waiting for command, 1=waiting for data
    reg spi_rx_valid_d;

    // Synchronize SS
    reg [1:0] ss_sync;
    wire ss_falling;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ss_sync <= 2'b11;
        end else begin
            ss_sync <= {ss_sync[0], spi_ss_n};
        end
    end
    
    assign ss_falling = ss_sync[1] & ~ss_sync[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_rx_valid_d <= 1'b0;
            gpio_dir_reg <= 14'h3FFF; // All inputs
            gpio_out_reg <= 14'h0;
            state <= 1'b0;
            cmd_byte <= 8'h0;
            byte_select <= 1'b0;
        end else begin
            spi_rx_valid_d <= spi_rx_valid;

            // Reset byte selector on new transaction
            if (ss_falling) begin
                byte_select <= 1'b0;
                state <= 1'b0;
            end
            // Toggle byte selector on each received byte
            else if (spi_rx_valid && !spi_rx_valid_d) begin
                byte_select <= ~byte_select;
                
                if (state == 1'b0) begin
                    // Receive command byte
                    cmd_byte <= spi_rx_data;
                    state <= 1'b1;
                end else begin
                    // Execute command with data byte
                    case (cmd_byte)
                        8'h10: gpio_dir_reg[7:0] <= spi_rx_data;
                        8'h11: gpio_dir_reg[13:8] <= spi_rx_data[5:0];
                        8'h20: gpio_out_reg[7:0] <= spi_rx_data;
                        8'h21: gpio_out_reg[13:8] <= spi_rx_data[5:0];
                    endcase
                    state <= 1'b0;
                end
            end
            
            // Reset on CS high
            if (spi_ss_n) begin
                state <= 1'b0;
            end
        end
    end
    
    // Alternate between high and low bytes based on byte_select
    assign spi_tx_data = byte_select ? 
                         i_gpio_pins[7:0] :              // Low byte (second read)
                         {2'b00, i_gpio_pins[13:8]};     // High byte (first read)

    // GPIO Output Assignments
    assign o_gpio_pins = gpio_out_reg;
    assign o_gpio_en = ~gpio_dir_reg;

endmodule
// finally done
