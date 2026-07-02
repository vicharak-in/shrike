`timescale 1ns/1ps

module tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;

    wire clk_en;
    reg  i_uart_rx = 1'b1;
    wire o_uart_tx;
    wire o_uart_tx_oe;
    
    wire i_i2c_scl;
    wire i_i2c_sda;
    wire o_i2c_scl;
    wire o_i2c_scl_oe;
    wire o_i2c_sda;
    wire o_i2c_sda_oe;

    wire scl_bus;
    wire sda_bus;
    reg  slave_sda_drive = 1'b1;

    assign scl_bus   = (o_i2c_scl_oe) ? 1'b0 : 1'b1;
    assign sda_bus   = (o_i2c_sda_oe) ? 1'b0 : (slave_sda_drive ? 1'b1 : 1'b0);

    assign i_i2c_scl = scl_bus;
    assign i_i2c_sda = sda_bus;

    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            i_uart_rx = 1'b0; repeat (434) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                i_uart_rx = data[i]; repeat (434) @(posedge clk);
            end
            i_uart_rx = 1'b1; repeat (434) @(posedge clk);
        end
    endtask

    top dut (
        .clk(clk), .clk_en(clk_en),
        .i_uart_rx(i_uart_rx), .o_uart_tx(o_uart_tx), .o_uart_tx_oe(o_uart_tx_oe),
        .i_i2c_sda(i_i2c_sda), .i_i2c_scl(i_i2c_scl),
        .o_i2c_scl(o_i2c_scl), .o_i2c_scl_oe(o_i2c_scl_oe),
        .o_i2c_sda(o_i2c_sda), .o_i2c_sda_oe(o_i2c_sda_oe)
    );

    wire [7:0] tb_rx_byte;
    wire       tb_rx_dv;

    uart_rx #(.CLKS_PER_BIT(9'd434)) u_tb_monitor (
        .i_clk(clk), .i_rx(o_uart_tx), .o_rx_byte(tb_rx_byte), .o_rx_dv(tb_rx_dv)
    );

    reg [7:0] slave_rx_shifter;
    reg [7:0] slave_stored_data;
    reg [7:0] slave_tx_shifter;
    integer bit_i;

    initial begin
        forever begin
            slave_sda_drive = 1'b1;
            @(negedge sda_bus);
            if (scl_bus === 1'b1) begin
                for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
                    @(posedge scl_bus);
                    slave_rx_shifter[bit_i] = sda_bus;
                end
                
                @(negedge scl_bus);
                if (slave_rx_shifter[7:1] == 7'h50) begin
                    slave_sda_drive = 1'b0;
                    
                    @(negedge scl_bus);
                    slave_sda_drive = 1'b1;
                    
                    if (slave_rx_shifter[0] == 1'b0) begin
                        for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
                            @(posedge scl_bus);
                            slave_rx_shifter[bit_i] = sda_bus;
                        end
                        slave_stored_data = slave_rx_shifter;
                        
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b0;
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b1;
                    end 
                    else begin
                        slave_tx_shifter = slave_stored_data + 8'h05;
                        for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
                            slave_sda_drive = slave_tx_shifter[bit_i];
                            @(negedge scl_bus);
                        end
                        slave_sda_drive = 1'b1;
                        @(negedge scl_bus);
                    end
                end
            end
        end
    end

    integer idx;
    integer passed_count = 0;
    reg [7:0] current_test_val;
    reg [7:0] golden_target_reply;

    initial begin
        $dumpfile("dump.vcd"); $dumpvars(0, tb);
        #5000;
        
        $display("Starting verification...");
        
        fork
            begin : main_test_engine
                for (idx = 0; idx < 10; idx = idx + 1) begin
                    current_test_val   = (idx == 0) ? 8'h4A : $random & 8'hFF;
                    golden_target_reply = (current_test_val + 8'h05) & 8'hFF;
                    
                    $display("Vector %0d | Inbound UART: 0x%02h", idx, current_test_val);
                    send_uart_byte(current_test_val);
                    
                    @(posedge tb_rx_dv);
                    $display("Vector %0d | Outbound Echo: 0x%02h (Expected: 0x%02h)", idx, tb_rx_byte, golden_target_reply);
                    
                    if (tb_rx_byte === golden_target_reply) begin
                        passed_count = passed_count + 1;
                    end else begin
                        $display("Vector %0d | Error: Data mismatch detected", idx);
                    end
                    
                    #200000;
                end
                disable simulation_watchdog;
            end

            begin : simulation_watchdog
                #100000000;
                $display("Error: Testbench timeout occurred.");
                $finish;
            end
        join

        $display("Verification Results:");
        $display("Total vectors tested: %0d", 10);
        $display("Total passes: %0d", passed_count);
        if (passed_count == 10) begin
            $display("Status: PASS");
        end else begin
            $display("Status: FAIL");
        end
        $finish;
    end
endmodule