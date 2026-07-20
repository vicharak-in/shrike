// =============================================================================
// Shrike-Lite host firmware for the shrike_picorv32_xip example.
//
// The RP2040 does two jobs: at boot it configures the FPGA from the embedded
// bitstream, then it emulates a 64 KB SPI RAM that the FPGA's CPU executes from.
// (MicroPython cannot host this -- the emulator is PIO + chained DMA + a
// dedicated core with cycle-level timing. Reflash the stock Shrike UF2 to
// restore MicroPython.)
//
// USB protocol (programs/run.py speaks it; replies are '#'-prefixed so the CPU's
// console stream stays clean):
//   'L' <u32le len> <bytes>   halt, clear RAM, load a program   -> #OK <len>
//   'R'                       release the CPU, run to completion -> #TRAP ...
//   'H'                       halt the CPU                       -> #HALT
//   'S'                       status word + run state            -> #STATUS ...
//   'B'                       reboot to the UF2 bootloader       -> #BOOTSEL
// The CPU's "console" is bytes it stores to 0xF000; it signals completion by
// storing to 0xF004 (123456789 = pass).
// =============================================================================

#include <stdio.h>
#include <string.h>
#include "pico/stdlib.h"
#include "hardware/spi.h"
#include "hardware/clocks.h"
#include "hardware/vreg.h"
#include "pico/bootrom.h"
#include "sram.h"

// FPGA configuration SPI (shared with the RAM-emulator wires after config)
#define CFG_SPI       spi0
#define PIN_CFG_MISO  0
#define PIN_CFG_SS    1
#define PIN_CFG_SCK   2
#define PIN_CFG_MOSI  3
#define PIN_PWR       12
#define PIN_EN        13
#define PIN_RUN       14   // -> FPGA: releases the CPU from reset and enables its SPI pads

#define STATUS_OFF    0xF004u
#define PASS_VALUE    123456789u
#define RUN_TIMEOUT_MS 20000   // XIP is slow (every access is a SPI txn)

extern const uint8_t  fpga_bitstream[];
extern const uint32_t fpga_bitstream_len;

static uint8_t *ram;   // the 64 KB emulated RAM

// Configure the SLG47910 over SPI: the Shrike flash() sequence -- 1.6 MHz, SS
// low through the power-up dance, then the whole bitstream in one SS-low frame.
static void fpga_configure(void)
{
    spi_init(CFG_SPI, 1600 * 1000);
    gpio_set_function(PIN_CFG_MISO, GPIO_FUNC_SPI);
    gpio_set_function(PIN_CFG_MOSI, GPIO_FUNC_SPI);
    gpio_set_function(PIN_CFG_SCK,  GPIO_FUNC_SPI);
    gpio_init(PIN_CFG_SS);  gpio_set_dir(PIN_CFG_SS,  GPIO_OUT);
    gpio_init(PIN_PWR);     gpio_set_dir(PIN_PWR, GPIO_OUT);
    gpio_init(PIN_EN);      gpio_set_dir(PIN_EN,  GPIO_OUT);

    gpio_put(PIN_PWR, 0); gpio_put(PIN_EN, 0);
    sleep_ms(500);                       // power-off settle
    gpio_put(PIN_CFG_SS, 0);
    sleep_ms(100);
    gpio_put(PIN_EN, 1); gpio_put(PIN_PWR, 1);
    sleep_ms(100);
    gpio_put(PIN_CFG_SS, 1);
    sleep_ms(2);
    gpio_put(PIN_CFG_SS, 0);
    spi_write_blocking(CFG_SPI, fpga_bitstream, fpga_bitstream_len);
    gpio_put(PIN_CFG_SS, 1);
    sleep_ms(100);

    // release the config SPI; the PIO emulator re-functions these pins next
    spi_deinit(CFG_SPI);
    for (int p = PIN_CFG_MISO; p <= PIN_CFG_MOSI; p++) {
        gpio_set_function(p, GPIO_FUNC_SIO);
        gpio_set_dir(p, GPIO_IN);
    }
}

static uint32_t status_word(void)
{
    volatile uint8_t *r = ram;   // core1's DMA writes emu_ram behind the compiler's back
    return (uint32_t)r[STATUS_OFF] | ((uint32_t)r[STATUS_OFF+1] << 8) |
           ((uint32_t)r[STATUS_OFF+2] << 16) | ((uint32_t)r[STATUS_OFF+3] << 24);
}

static int usb_getc_blocking(void)
{
    int c;
    while ((c = getchar_timeout_us(0)) == PICO_ERROR_TIMEOUT)
        tight_loop_contents();
    return c;
}

int main(void)
{
    // The FPGA's inter-transaction CS-high gap is fixed in RTL; a fast sys clock
    // packs enough SYS cycles into it for the emulator to re-arm between ops.
    vreg_set_voltage(VREG_VOLTAGE_1_15);
    sleep_ms(2);
    set_sys_clock_khz(200000, true);

    gpio_init(PIN_RUN);
    gpio_set_dir(PIN_RUN, GPIO_OUT);
    gpio_put(PIN_RUN, 0);                // hold the CPU in reset

    stdio_init_all();
    fpga_configure();

    ram = setup_simulated_sram();        // claims PIOs/DMA, launches core1
    memset(ram, 0, 65536);
    gpio_pull_up(SIM_SRAM_SPI_CS);       // FPGA pads are Hi-Z until run rises
    gpio_pull_down(SIM_SRAM_SPI_SCK);
    gpio_pull_down(SIM_SRAM_SPI_MOSI);

    sleep_ms(2);
    printf("#READY bitstream=%lu ram=64K\n", (unsigned long)fpga_bitstream_len);

    uint32_t console_rd = 0;
    #define DRAIN() do { \
        while (console_rd != sim_sram_console_wr) \
            putchar(sim_sram_console_ring[(console_rd++) & 8191]); \
    } while (0)

    while (true) {
        int c = getchar_timeout_us(1000);
        if (c == PICO_ERROR_TIMEOUT) continue;
        switch (c) {
        case 'L': {   // load a program: halt, clear RAM, copy len bytes in
            uint32_t len = 0;
            for (int i = 0; i < 4; i++)
                len |= (uint32_t)usb_getc_blocking() << (8 * i);
            gpio_put(PIN_RUN, 0);
            sleep_ms(1);
            memset(ram, 0, 65536);
            if (len > 65536) { printf("#ERR len\n"); break; }
            for (uint32_t i = 0; i < len; i++)
                ram[i] = (uint8_t)usb_getc_blocking();
            console_rd = sim_sram_console_wr;   // discard stale console bytes
            printf("#OK %lu\n", (unsigned long)len);
            break;
        }
        case 'R': {   // release the CPU, wait for completion, report + transcript
            console_rd = sim_sram_console_wr;
            absolute_time_t deadline = make_timeout_time_ms(RUN_TIMEOUT_MS);
            gpio_put(PIN_RUN, 1);
            bool done = false;
            // the program writes a non-zero status word (0xF004) when it finishes
            while (!done) {
                if (status_word() != 0) { sleep_ms(50); done = true; break; }
                if (absolute_time_diff_us(get_absolute_time(), deadline) < 0) break;
                sleep_us(200);
            }
            gpio_put(PIN_RUN, 0);        // stop fetching -> bus quiet
            sleep_ms(5);                 // let core1 finish the last frame
            DRAIN();
            uint32_t s = status_word();
            printf("\n#%s STATUS=%08lX %s\n",
                   done ? "TRAP" : "TIMEOUT", (unsigned long)s,
                   (s == PASS_VALUE) ? "PASS" : "FAIL");
            break;
        }
        case 'H':
            gpio_put(PIN_RUN, 0);
            printf("#HALT\n");
            break;
        case 'S':
            printf("#STATUS %08lX RUN=%d\n",
                   (unsigned long)status_word(), gpio_get(PIN_RUN));
            break;
        case 'B':   // reboot to the UF2 bootloader (reflash without touching the board)
            printf("#BOOTSEL\n");
            sleep_ms(50);
            reset_usb_boot(0, 0);
            break;
        default:
            break;   // ignore noise
        }
    }
}
