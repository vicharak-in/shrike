(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en,
    (* iopad_external_pin *) input rst_n,

    // SPI Interface
    (* iopad_external_pin *) input spi_ss_n,
    (* iopad_external_pin *) input spi_sck,
    (* iopad_external_pin *) input spi_mosi,
    (* iopad_external_pin *) output spi_miso,
    (* iopad_external_pin *) output spi_miso_en
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

    // CPU Signals
    wire [3:0] cpu_pc;
    wire [3:0] cpu_regval;

    // Logic to handle Inputs
    reg cpu_reset_cmd;
    reg step_cmd;
    reg [1:0] cpu_instr;
    reg [3:0] cpu_data;
    reg last_data_bit_3;

    // Pulse generation signals
    reg spi_rx_valid_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_rx_valid_d <= 1'b0;
            cpu_reset_cmd <= 1'b0;
            step_cmd <= 1'b0;
            cpu_instr <= 2'b00;
            cpu_data <= 4'b0000;
            last_data_bit_3 <= 1'b0;
        end else begin
            spi_rx_valid_d <= spi_rx_valid;

            // Default: step_cmd is LOW. It will only be high for ONE cycle if triggered below.
            step_cmd <= 1'b0;

            // Detect rising edge of spi_rx_valid (New packet arrived)
            if (spi_rx_valid && !spi_rx_valid_d) begin
                // Packet Format: {Data[3:0], Instr[1:0], Reset, Step}
                cpu_data <= spi_rx_data[7:4];
                cpu_instr <= spi_rx_data[3:2];
                cpu_reset_cmd <= spi_rx_data[1];
                
                // If the step bit (bit 0) is 1, pulse step_cmd HIGH for this cycle only
                if (spi_rx_data[0]) begin
                    step_cmd <= 1'b1;
                end

                // Keep track of Data[3] for JUMP instructions
                last_data_bit_3 <= spi_rx_data[7];
            end
        end
    end
    
    // Continuous assignment - always reflects current CPU state for readback
    assign spi_tx_data = {cpu_regval, cpu_pc};

    // Instantiate the CPU Core
    cpu_core u_cpu (
        .clk(clk),
        .rst_n(rst_n && !cpu_reset_cmd),
        .i_step(step_cmd),
        .instruction(cpu_instr),
        .data_in(cpu_data),
        .data_in_3_latched(last_data_bit_3),
        .pc(cpu_pc),
        .regval(cpu_regval)
    );

endmodule
