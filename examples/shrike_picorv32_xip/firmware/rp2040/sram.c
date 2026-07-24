// Copyright 2023 (c) Michael Bell
// The BSD 3 clause license applies
#include <hardware/pio.h>
#include <hardware/dma.h>
#include <pico/multicore.h>
#include "hardware/structs/bus_ctrl.h"

#include "sram.pio.h"

#include "sram.h"

// We define the SMs and DMA channels to avoid memory accesses
// looking them up which saves precious cycles processing the SPI commands.
#define pio_write_offset 0  // This must be 0

static int pio_read_offset;

uint8_t __attribute__((section(".spi_ram.emu_ram"))) emu_ram[65536];

// Console relay: written by core1, read by core0 (single producer/consumer).
volatile uint8_t  sim_sram_console_ring[8192];
volatile uint32_t sim_sram_console_wr = 0;

static void setup_sram_pio()
{
    pio_read_offset = pio_add_program(SIM_SRAM_pio_read, &sram_read_program);
    pio_sm_claim(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
    pio_add_program_at_offset(SIM_SRAM_pio_write, &sram_write_program, pio_write_offset);
    pio_sm_claim(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm);

    sram_read_program_init(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm, pio_read_offset, SIM_SRAM_SPI_MOSI);
    sram_write_program_init(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm, pio_write_offset, SIM_SRAM_SPI_MOSI, SIM_SRAM_SPI_MISO);
}

static void setup_rx_channel()
{
    dma_channel_claim(SIM_SRAM_rx_channel);

    dma_channel_config c = dma_channel_get_default_config(SIM_SRAM_rx_channel);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_8);
    channel_config_set_read_increment(&c, false);
    channel_config_set_write_increment(&c, true);
    channel_config_set_dreq(&c, pio_get_dreq(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm, false));

    dma_channel_configure(
        SIM_SRAM_rx_channel,          // Channel to be configured
        &c,            // The configuration we just created
        NULL,           // The initial write address
        &SIM_SRAM_pio_read->rxf[SIM_SRAM_pio_read_sm],           // The initial read address
        65536, // Number of transfers; in this case each is 1 byte.
        false           // Start immediately.
    );
}

static void setup_tx_channel()
{
    dma_channel_claim(SIM_SRAM_tx_channel);
    dma_channel_claim(SIM_SRAM_tx_channel2);

    dma_channel_config c = dma_channel_get_default_config(SIM_SRAM_tx_channel);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
    channel_config_set_read_increment(&c, true);
    channel_config_set_write_increment(&c, false);
    channel_config_set_bswap(&c, true);
    channel_config_set_dreq(&c, pio_get_dreq(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm, true));

    dma_channel_configure(
        SIM_SRAM_tx_channel,          // Channel to be configured
        &c,            // The configuration we just created
        &SIM_SRAM_pio_write->txf[SIM_SRAM_pio_write_sm],           // The initial write address
        NULL,           // The initial read address
        65536, // Number of transfers; in this case each is 1 byte.
        false           // Start immediately.
    );

    c = dma_channel_get_default_config(SIM_SRAM_tx_channel2);
    channel_config_set_transfer_data_size(&c, DMA_SIZE_32);
    channel_config_set_read_increment(&c, false);
    channel_config_set_write_increment(&c, false);
    channel_config_set_dreq(&c, pio_get_dreq(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm, false));

    dma_channel_configure(
        SIM_SRAM_tx_channel2,          // Channel to be configured
        &c,            // The configuration we just created
        &dma_hw->ch[SIM_SRAM_tx_channel].al3_read_addr_trig,           // The initial write address
        &SIM_SRAM_pio_read->rxf[SIM_SRAM_pio_read_sm],           // The initial read address
        1, // Number of transfers; in this case each is 1 byte.
        false           // Start immediately.
    );
}

static __always_inline void wait_for_cs_high() {
    while (true) {
        if (gpio_get(SIM_SRAM_SPI_CS)) {
            if (gpio_get(SIM_SRAM_SPI_CS)) {
                // Must be high for 2 cycles to count - avoids deselecting on a glitch.
                break;
            }
        }
    }
}

static void __scratch_x("core1_main") core1_main()
{
    uint32_t wr_addr = 0;
    while (true) {
        uint32_t cmd = pio_sm_get_blocking(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
        if (cmd == 0x3) {
            // Read - this works by transferring the address direct from the Read PIO SM
            // direct to the read address of the transmit DMA channel.
            dma_channel_start(SIM_SRAM_tx_channel2);

            wait_for_cs_high();
            dma_channel_abort(SIM_SRAM_tx_channel);
        }
        else if (cmd == 0xB) {
            // Fast read
            // Need to patch the write program to do extra delay cycles
            SIM_SRAM_pio_write->instr_mem[sram_write_offset_addr_loop_end] = pio_encode_jmp(sram_write_offset_fast_read);

            // And change the write size to 8
            hw_clear_bits(&dma_hw->ch[SIM_SRAM_tx_channel].al1_ctrl, DMA_CH0_CTRL_TRIG_DATA_SIZE_BITS);
            hw_set_bits(&SIM_SRAM_pio_write->sm[SIM_SRAM_pio_write_sm].shiftctrl, 8 << PIO_SM0_SHIFTCTRL_PULL_THRESH_LSB);

            // Transfer the address manually
            uint32_t addr = pio_sm_get_blocking(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
            addr |= pio_sm_get_blocking(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
            dma_hw->ch[SIM_SRAM_tx_channel].al3_read_addr_trig = addr;

            wait_for_cs_high();
            dma_channel_abort(SIM_SRAM_tx_channel);

            // Unpatch the write program
            SIM_SRAM_pio_write->instr_mem[sram_write_offset_addr_loop_end] = pio_encode_jmp_pin(sram_write_offset_addr_two);

            // And change the write size back to 32
            hw_set_bits(&dma_hw->ch[SIM_SRAM_tx_channel].al1_ctrl, 2 << DMA_CH10_CTRL_TRIG_DATA_SIZE_LSB);
            hw_clear_bits(&SIM_SRAM_pio_write->sm[SIM_SRAM_pio_write_sm].shiftctrl, PIO_SM0_SHIFTCTRL_PULL_THRESH_BITS);
        }
        else if (cmd == 0x2) {
            // Write
            //addr += pio_sm_get_blocking(pio, pio_read_sm) << 8;
            uint32_t addr = pio_sm_get_blocking(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
            addr |= pio_sm_get_blocking(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
            // Shrike-XIP hardening: a glitched frame could assemble a wild
            // address and let the DMA write anywhere (system registers
            // included -- one such write can reset the chip). Clamp every
            // write into the 64 KB emu_ram window.
            addr = (uint32_t)emu_ram | (addr & 0xFFFFu);
            dma_hw->ch[SIM_SRAM_rx_channel].al2_write_addr_trig = addr;

            wait_for_cs_high();
            while (!pio_sm_is_rx_fifo_empty(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm));
            dma_channel_abort(SIM_SRAM_rx_channel);
            wr_addr = addr;   // bookkeeping deferred until after the re-arm
        }
        else {
            // Ignore unknown command
            wait_for_cs_high();
        }
        // Re-arm BOTH SMs IMMEDIATELY: the next frame starts one CS gap
        // (~0.84 us) after CS rose, and a restart that lands mid-frame makes
        // the SM sync to a wrong bit boundary (the cmd parses as garbage, the
        // frame is ignored, and a fetch that gets no MISO data derails the
        // CPU). All slow bookkeeping happens after this block.
        pio_sm_set_enabled(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm, false);
        pio_sm_clear_fifos(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm);
        pio_sm_restart(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm);
        pio_sm_exec(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm, pio_encode_jmp(pio_write_offset));
        pio_sm_set_enabled(SIM_SRAM_pio_write, SIM_SRAM_pio_write_sm, true);
        pio_sm_set_enabled(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm, false);
        pio_sm_clear_fifos(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
        pio_sm_restart(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm);
        pio_sm_exec(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm, pio_encode_jmp(pio_read_offset));
        pio_sm_set_enabled(SIM_SRAM_pio_read, SIM_SRAM_pio_read_sm, true);

        // ---- deferred write-frame bookkeeping (SMs already listening) ----
        if (wr_addr) {
            // Shrike-XIP console hook: a completed write frame that STARTED at
            // the console word carries one character in its first byte. This is
            // the exact mechanism the system testbench (tb_xip.v) models.
            if (wr_addr == (uint32_t)&emu_ram[SIM_SRAM_CONSOLE_OFF])
                sim_sram_console_ring[(sim_sram_console_wr++) & 8191] =
                    *(volatile uint8_t*)&emu_ram[SIM_SRAM_CONSOLE_OFF];
            wr_addr = 0;
        }
    }
}

uint8_t* setup_simulated_sram() {
    setup_sram_pio();

    setup_rx_channel();
    setup_tx_channel();

    hw_set_bits(&bus_ctrl_hw->priority, BUSCTRL_BUS_PRIORITY_DMA_R_BITS | BUSCTRL_BUS_PRIORITY_DMA_W_BITS);
    multicore_launch_core1(core1_main);

    return emu_ram;
}