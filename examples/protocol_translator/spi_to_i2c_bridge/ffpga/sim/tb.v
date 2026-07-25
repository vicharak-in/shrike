`timescale 1ns/1ps
//------------------------------------------------------------
// Testbench : SPI <-> I2C, FPGA = SPI slave + I2C MASTER.
//
// TB models an external SPI master + an external I2C slave (sensor)
// at 0x50 that returns (received + 0x05). Each vector checks BOTH
// directions:
//   SPI -> I2C : the byte the SPI host sent reached the I2C slave
//   I2C -> SPI : the slave's reply came back on MISO (read-back)
//------------------------------------------------------------

module tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;   // 50 MHz

    // SPI master stimulus
    reg spi_sck  = 1'b0;
    reg spi_mosi = 1'b0;
    reg spi_ss   = 1'b1;
    wire o_spi_miso, o_spi_miso_oe, clk_en;

    // I2C open-drain bus: FPGA is master, TB models the slave
    reg  slave_sda_drive = 1'b1;
    wire o_i2c_scl, o_i2c_scl_oe, o_i2c_sda, o_i2c_sda_oe;
    wire scl_bus = (o_i2c_scl_oe) ? 1'b0 : 1'b1;
    wire sda_bus = (o_i2c_sda_oe) ? 1'b0 : (slave_sda_drive ? 1'b1 : 1'b0);
    wire i_i2c_scl = scl_bus;
    wire i_i2c_sda = sda_bus;

    top dut (
        .clk(clk), .clk_en(clk_en),
        .i_spi_sck(spi_sck), .i_spi_mosi(spi_mosi),
        .o_spi_miso(o_spi_miso), .o_spi_miso_oe(o_spi_miso_oe), .i_spi_ss(spi_ss),
        .i_i2c_sda(i_i2c_sda), .i_i2c_scl(i_i2c_scl),
        .o_i2c_scl(o_i2c_scl), .o_i2c_scl_oe(o_i2c_scl_oe),
        .o_i2c_sda(o_i2c_sda), .o_i2c_sda_oe(o_i2c_sda_oe)
    );

    // SPI master: one byte per CS (mode 0, MSB first)
    localparam SPI_HALF = 500;
    task spi_xfer; input [7:0] mosi_byte; output [7:0] miso_byte; integer i; begin
        spi_ss = 1'b0; #SPI_HALF;
        for (i=7;i>=0;i=i-1) begin
            spi_mosi = mosi_byte[i]; #SPI_HALF;
            spi_sck  = 1'b1;         #SPI_HALF;
            miso_byte[i] = o_spi_miso;
            spi_sck  = 1'b0;
        end
        #SPI_HALF;
        spi_ss = 1'b1; #SPI_HALF;
    end endtask

    // I2C slave model @ 0x50 : store on write, reply (+0x05) on read
    reg [7:0] slave_rx_shifter;
    reg [7:0] slave_stored_data = 8'h00;
    reg [7:0] slave_tx_shifter;
    integer   bit_i;
    initial begin
        forever begin
            slave_sda_drive = 1'b1;
            @(negedge sda_bus);
            if (scl_bus === 1'b1) begin                 // START
                for (bit_i=7; bit_i>=0; bit_i=bit_i-1) begin
                    @(posedge scl_bus); slave_rx_shifter[bit_i] = sda_bus;
                end
                @(negedge scl_bus);
                if (slave_rx_shifter[7:1] == 7'h50) begin
                    slave_sda_drive = 1'b0;             // ACK addr
                    @(negedge scl_bus);
                    slave_sda_drive = 1'b1;
                    if (slave_rx_shifter[0] == 1'b0) begin
                        for (bit_i=7; bit_i>=0; bit_i=bit_i-1) begin
                            @(posedge scl_bus); slave_rx_shifter[bit_i] = sda_bus;
                        end
                        slave_stored_data = slave_rx_shifter;
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b0;         // ACK data
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b1;
                    end else begin
                        slave_tx_shifter = (slave_stored_data + 8'h05) & 8'hFF;
                        for (bit_i=7; bit_i>=0; bit_i=bit_i-1) begin
                            slave_sda_drive = slave_tx_shifter[bit_i];
                            @(negedge scl_bus);
                        end
                        slave_sda_drive = 1'b1;         // release for master NACK
                        @(negedge scl_bus);
                    end
                end
            end
        end
    end

    reg [7:0] vec [0:11];
    initial begin
        vec[0]=8'h00; vec[1]=8'hFF; vec[2]=8'h55; vec[3]=8'hAA;
        vec[4]=8'h01; vec[5]=8'h02; vec[6]=8'h40; vec[7]=8'h80;
        vec[8]=8'h10; vec[9]=8'h7F; vec[10]=8'hC3; vec[11]=8'h5A;
    end

    integer   idx, passes = 0, total = 0;
    reg [7:0] x, expected, cmd_miso, got;
    reg       test_done = 1'b0;

    initial begin
        #500000000;
        if (!test_done) begin $display("Error: timeout"); $finish; end
    end

    initial begin
        $dumpfile("dump.vcd"); $dumpvars(0, tb);
        #2000;
        $display("=== SPI <-> I2C (FPGA master) test ===");
        for (idx=0; idx<12; idx=idx+1) begin
            x        = vec[idx];
            expected = (x + 8'h05) & 8'hFF;

            spi_xfer(x, cmd_miso);      // command byte
            #3000000;                    // FPGA does I2C write + turnaround + read
            spi_xfer(8'h00, got);       // dummy read-back

            // Direction SPI -> I2C: the slave must have received x
            total = total + 1;
            if (slave_stored_data === x) passes = passes + 1;
            else $display("  [SPI->I2C] idx %02d  sent 0x%02h  slave-got 0x%02h", idx, x, slave_stored_data);

            // Direction I2C -> SPI: the reply must come back on MISO
            total = total + 1;
            if (got === expected) passes = passes + 1;
            else $display("  [I2C->SPI] idx %02d  exp 0x%02h  got 0x%02h", idx, expected, got);

            #100000;
        end
        test_done = 1'b1;
        $display("Passed %0d / %0d", passes, total);
        if (passes == total) $display("STATUS: SUCCESS");
        else                 $display("STATUS: FAILURE");
        $finish;
    end
endmodule
