`timescale 1ns/1ps

module tb;
    // System Master Clock Source Grid (50 MHz Input)
    reg clk = 1'b0;
    always #10 clk = ~clk;

    // Emulated Microcontroller Interface Stimulus Pins
    reg master_scl_drive = 1'b1;
    reg master_sda_drive = 1'b1;
    reg i_uart_rx        = 1'b1;

    // Hardware Layer Physical Nets
    wire i_i2c_sda;
    wire i_i2c_scl;
    wire o_uart_tx;
    wire o_uart_tx_oe;
    wire o_i2c_sda;
    wire o_i2c_sda_oe;
    wire clk_en;

    // Structural Open-Drain Wire Resolutions
    assign i_i2c_scl = master_scl_drive;
    assign i_i2c_sda = (o_i2c_sda_oe) ? 1'b0 : master_sda_drive;

    // =====================================================
    // CORE MASTER SIMULATION MECHANICS (TASKS)
    // =====================================================
    task i2c_start;
        begin
            master_sda_drive = 1'b1; master_scl_drive = 1'b1; #5000;
            master_sda_drive = 1'b0; #5000;
            master_scl_drive = 1'b0; #5000;
        end
    endtask

    task i2c_stop;
        begin
            master_sda_drive = 1'b0; #5000;
            master_scl_drive = 1'b1; #5000;
            master_sda_drive = 1'b1; #5000;
        end
    endtask

    task i2c_write_byte;
        input [7:0] data;
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                master_sda_drive = data[i]; #2500;
                master_scl_drive = 1'b1;    #5000;
                master_scl_drive = 1'b0;    #2500;
            end
            master_sda_drive = 1'b1; #2500; // Float line for Slave Hardware ACK 
            master_scl_drive = 1'b1; #5000;
            master_scl_drive = 1'b0; #2500;
        end
    endtask

    task i2c_read_byte;
        output [7:0] data;
        integer i;
        begin
            master_sda_drive = 1'b1; // Master releases line high to sample slave bits
            for (i = 7; i >= 0; i = i - 1) begin
                #2500;
                master_scl_drive = 1'b1; #2500;
                data[i] = i_i2c_sda;     #2500;
                master_scl_drive = 1'b0; #2500;
            end
            // Send NACK to terminate the single-byte frame cleanly
            master_sda_drive = 1'b1; #2500;
            master_scl_drive = 1'b1; #5000;
            master_scl_drive = 1'b0; #2500;
        end
    endtask

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
        .o_i2c_sda(o_i2c_sda), .o_i2c_sda_oe(o_i2c_sda_oe)
    );

    // Outbound FPGA UART Monitor Network
    wire [7:0] mon_uart_out_byte;
    wire       mon_uart_out_dv;
    reg  [7:0] master_harvested_byte = 8'h00;

    uart_rx #(.CLKS_PER_BIT(9'd434)) u_uart_out_monitor (
        .i_clk(clk), .i_rx(o_uart_tx), .o_rx_byte(mon_uart_out_byte), .o_rx_dv(mon_uart_out_dv)
    );

    // =====================================================
    // AUTOMATED OBJECT B DYNAMIC UART RESPONDER LOOP
    // =====================================================
    // Mapped equation parameters matching micro-controller loop behaviour
    reg [7:0] mcu_reply_data;
    initial begin
        forever begin
            @(posedge mon_uart_out_dv);
            mcu_reply_data = (mon_uart_out_byte + 8'h05) & 8'hFF; 
            #40000; // Simulated internal execution delay latency
            send_uart_byte(mcu_reply_data);
        end
    end

    // =====================================================
    // EXHAUSTIVE MULTI-VECTOR STRESS ASSESSMENT GRID
    // =====================================================
    integer idx;
    integer total_vectors = 66; // Exhaustive collection count
    integer verified_passes = 0;
    
    reg [7:0] write_val;
    reg [7:0] golden_reply;

    initial begin
        $dumpfile("dump.vcd"); $dumpvars(0, tb);
        #1000;
        
        $display("\n==================================================");
        $display("LAUNCHING ROBUST MULTI-VECTOR ASSIGNMENT: PROJECT 2");
        $display("==================================================");
        
        fork
            begin : master_stress_engine
                for (idx = 0; idx < total_vectors; idx = idx + 1) begin
                    
                    // Procedural generation block mapping multi-byte sweeps
                    if (idx < 4) begin
                        // Phase A: Boundary conditions checking (4 Vectors)
                        case(idx)
                            0: write_val = 8'h00; // Min Boundary
                            1: write_val = 8'hFF; // Max Boundary
                            2: write_val = 8'h55; // Alternating grid checker 1
                            3: write_val = 8'hAA; // Alternating grid checker 2
                        endcase
                    end 
                    else if (idx >= 4 && idx < 12) begin
                        // Phase B: Walking Ones Bitwise Expansion tracking (8 Vectors)
                        write_val = (8'h01 << (idx - 4));
                    end 
                    else begin
                        // Phase C: Randomized Stream Interference checks (54 Vectors)
                        write_val = $random & 8'hFF;
                    end

                    // Golden output checking reference matrix rule
                    golden_reply = (write_val + 8'h05) & 8'hFF;

                    // --- STEP 1: Execute I2C Master Write Frame ---
                    i2c_start();
                    i2c_write_byte({7'h50, 1'b0}); // Targeting Slave Address 0x50 + Write Code Flag
                    i2c_write_byte(write_val);          
                    i2c_stop();

                    #100000; // Mapped calibrated simulation timing turnaround delay

                    // --- STEP 2: Execute I2C Master Read Frame ---
                    i2c_start();
                    i2c_write_byte({7'h50, 1'b1}); // Targeting Slave Address 0x50 + Read Code Flag
                    i2c_read_byte(master_harvested_byte);
                    i2c_stop();

                    // Verbose validation tracking updates
                    if (idx < 12 || idx % 15 == 0) begin
                        $display(" Vector %02d | Sent I2C: 0x%02h | Expected Read: 0x%02h | Got: 0x%02h | Status: %s", 
                                 idx, write_val, golden_reply, master_harvested_byte,
                                 (master_harvested_byte === golden_reply) ? "MATCH ✅" : "MISMATCH ❌");
                    end

                    if (master_harvested_byte === golden_reply) begin
                        verified_passes = verified_passes + 1;
                    end
                    
                    #50000; // Inter-packet structural normalization stability gap
                end
                disable watchdog_timer_gate;
            end

            begin : watchdog_timer_gate
                #50000000; // Hard bounded 50ms simulation timeout limits
                $display("\n[CRITICAL FAILURE] Synchronization lost or FSM locked out inside simulation boundary graph.");
                $finish;
            end
        join

        // =====================================================
        // PERFORMANCE METRIC SUMMARY ASSESSMENT CARD
        // =====================================================
        $display("\n==================================================");
        $display(" PROJECT 2 ROBUSTNESS STABILITY ASSESSMENT CARD");
        $display("==================================================");
        $display(" Total Vectors Transmitted : %0d", total_vectors);
        $display(" Total Assertions Passed   : %0d", verified_passes);
        $display(" Total Hardware Error Rate : %0.2f%%", ((total_vectors - verified_passes) * 100.0) / total_vectors);
        $display(" Structural Yield Score    : %0.2f%%", (verified_passes * 100.0) / total_vectors);
        $display("--------------------------------------------------");
        if (verified_passes == total_vectors) begin
            $display(" VERDICT: ROBUST REVERSE OPERATION STABLE APPROVED 🚀");
        end else begin
            $display(" VERDICT: SYSTEM CRASH FAILS UNEXPECTED VALUE SWEEPS ❌");
        end
        $display("==================================================\n");
        $finish;
    end
endmodule