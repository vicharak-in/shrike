// Copyright 2023 (c) Michael Bell
// The BSD 3 clause license applies
#pragma once

#include <stdint.h>

// Configuration: GPIOs for the SPI interface
// Shrike-Lite wiring (FPGA is the SPI master):
//   GP1 <- FPGA GPIO4 (mosi)   GP2 <- FPGA GPIO3 (sck)
//   GP3 <- FPGA GPIO5 (cs_n)   GP0 -> FPGA GPIO6 (miso)
#define SIM_SRAM_SPI_MOSI 1
#define SIM_SRAM_SPI_SCK  2  // Must be MOSI + 1
#define SIM_SRAM_SPI_CS   3  // Must be MOSI + 2
#define SIM_SRAM_SPI_MISO 0

// The PIO SMs and DMA channels are hardcoded as using dynamic
// allocation and then reading the values from memory is slightly slower.

// Configuration: PIO and SMs to use
// A different PIO must be used for each of read and write 
// as the total program size is too large to fit in one PIO
#define SIM_SRAM_pio_read_sm   1
#define SIM_SRAM_pio_read      pio1
#define SIM_SRAM_pio_write_sm  1
#define SIM_SRAM_pio_write     pio0

// Configuration: DMA channels
#define SIM_SRAM_rx_channel    0
#define SIM_SRAM_tx_channel    1
#define SIM_SRAM_tx_channel2   2

// Setup the simulated SRAM and launch core1 to service the commands.
//
// It is best to call this before other initialization, so that
// the hardcoded DMA channels and SMs are claimed before other resources
// are claimed.
uint8_t* setup_simulated_sram();

// Console relay ring (filled by core1 on every completed SPI write frame
// that starts at CONSOLE_OFF; drained by core0 to USB). Power-of-2 size.
#define SIM_SRAM_CONSOLE_OFF 0xF000u
extern volatile uint8_t  sim_sram_console_ring[8192];
extern volatile uint32_t sim_sram_console_wr;
