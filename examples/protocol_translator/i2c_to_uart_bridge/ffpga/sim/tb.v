`timescale 1ns/1ps

module tb;
    // Clock (50 MHz)
    reg clk = 1'b0;
    always #10 clk = ~clk;

    // I/O pins
    reg master_scl_drive = 1'b1;
    reg master_sda_drive = 1'b1;
    reg i_uart_rx        = 1'b1;

    wire i_i2c_sda;
    wire i_i2c_scl;
    wire o_uart_tx;
    wire o_uart_tx_oe;
    wire o_i2c_sda;
    wire o_i2c_sda_oe;
    wire clk_en;

    // Open-drain emulation
    assign i_i2c_scl = master_scl_drive;
    assign i_i2c_sda = (o_i2c_sda_oe) ? 1'b0 : master_sda_drive;

    // I2C Start
    task i2c_start;
        begin
            master_sda_drive = 1'b1; master_scl_drive = 1'b1; #5000;
            master_sda_drive = 1'b0; #5000;
            master_scl_drive = 1'b0; #5000;
        end
    endtask

    // I2C Stop
    task i2c_stop;
        begin
            master_sda_drive = 1'b0; #5000;
            master_scl_drive = 1'b1; #5000;
            master_sda_drive = 1'b1; #5000;
        end
    endtask

    // I2C Write
    task i2c_write_byte;
        input [7:0] data;
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                master_sda_drive = data[i]; #2500;
                master_scl_drive = 1'b1;    #5000;
                master_scl_drive = 1'b0;    #2500;
            end
            master_sda_drive = 1'b1; #2500; // Release for ACK
            master_scl_drive = 1'b1; #5000;
            master_scl_drive = 1'b0; #2500;
        end
    endtask

    // I2C Read
    task i2c_read_byte;
        output [7:0] data;
        integer i;
        begin
            master_sda_drive = 1'b1; // Release line
            for (i = 7; i >= 0; i = i - 1) begin
                #2500;
                master_scl_drive = 1'b1; #2500;
                data[i] = i_i2c_sda;     #2500;
                master_scl_drive = 1'b0; #2500;
            end
            master_sda_drive = 1'b1; #2500; // Send NACK
            master_scl_drive = 1'b1; #5000;
            master_scl_drive = 1'b0; #2500;
        end
    endtask

    // UART Transmit
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            i_uart_rx = 1'b0; repeat (434) @(posedge clk); // Start bit
            for (i = 0; i < 8; i = i + 1) begin
                i_uart_rx = data[i]; repeat (434) @(posedge clk); // 8 Data bits
            end
            i_uart_rx = 1'b1; repeat (434) @(posedge clk); // Stop bit
        end
    endtask

    // DUT Instantiation
    top dut (
        .clk(clk), .clk_en(clk_en),
        .i_uart_rx(i_uart_rx), .o_uart_tx(o_uart_tx), .o_uart_tx_oe(o_uart_tx_oe),
        .i_i2c_sda(i_i2c_sda), .i_i2c_scl(i_i2c_scl),
        .o_i2c_sda(o_i2c_sda), .o_i2c_sda_oe(o_i2c_sda_oe)
    );

    // UART Out Monitor
    wire [7:0] mon_uart_out_byte;
    wire       mon_uart_out_dv;
    reg  [7:0] master_harvested_byte = 8'h00;

    uart_rx #(.CLKS_PER_BIT(9'd434)) u_uart_out_monitor (
        .i_clk(clk), .i_rx(o_uart_tx), .o_rx_byte(mon_uart_out_byte), .o_rx_dv(mon_uart_out_dv)
    );

    // MCU Responder Logic
    reg [7:0] mcu_reply_data;
    initial begin
        forever begin
            @(posedge mon_uart_out_dv);
            mcu_reply_data = (mon_uart_out_byte + 8'h05) & 8'hFF; 
            #40000; 
            send_uart_byte(mcu_reply_data);
        end
    end

    // Test Variables
    integer idx;
    integer total_vectors = 66; 
    integer verified_passes = 0;
    reg [7:0] write_val;
    reg [7:0] golden_reply;

    initial begin
        $dumpfile("dump.vcd"); 
        $dumpvars(0, tb);
        #1000;
        
        $display("Starting simulation...");
        
        fork
            begin : master_stress_engine
                for (idx = 0; idx < total_vectors; idx = idx + 1) begin
                    
                    // Generate patterns
                    if (idx < 4) begin
                        case(idx)
                            0: write_val = 8'h00; 
                            1: write_val = 8'hFF; 
                            2: write_val = 8'h55; 
                            3: write_val = 8'hAA; 
                        endcase
                    end 
                    else if (idx >= 4 && idx < 12) begin
                        write_val = (8'h01 << (idx - 4));
                    end 
                    else begin
                        write_val = $random & 8'hFF;
                    end

                    golden_reply = (write_val + 8'h05) & 8'hFF;

                    // I2C Write
                    i2c_start();
                    i2c_write_byte({7'h50, 1'b0}); 
                    i2c_write_byte(write_val);          
                    i2c_stop();

                    #100000; 

                    // I2C Read
                    i2c_start();
                    i2c_write_byte({7'h50, 1'b1}); 
                    i2c_read_byte(master_harvested_byte);
                    i2c_stop();

                    // Display results
                    if (idx < 12 || idx % 15 == 0) begin
                        $display("Vector %02d | Sent: 0x%02h | Exp: 0x%02h | Got: 0x%02h | %s", 
                                 idx, write_val, golden_reply, master_harvested_byte,
                                 (master_harvested_byte === golden_reply) ? "PASS" : "FAIL");
                    end

                    if (master_harvested_byte === golden_reply) begin
                        verified_passes = verified_passes + 1;
                    end
                    
                    #50000; 
                end
                disable watchdog_timer_gate;
            end

            begin : watchdog_timer_gate
                #50000000; 
                $display("Error: Simulation timeout!");
                $finish;
            end
        join

        // Status Summary
        $display("Done. Passed: %0d/%0d", verified_passes, total_vectors);
        if (verified_passes == total_vectors) begin
            $display("STATUS: SUCCESS");
        end else begin
            $display("STATUS: FAILURE");
        end
        $finish;
    end
endmodule