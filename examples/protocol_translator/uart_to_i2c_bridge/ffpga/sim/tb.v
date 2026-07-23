`timescale 1ns/1ps
//------------------------------------------------------------
// Testbench : UART <-> I2C bridge, FPGA is the I2C MASTER.
//
// The TB models an EXTERNAL I2C SLAVE (a sensor) at 0x50 that returns
// (received_byte + 0x10), plus a UART peer. For each vector:
//   send byte X on UART -> FPGA writes X to the slave, reads it back,
//   and echoes the slave's reply (X+0x10) out on UART -> we check it.
//------------------------------------------------------------

module tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;   // 50 MHz

    wire clk_en;
    reg  i_uart_rx = 1'b1;
    wire o_uart_tx, o_uart_tx_oe;

    wire o_i2c_scl, o_i2c_scl_oe, o_i2c_sda, o_i2c_sda_oe;
    reg  slave_sda_drive = 1'b1;

    // Open-drain bus: FPGA master drives via *_oe; TB slave drives SDA low
    wire scl_bus = (o_i2c_scl_oe) ? 1'b0 : 1'b1;
    wire sda_bus = (o_i2c_sda_oe) ? 1'b0 : (slave_sda_drive ? 1'b1 : 1'b0);
    wire i_i2c_scl = scl_bus;
    wire i_i2c_sda = sda_bus;

    top dut (
        .clk(clk), .clk_en(clk_en),
        .i_uart_rx(i_uart_rx), .o_uart_tx(o_uart_tx), .o_uart_tx_oe(o_uart_tx_oe),
        .i_i2c_sda(i_i2c_sda), .i_i2c_scl(i_i2c_scl),
        .o_i2c_scl(o_i2c_scl), .o_i2c_scl_oe(o_i2c_scl_oe),
        .o_i2c_sda(o_i2c_sda), .o_i2c_sda_oe(o_i2c_sda_oe)
    );

    // UART peer -> FPGA
    task send_uart_byte; input [7:0] data; integer i; begin
        i_uart_rx = 1'b0; repeat (434) @(posedge clk);
        for (i=0;i<8;i=i+1) begin i_uart_rx = data[i]; repeat (434) @(posedge clk); end
        i_uart_rx = 1'b1; repeat (434) @(posedge clk);
    end endtask

    // UART monitor on the FPGA's TX
    wire [7:0] tb_rx_byte;
    wire       tb_rx_dv;
    uart_rx #(.CLKS_PER_BIT(9'd434)) u_mon (
        .i_clk(clk), .i_rx(o_uart_tx), .o_rx_byte(tb_rx_byte), .o_rx_dv(tb_rx_dv)
    );

    // External I2C slave model @ 0x50 : store on write, reply (+0x10) on read
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
                        // WRITE: capture data byte, ACK
                        for (bit_i=7; bit_i>=0; bit_i=bit_i-1) begin
                            @(posedge scl_bus); slave_rx_shifter[bit_i] = sda_bus;
                        end
                        slave_stored_data = slave_rx_shifter;
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b0;         // ACK data
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b1;
                    end else begin
                        // READ: drive stored+0x10, MSB first
                        slave_tx_shifter = (slave_stored_data + 8'h10) & 8'hFF;
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

    integer   idx, passes = 0, total = 0;
    reg [7:0] x, expected;
    reg       test_done = 1'b0;

    initial begin
        #100000000;
        if (!test_done) begin $display("Error: timeout"); $finish; end
    end

    reg [7:0] vec [0:11];
    initial begin
        vec[0]=8'h00; vec[1]=8'hFF; vec[2]=8'h55; vec[3]=8'hAA;
        vec[4]=8'h01; vec[5]=8'h02; vec[6]=8'h40; vec[7]=8'h80;
        vec[8]=8'h10; vec[9]=8'h7F; vec[10]=8'hC3; vec[11]=8'h5A;
    end

    initial begin
        $dumpfile("dump.vcd"); $dumpvars(0, tb);
        #5000;
        $display("=== UART <-> I2C (FPGA master) test ===");
        for (idx=0; idx<12; idx=idx+1) begin
            x        = vec[idx];
            expected = (x + 8'h10) & 8'hFF;
            send_uart_byte(x);
            @(posedge tb_rx_dv);

            // Direction UART -> I2C: the slave must have received x on the bus
            total = total + 1;
            if (slave_stored_data === x) passes = passes + 1;
            else $display("  [UART->I2C] idx %02d  sent 0x%02h  slave-got 0x%02h", idx, x, slave_stored_data);

            // Direction I2C -> UART: the slave's reply must return on UART
            total = total + 1;
            if (tb_rx_byte === expected) passes = passes + 1;
            else $display("  [I2C->UART] idx %02d  exp 0x%02h  got 0x%02h", idx, expected, tb_rx_byte);

            #100000;
        end
        test_done = 1'b1;
        $display("Passed %0d / %0d", passes, total);
        if (passes == total) $display("STATUS: SUCCESS");
        else                 $display("STATUS: FAILURE");
        $finish;
    end
endmodule
