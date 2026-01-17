(* top *) module top ( 
    (* iopad_external_pin, clkbuf_inhibit *) input clk,
    (* iopad_external_pin *) output clk_en, 
    (* iopad_external_pin *) input  rst_n, 

    // SPI
    (* iopad_external_pin *) input  spi_ss_n, 
    (* iopad_external_pin *) input  spi_sck, 
    (* iopad_external_pin *) input  spi_mosi, 
    (* iopad_external_pin *) output spi_miso, 
    (* iopad_external_pin *) output spi_miso_en,
    
    // BRAM
    (* iopad_external_pin *) output [1:0] BRAM0_RATIO,
    (* iopad_external_pin *) output [7:0] BRAM0_DATA_IN,
    (* iopad_external_pin *) output       BRAM0_WEN,
    (* iopad_external_pin *) output       BRAM0_WCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM0_WRITE_ADDR,
    (* iopad_external_pin *) input  [3:0] BRAM0_DATA_OUT,
    (* iopad_external_pin *) output       BRAM0_REN,
    (* iopad_external_pin *) output       BRAM0_RCLKEN,
    (* iopad_external_pin *) output [8:0] BRAM0_READ_ADDR
);

    assign clk_en = 1'b1;

    // SPI interface 
    wire [7:0] spi_rx_data;
    wire       spi_rx_valid;
    reg  [7:0] spi_tx_data;


    // LIFO signals
    reg  [3:0] lifo_din;
    reg        lifo_we;
    reg        lifo_re;
    wire [3:0] lifo_dout;
    wire       lifo_full;
    wire       lifo_empty;


    // SPI module
    spi_target #(
        .CPOL(1'b0),
        .CPHA(1'b0),
        .WIDTH(8),
        .LSB(1'b0)
    ) u_spi_target (
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


    // LIFO BRAM
    lifo_bram lifo_inst (
        .clk        (clk),
        .nReset     (rst_n),
        .DIN        (lifo_din),
        .WE         (lifo_we),
        .RE         (lifo_re),
        .DOUT       (lifo_dout),
        .LIFO_full  (lifo_full),
        .LIFO_empty (lifo_empty),

        // BRAM ports
        .BRAM0_RATIO      (BRAM0_RATIO),
        .BRAM0_DATA_IN    (BRAM0_DATA_IN),
        .BRAM0_WEN        (BRAM0_WEN),
        .BRAM0_WCLKEN     (BRAM0_WCLKEN),
        .BRAM0_WRITE_ADDR (BRAM0_WRITE_ADDR),
        .BRAM0_DATA_OUT   (BRAM0_DATA_OUT),
        .BRAM0_REN        (BRAM0_REN),
        .BRAM0_RCLKEN     (BRAM0_RCLKEN),
        .BRAM0_READ_ADDR  (BRAM0_READ_ADDR)
    );

    
    reg spi_rx_valid_d;
    wire spi_rx_pulse;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            spi_rx_valid_d <= 1'b0;
        else
            spi_rx_valid_d <= spi_rx_valid;
    end
    assign spi_rx_pulse = spi_rx_valid & ~spi_rx_valid_d;

    
    // -----------------------------------------------------------------
    // Processor Logic
    // -----------------------------------------------------------------
    
    reg [2:0] cnt;
    reg [7:0] A, B, C;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lifo_we      <= 1'b0;
            lifo_re      <= 1'b0;
            lifo_din     <= 4'b0;
            spi_tx_data  <= 8'b0;
            cnt <= 0;
        end else begin
            lifo_we      <= 1'b0;
            lifo_re      <= 1'b0;

            if (spi_rx_pulse) begin
                casez (spi_rx_data)
                    8'b0000_0000: C <= C; 

                    8'b0001_????: begin
                        lifo_din <= spi_rx_data[3:0];
                        lifo_we <= 1'b1;
                    end

                    8'b0010_0000: begin 
                        cnt <= 3'b1;
                        lifo_re <= 1'b1;
                    end

                    8'b0011_0000: begin
                        lifo_din <= A[3:0];
                        lifo_we <= 1'b1;
                    end

                    8'b0011_0001: begin
                        lifo_din <= B[3:0];
                        lifo_we <= 1'b1;
                    end

                    8'b0011_0010: begin
                        lifo_din <= C[3:0];
                        lifo_we <= 1'b1;
                    end

                    8'b0011_0011: begin 
                        cnt <= 3'b1;
                        lifo_re <= 1'b1;
                    end

                    8'b0011_0100: begin 
                        cnt <= 3'b1;
                        lifo_re <= 1'b1;
                    end

                    8'b0011_0101: begin 
                        cnt <= 3'b1;
                        lifo_re <= 1'b1;
                    end

                    8'b1100_0000: C <= A + B;
                    8'b1100_0001: C <= A - B;
                    8'b1100_0010: C <= A * B;
                    8'b1100_0011: C <= A / B;
                    8'b1100_0100: C <= A << B;
                    8'b1100_0101: C <= A >> B;
                    8'b1100_0110: C <= {A[7], A[7:1]};

                    default: C <= C;
                endcase
            end

            if (cnt != 3'b000) begin
                cnt <= cnt + 1;
                if (cnt == 3'b100) begin 
                    case (spi_rx_data)
                        8'b0010_0000 : spi_tx_data <= {lifo_empty, lifo_full, 2'b00, lifo_dout};
                        8'b0011_0011 : A <= {4'b0000, lifo_dout}; 
                        8'b0011_0100 : B <= {4'b0000, lifo_dout}; 
                        8'b0011_0101 : C <= {4'b0000, lifo_dout}; 
                        default: spi_tx_data <= {lifo_empty, lifo_full, 2'b00, lifo_dout};
                    endcase    
                    cnt <= 3'b0;
                end
            end
        end
    end
  
endmodule