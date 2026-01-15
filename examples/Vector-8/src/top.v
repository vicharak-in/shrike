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

    wire [7:0] spi_rx_data;
    wire spi_rx_valid;
    reg  spi_rx_valid_d;
    
    spi_target #( .WIDTH(8) ) u_spi_target (
        .i_clk(clk), .i_rst_n(rst_n), .i_enable(1'b1),
        .i_ss_n(spi_ss_n), .i_sck(spi_sck), .i_mosi(spi_mosi),
        .o_miso(spi_miso), .o_miso_oe(spi_miso_en),
        .o_rx_data(spi_rx_data), .o_rx_data_valid(spi_rx_valid),
        .i_tx_data(cpu_acc), .o_tx_data_hold()
    );

    reg [4:0] r_opcode;
    reg [7:0] r_data;
    reg byte_cnt;
    reg step_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_cnt <= 0;
            step_pulse <= 0;
            spi_rx_valid_d <= 0;
        end else begin
            spi_rx_valid_d <= spi_rx_valid;
            step_pulse <= 0;

            if (spi_rx_valid && !spi_rx_valid_d) begin
                if (byte_cnt == 0) begin
                    r_opcode <= spi_rx_data[4:0]; 
                    byte_cnt <= 1;
                end else begin
                    r_data <= spi_rx_data;
                    byte_cnt <= 0;
                    step_pulse <= 1; 
                end
            end
            if (spi_ss_n) byte_cnt <= 0;
        end
    end

    wire [7:0] cpu_pc;
    wire [7:0] cpu_acc;

    cpu_core u_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .i_step(step_pulse),
        .opcode(r_opcode),
        .data_in(r_data),
        .pc(cpu_pc),
        .acc(cpu_acc)
    );

endmodule
