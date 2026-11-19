// Go Configure Software Hub Custom Testbench: tb_pid_top.vt
// 360-Degree Continuous Rotation RC Servo & 2-Stage Pipelined PID Hardware Verification

`timescale 1ns / 1ps

module tb_pid_top;

    reg clk;
    reg rst_n;
    reg spi_ss_n;
    reg spi_sck;
    reg spi_mosi;
    wire spi_miso;
    wire spi_miso_en;
    wire pwm_left_out;
    wire pwm_left_oe;
    wire pwm_right_out;
    wire pwm_right_oe;
    wire motor_en_out;
    wire motor_en_oe;
    wire led;
    wire led_en;

    // DUT instantiation
    pid_top dut (
        .clk(clk),
        .clk_en(),
        .rst_n(rst_n),
        .spi_ss_n(spi_ss_n),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_miso_en(spi_miso_en),
        .pwm_left_out(pwm_left_out),
        .pwm_left_oe(pwm_left_oe),
        .pwm_right_out(pwm_right_out),
        .pwm_right_oe(pwm_right_oe),
        .motor_en_out(motor_en_out),
        .motor_en_oe(motor_en_oe),
        .led(led),
        .led_en(led_en)
    );

    // 50 MHz system clock (20 ns period)
    always #10 clk = ~clk;

    // Task to perform a 1-byte SPI transfer (Mode 0, MSB first, 5 MHz SPI)
    task spi_transfer_byte(
        input  [7:0] tx_byte,
        output [7:0] rx_byte
    );
        integer i;
        begin
            rx_byte = 8'h00;
            for (i = 7; i >= 0; i = i - 1) begin
                spi_mosi = tx_byte[i];
                #100; // Half SCK period (5 MHz SPI)
                spi_sck = 1'b1;
                rx_byte[i] = spi_miso;
                #100;
                spi_sck = 1'b0;
            end
            #50;
        end
    endtask

    // Task to execute full 4-byte SPI frame
    task spi_exchange_frame(
        input  [7:0] cmd,
        input  [7:0] sensor,
        input  [7:0] speed,
        output [7:0] status,
        output [7:0] pwml,
        output [7:0] pwmr,
        output [7:0] error_out
    );
        reg [7:0] parity;
        begin
            parity = cmd ^ sensor ^ speed;

            #200;
            spi_ss_n = 1'b0;
            #200;

            // Byte 0: CMD -> Returns STATUS
            spi_transfer_byte(cmd, status);
            // Byte 1: SENSOR -> Returns DUTY_L
            spi_transfer_byte(sensor, pwml);
            // Byte 2: SPEED -> Returns DUTY_R
            spi_transfer_byte(speed, pwmr);
            // Byte 3: PARITY -> Returns LINE_ERROR
            spi_transfer_byte(parity, error_out);

            #200;
            spi_ss_n = 1'b1;
            #500;
        end
    endtask

    // Test registers
    reg [7:0] status_rx, pwml_rx, pwmr_rx, err_rx;
    integer test_failures = 0;

    initial begin
        $dumpfile("tb_pid_top.vcd");
        $dumpvars(0,
            rst_n,
            spi_ss_n,
            spi_sck,
            spi_mosi,
            spi_miso,
            pwm_left_out,
            pwm_right_out,
            motor_en_out,
            led,
            pwml_rx,
            pwmr_rx,
            err_rx,
            status_rx,
            dut.target_pulse_l,
            dut.target_pulse_r,
            dut.active_duty_l,
            dut.active_duty_r,
            dut.is_armed
        );

        clk = 1'b0;
        rst_n = 1'b0;
        spi_ss_n = 1'b1;
        spi_sck = 1'b0;
        spi_mosi = 1'b0;

        $display("\n============================================================");
        $display(" RENESAS GO CONFIGURE HUB RTL SIMULATION: tb_pid_top");
        $display(" 360-Degree Continuous Rotation RC Servo Engine");
        $display("============================================================\n");

        // Release reset after 300 cycles (internal reset counter is 256)
        #6000;
        rst_n = 1'b1;
        #2000;
        $display("[TB] Reset deasserted. Initializing SPI communication...");

        // -------------------------------------------------------------
        // TEST 1: Center Line Tracking (Sensors = 8'b0001_1000, Speed = 100)
        // -------------------------------------------------------------
        $display("\n[TEST 1] Testing Dead Center Tracking (Sensors = 8'b0001_1000, Speed = 100)...");
        // Frame 1: Stimulus input
        spi_exchange_frame(8'h10, 8'b0001_1000, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);
        #5000;
        // Frame 2: Read back pipelined telemetry
        spi_exchange_frame(8'h10, 8'b0001_1000, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);

        $display("  -> Telemetry: PWM_L=%d, PWM_R=%d, Error=%d, Status=0x%02X",
                 pwml_rx, pwmr_rx, $signed(err_rx), status_rx);

        if (pwml_rx == 8'd100 && pwmr_rx == 8'd100 && $signed(err_rx) == 0 && motor_en_out == 1'b1) begin
            $display("  [PASS] Center Tracking Telemetry Verified (Equal duty 100, Error 0, Motor_EN High).");
        end else begin
            $display("  [FAIL] Expected (100, 100, 0, EN=1), Got (%d, %d, %d, EN=%b)",
                     pwml_rx, pwmr_rx, $signed(err_rx), motor_en_out);
            test_failures = test_failures + 1;
        end
        // Wait 21 ms to record a full 20 ms RC servo frame (Left=1700us, Right=1300us)
        #21000000;

        // -------------------------------------------------------------
        // TEST 2: Hard Left Deviation (Sensors = 8'b1000_0000, Error = -7)
        // -------------------------------------------------------------
        $display("\n[TEST 2] Testing Far Left Deviation (Sensors = 8'b1000_0000)...");
        spi_exchange_frame(8'h10, 8'b1000_0000, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);
        #5000;
        spi_exchange_frame(8'h10, 8'b1000_0000, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);

        $display("  -> Telemetry: PWM_L=%d, PWM_R=%d, Error=%d", pwml_rx, pwmr_rx, $signed(err_rx));

        if ($signed(err_rx) == -7 && pwml_rx > pwmr_rx) begin
            $display("  [PASS] Left Correction Verified: Error=-7, Left wheel sped up to turn right.");
        end else begin
            $display("  [FAIL] Expected Error=-7 and PWM_L > PWM_R, Got (%d, %d, %d)",
                     pwml_rx, pwmr_rx, $signed(err_rx));
            test_failures = test_failures + 1;
        end
        // Wait 21 ms to record a full 20 ms RC servo frame (Left=1772us, Right=1372us)
        #21000000;

        // -------------------------------------------------------------
        // TEST 3: Hard Right Deviation (Sensors = 8'b0000_0001, Error = +7)
        // -------------------------------------------------------------
        $display("\n[TEST 3] Testing Far Right Deviation (Sensors = 8'b0000_0001)...");
        spi_exchange_frame(8'h10, 8'b0000_0001, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);
        #5000;
        spi_exchange_frame(8'h10, 8'b0000_0001, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);

        $display("  -> Telemetry: PWM_L=%d, PWM_R=%d, Error=%d", pwml_rx, pwmr_rx, $signed(err_rx));

        if ($signed(err_rx) == 7 && pwmr_rx > pwml_rx) begin
            $display("  [PASS] Right Correction Verified: Error=+7, Right wheel sped up to turn left.");
        end else begin
            $display("  [FAIL] Expected Error=+7 and PWM_R > PWM_L, Got (%d, %d, %d)",
                     pwml_rx, pwmr_rx, $signed(err_rx));
            test_failures = test_failures + 1;
        end
        // Wait 21 ms to record a full 20 ms RC servo frame (Left=1590us, Right=1190us)
        #21000000;

        // -------------------------------------------------------------
        // TEST 4: Lost Line Event & Pivot Spin Turn Recovery
        // -------------------------------------------------------------
        $display("\n[TEST 4] Testing Lost Line Event & Memory Pivot Recovery...");
        spi_exchange_frame(8'h10, 8'b0000_0000, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);
        #5000;
        spi_exchange_frame(8'h10, 8'b0000_0000, 8'd100, status_rx, pwml_rx, pwmr_rx, err_rx);

        $display("  -> Telemetry: PWM_L=%d, PWM_R=%d, Status=0x%02X (LineLost=%b)",
                 pwml_rx, pwmr_rx, status_rx, status_rx[6]);

        if (status_rx[6] == 1'b1 && pwml_rx == 8'd60 && pwmr_rx == 8'd0) begin
            $display("  [PASS] Line Lost Recovery Verified: Status flag set, pivot right executed (60, 0).");
        end else begin
            $display("  [FAIL] Expected LineLost=1 and (60, 0), Got (%d, %d, Status=0x%02X)",
                     pwml_rx, pwmr_rx, status_rx);
            test_failures = test_failures + 1;
        end
        // Wait 21 ms to record a full 20 ms RC servo frame (Left=1620us, Right=1500us neutral)
        #21000000;

        // -------------------------------------------------------------
        // TEST 5: Disarm Safety Interlock (CMD = 0x00)
        // -------------------------------------------------------------
        $display("\n[TEST 5] Testing Disarm Command & Zero-Creep Silence...");
        spi_exchange_frame(8'h00, 8'b0001_1000, 8'd0, status_rx, pwml_rx, pwmr_rx, err_rx);
        #10000;

        if (dut.is_armed == 1'b0 && motor_en_out == 1'b0 && dut.target_pulse_l == 0 && dut.target_pulse_r == 0) begin
            $display("  [PASS] Disarm Verified: is_armed=0, motor_en=0, servo target pulses silenced (0V).");
        end else begin
            $display("  [FAIL] Disarm failed: is_armed=%b, motor_en=%b, pulses=(%d, %d)",
                     dut.is_armed, motor_en_out, dut.target_pulse_l, dut.target_pulse_r);
            test_failures = test_failures + 1;
        end
        // Observe flat 0V silence line for 5 ms
        #5000000;

        // -------------------------------------------------------------
        // SUMMARY REPORT
        // -------------------------------------------------------------
        $display("\n============================================================");
        if (test_failures == 0) begin
            $display("  ALL HARDWARE TESTBENCH CHECKS PASSED (0 failures)!");
        end else begin
            $display("  TESTBENCH FAILED: %d test failure(s) detected!", test_failures);
        end
        $display("============================================================\n");

        #5000;
        $finish;
    end

endmodule
