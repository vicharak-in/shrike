/*
 * Project: Vicharak Shrike-Fi FPGA-Primary PID Line Follower
 * File: config.h
 * Description: Master configuration, pin mapping, timing and safety limits.
 */

#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// ============================================================================
// 1. PIN ALLOCATION (Shrike-Fi ESP32-S3 Layout)
// ============================================================================

// --- Internal FPGA Interconnect ---
#define PIN_FPGA_EN      9    // Active-High chip enable
#define PIN_FPGA_PWR     8    // Core power control
#define PIN_FPGA_SS     10    // SPI Chip Select (Active Low)
#define PIN_FPGA_SCK    12    // SPI Serial Clock
#define PIN_FPGA_MOSI   11    // SPI Master Out Slave In
#define PIN_FPGA_MISO   13    // SPI Master In Slave Out

// --- On-Board User LED ---
#define PIN_MCU_LED     21    // ESP32-S3 Green User LED

// --- 8-Channel Digital IR Sensor Array ---
// Bit 0 = Far Right ... Bit 7 = Far Left
#define PIN_SENSOR_0     1    // Far Right
#define PIN_SENSOR_1     2    // Right Outer
#define PIN_SENSOR_2     4    // Right Mid
#define PIN_SENSOR_3     5    // Right Center
#define PIN_SENSOR_4     6    // Left Center
#define PIN_SENSOR_5     7    // Left Mid
#define PIN_SENSOR_6    15    // Left Outer
#define PIN_SENSOR_7    16    // Far Left

// --- L298N Dual H-Bridge Motor Driver ---
#define PIN_MOTOR_L_ENA 38    // Left Motor Speed (PWM Channel 0)
#define PIN_MOTOR_L_IN1 17    // Left Motor Phase A
#define PIN_MOTOR_L_IN2 18    // Left Motor Phase B

#define PIN_MOTOR_R_ENB 39    // Right Motor Speed (PWM Channel 1)
#define PIN_MOTOR_R_IN3 40    // Right Motor Phase A
#define PIN_MOTOR_R_IN4 41    // Right Motor Phase B

// ============================================================================
// 2. TIMING & LOOP RATES
// ============================================================================
#define CONTROL_LOOP_FREQ_HZ   1000     // 1.0 kHz deterministic loop rate
#define CONTROL_LOOP_PERIOD_US 1000     // 1000 microseconds per iteration
#define SPI_BUS_SPEED_HZ       2000000  // 2.0 MHz SPI clock
#define TELEMETRY_RATE_HZ      20       // 20 Hz serial status broadcast

// ============================================================================
// 3. MOTOR & DRIVE CONSTRAINTS
// ============================================================================
#define MOTOR_PWM_FREQ_HZ      20000    // 20 kHz ultrasonic PWM (silent drive)
#define MOTOR_PWM_RESOLUTION   8        // 8-bit resolution (0 to 255)
#define DEFAULT_BASE_SPEED     110      // Default forward speed (0 - 255)
#define MAX_ALLOWED_SPEED      200      // Speed ceiling for battery safety
#define MIN_START_SPEED        40       // Minimum duty to overcome gearbox friction
#define MOTOR_SLEW_LIMIT       25       // Max duty change per control cycle (prevents current spikes)

// ============================================================================
// 4. SENSOR ELECTRICAL NORMALIZATION
// ============================================================================
// Set to 1 if sensor outputs HIGH on black line (reflectance drops);
// Set to 0 if sensor outputs LOW on black line (active-low comparator).
#define SENSOR_ACTIVE_POLARITY_HIGH 1

// ============================================================================
// 5. SAFETY & FAULT THRESHOLDS
// ============================================================================
#define WATCHDOG_TIMEOUT_MS    30       // E-Stop if FPGA fails to respond in 30ms
#define LINE_LOSS_TIMEOUT_MS   800      // E-Stop if line is missing for > 800ms
#define TELEMETRY_BAUD_RATE    115200

// ============================================================================
// 6. WI-FI & WEB TUNING INTERFACE
// ============================================================================
#define WIFI_AP_SSID           "Shrike-TraceRunner"
#define WIFI_AP_PASSWORD       ""        // Open Access Point for track tuning
#define WIFI_AP_CHANNEL        1
#define WEB_SERVER_PORT        80

#endif // CONFIG_H
