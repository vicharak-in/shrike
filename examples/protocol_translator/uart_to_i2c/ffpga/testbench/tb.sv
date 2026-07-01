`timescale 1ns/1ps

module tb;
    // System Clock Source Grid (50 MHz Generator)
    reg clk = 1'b0;
    always #10 clk = ~clk;

    // Emulated Microcontroller Interface Stimulus Pins
    wire clk_en;
    reg  i_uart_rx = 1'b1;
    wire o_uart_tx;
    wire o_uart_tx_oe;
    
    wire i_i2c_sda;
    wire i_i2c_scl;
    wire o_i2c_scl;
    wire o_i2c_scl_oe;
    wire o_i2c_sda;
    wire o_i2c_sda_oe;

    // Structural Open-Drain Emulation Network with Pull-ups
    wire scl_bus;
    wire sda_bus;
    reg  slave_sda_drive = 1'b1; // Default floating high (Pull-up)

    assign scl_bus   = (o_i2c_scl_oe) ? 1'b0 : 1'b1;
    assign sda_bus   = (o_i2c_sda_oe) ? 1'b0 : (slave_sda_drive ? 1'b1 : 1'b0);

    assign i_i2c_scl = scl_bus;
    assign i_i2c_sda = sda_bus;

    // =====================================================
    // CORE ASYNCHRONOUS UART TRANSMISSION STIMULUS TASK
    // =====================================================
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            i_uart_rx = 1'b0; repeat (434) @(posedge clk); // Start Bit Frame
            for (i = 0; i < 8; i = i + 1) begin
                i_uart_rx = data[i]; repeat (434) @(posedge clk); // 8 Data Bits
            end
            i_uart_rx = 1'b1; repeat (434) @(posedge clk); // Stop Bit Frame
        end
    endtask

    // Instantiate Reverse Bridge Unit Under Test (DUT)
    top dut (
        .clk(clk), .clk_en(clk_en),
        .i_uart_rx(i_uart_rx), .o_uart_tx(o_uart_tx), .o_uart_tx_oe(o_uart_tx_oe),
        .i_i2c_sda(i_i2c_sda), .i_i2c_scl(i_i2c_scl),
        .o_i2c_scl(o_i2c_scl), .o_i2c_scl_oe(o_i2c_scl_oe),
        .o_i2c_sda(o_i2c_sda), .o_i2c_sda_oe(o_i2c_sda_oe)
    );

    // Outbound FPGA UART Echo Receiver Monitor Channel
    wire [7:0] tb_rx_byte;
    wire       tb_rx_dv;

    uart_rx #(.CLKS_PER_BIT(9'd434)) u_tb_monitor (
        .i_clk(clk), .i_rx(o_uart_tx), .o_rx_byte(tb_rx_byte), .o_rx_dv(tb_rx_dv)
    );

    // =====================================================
    // AUTOMATED BEHAVIORAL BKG I2C SLAVE RESPONDER (0x50)
    // =====================================================
    reg [7:0] slave_rx_shifter;
    reg [7:0] slave_stored_data;
    reg [7:0] slave_tx_shifter;
    integer bit_i;

    initial begin
        forever begin
            slave_sda_drive = 1'b1;
            // Catch True I2C Bus Start Condition
            @(negedge sda_bus);
            if (scl_bus === 1'b1) begin
                // 1. Ingest Address Frame + R/W Indicator Bit
                for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
                    @(posedge scl_bus);
                    slave_rx_shifter[bit_i] = sda_bus;
                end
                
                // Transition to 8th falling edge phase
                @(negedge scl_bus);
                if (slave_rx_shifter[7:1] == 7'h50) begin
                    slave_sda_drive = 1'b0; // Pull down bus line for Hardware ACK
                    
                    // Consume 9th Clock ACK pulse falling edge
                    @(negedge scl_bus);
                    slave_sda_drive = 1'b1; // Cleanly release line back to float high
                    
                    if (slave_rx_shifter[0] == 1'b0) begin
                        // CASE A: FPGA Master Write Transaction Frame
                        for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
                            @(posedge scl_bus);
                            slave_rx_shifter[bit_i] = sda_bus;
                        end
                        slave_stored_data = slave_rx_shifter; // Ingest payload register
                        
                        // Drop line low to ACK data byte receipt
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b0;
                        @(negedge scl_bus);
                        slave_sda_drive = 1'b1;
                    end 
                    else begin
                        // CASE B: FPGA Master Read Turnaround Operation
                        // Mock computation response loop back calculation logic matching hardware requirements
                        slave_tx_shifter = slave_stored_data + 8'h05;
                        for (bit_i = 7; bit_i >= 0; bit_i = bit_i - 1) begin
                            slave_sda_drive = slave_tx_shifter[bit_i];
                            @(negedge scl_bus);
                        end
                        slave_sda_drive = 1'b1; // Float pin high to absorb Master NACK
                        @(negedge scl_bus);
                    end
                end
            end
        end
    end

    // =====================================================
    // EXHAUSTIVE VALIDATION SIMULATION SWEEP MATRIX
    // =====================================================
    integer idx;
    integer passed_count = 0;
    reg [7:0] current_test_val;
    reg [7:0] golden_target_reply;

    initial begin
        $dumpfile("dump.vcd"); $dumpvars(0, tb);
        #5000;
        
        $display("\n=== STARTING PROJECT 1 (UART TO I2C) VERIFICATION HARNESS ===");
        
        fork
            begin : main_test_engine
                for (idx = 0; idx < 10; idx = idx + 1) begin
                    // Initial seed byte matching previous validation trace rules
                    current_test_val   = (idx == 0) ? 8'h4A : $random & 8'hFF;
                    golden_target_reply = (current_test_val + 8'h05) & 8'hFF;
                    
                    $display(" Vector %0d | Inbound UART Trigger Sent: 0x%02h", idx, current_test_val);
                    send_uart_byte(current_test_val);
                    
                    // Track round-trip validation execution back via echo monitor wire
                    @(posedge tb_rx_dv);
                    $display("           -> Outbound Echo Captured : 0x%02h (Expected: 0x%02h)", tb_rx_byte, golden_target_reply);
                    
                    if (tb_rx_byte === golden_target_reply) begin
                        passed_count = passed_count + 1;
                    end else begin
                        $display("           ❌ DATA BITSTREAM FAILURE CORRUPTION DETECTED!");
                    end
                    
                    #200000; // Pacing stabilization layout gap between iterations
                end
                disable simulation_watchdog;
            end

            begin : simulation_watchdog
                #100000000; // Hard bounded wall time execution gate
                $display("\n❌ CRITICAL CRASH: Testbench simulation hit a deadlock timeout or hung state.");
                $finish;
            end
        join

        // Print Outbound Verification Report Summary Card
        $display("\n==================================================");
        $display(" PROJECT 1 AUTOMATED ASSESSMENT SCORECARD");
        $display("==================================================");
        $display(" Total Evaluation Vectors Tested : %0d", 10);
        $display(" Total Successful Match Passes   : %0d", passed_count);
        $display(" Final Simulation Status Verdict : %s", (passed_count == 10) ? "PASS 🎉" : "FAIL ❌");
        $display("==================================================\n");
        $finish;
    end
endmodule