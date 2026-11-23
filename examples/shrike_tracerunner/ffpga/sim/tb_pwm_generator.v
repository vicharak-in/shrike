`timescale 1ns / 1ps

module tb_pwm_generator;

    reg        clk;
    reg        rst_n;
    reg        enable;
    reg  [7:0] duty;
    wire       pwm_out;

    // Instantiate with smaller prescaler for fast simulation verification
    // PRESCALER = 2 -> 2 clocks per tick, 256 ticks = 512 clocks per PWM cycle
    pwm_generator #(
        .PRESCALER(2),
        .WIDTH(8)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .duty(duty),
        .pwm_out(pwm_out)
    );

    // 50 MHz Clock generation (20 ns period)
    always #10 clk = ~clk;

    integer high_count;
    integer low_count;
    integer i;
    integer errors;

    initial begin
        clk = 0;
        rst_n = 0;
        enable = 0;
        duty = 8'd0;
        high_count = 0;
        low_count = 0;
        errors = 0;

        $display("=== Starting PWM Generator Testbench ===");

        // Test 1: Reset behavior
        #50;
        if (pwm_out !== 1'b0) begin
            $display("[FAIL] Test 1: pwm_out not 0 during reset");
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 1: Reset holds output low");
        end

        // Release reset but keep enable = 0
        rst_n = 1;
        duty = 8'd128;
        #100;
        if (pwm_out !== 1'b0) begin
            $display("[FAIL] Test 2: pwm_out asserted while enable = 0");
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 2: Enable gating holds output low");
        end

        // Test 3: Duty = 0% with enable = 1
        enable = 1;
        duty = 8'd0;
        high_count = 0;
        for (i = 0; i < 600; i = i + 1) begin
            @(posedge clk);
            if (pwm_out) high_count = high_count + 1;
        end
        if (high_count !== 0) begin
            $display("[FAIL] Test 3: Duty 0 produced pulses (high_count = %d)", high_count);
            errors = errors + 1;
        end else begin
            $display("[PASS] Test 3: Duty 0 produces constant 0");
        end

        // Test 4: Duty = 50% (duty = 128)
        // With PRESCALER=2 and WIDTH=8, 1 PWM period = 512 clock cycles
        duty = 8'd128;
        // Wait for cycle start
        @(negedge pwm_out);
        @(posedge pwm_out);
        high_count = 0;
        low_count = 0;
        for (i = 0; i < 512; i = i + 1) begin
            @(posedge clk);
            if (pwm_out)
                high_count = high_count + 1;
            else
                low_count = low_count + 1;
        end

        // 128 * 2 = 256 high clocks, 128 * 2 = 256 low clocks
        if (high_count == 256 && low_count == 256) begin
            $display("[PASS] Test 4: 50 percent duty exact match (256 high, 256 low)");
        end else begin
            $display("[FAIL] Test 4: 50 percent duty mismatch (high=%d, low=%d, expected 256/256)", high_count, low_count);
            errors = errors + 1;
        end

        // Test 5: Duty = 255 (~99.6%)
        duty = 8'd255;
        @(negedge pwm_out);
        @(posedge pwm_out);
        high_count = 0;
        low_count = 0;
        for (i = 0; i < 512; i = i + 1) begin
            @(posedge clk);
            if (pwm_out)
                high_count = high_count + 1;
            else
                low_count = low_count + 1;
        end

        // 255 * 2 = 510 high clocks, 1 * 2 = 2 low clocks
        if (high_count == 510 && low_count == 2) begin
            $display("[PASS] Test 5: 99.6 percent duty exact match (510 high, 2 low)");
        end else begin
            $display("[FAIL] Test 5: Duty 255 mismatch (high=%d, low=%d, expected 510/2)", high_count, low_count);
            errors = errors + 1;
        end

        // Summary
        if (errors == 0) begin
            $display("=== ALL PWM TESTS PASSED ===");
            $finish;
        end else begin
            $display("=== PWM TESTS FAILED WITH %d ERRORS ===", errors);
            $stop;
        end
    end

endmodule
