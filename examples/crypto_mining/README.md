# SPONGENT-88 Custom Mining Rig

**Difficulty:** 
**Uses MCU:** Yes  
**External Hardware:** None  

## Overview

This project implements a full-stack, hardware-accelerated cryptographic mining rig on the Shrike platform. It features a custom Application-Specific Integrated Circuit (ASIC) design written in Verilog that natively computes the 45-round SPONGENT-88 hash function in pure silicon at over 2.17 MH/s. 

An RP2040 microcontroller acts as the "Stratum" controller, securely pre-hashing arbitrary workloads (Merkle Root simulation) and dispatching them to the FPGA via a custom 10 MHz Programmable I/O (PIO) Dual-SPI bus. The repository also includes a suite of PC-based Python tools for CPU benchmarking and mathematical hardware auditing.

## Compatibility

| Board | Firmware | Status |
|-------|----------|--------|
| Shrike-Lite (RP2040) | `firmware/micropython/` | ✅ Tested |
| Shrike (RP2350) | `firmware/micropython/` | ✅ Tested |
| Shrike-fi (ESP32-S3) | `firmware/micropython/` | ⬜ Untested |

> FPGA bitstream is the same across all boards.

## Hardware Setup

No external hardware required. The configuration utilizes the internal routing between the MCU and the FPGA.

**FPGA Connections (`miner.v`):**
* **Pin 3:** `spi_sck` (Input) - SPI clock
* **Pin 4:** `spi_ss_in` (Input) - Chip select (active low)
* **Pin 18:** `dual_io[0]` (Inout) - DSPI Data Line 0
* **Pin 17:** `dual_io[1]` (Inout) - DSPI Data Line 1
* **Pin 16:** `led` (Output) - Status LED (Turns OFF when Proof of Work is found)

**RP2040 / RP2350 Connections (`dspi_bus.py`):**
* **GPIO 2:** `SCK` (Output) - SPI clock
* **GPIO 1:** `CS` (Output) - Chip select
* **GPIO 14:** `DSPI_D0` (Inout) - PIO Data Line 0
* **GPIO 15:** `DSPI_D1` (Inout) - PIO Data Line 1

*(Note: The RP2040 PIO requires data pins to be contiguous in the silicon. GPIO 14 and 15 form a contiguous block mapped to the FPGA interconnects).*

## Quick Start (Pre-Built Bitstream)

1. Connect your Shrike board via USB.
2. Upload `FPGA_bitstream_MCU.bin` to your board using ShrikeFlash.
3. Upload `dspi_bus.py` and `main.py` to the MCU.
4. Run `main.py` on the MCU to begin the hardware mining process and view live hash rates.
5. **Expected result:** The ASIC will rapidly compute nonces. Once a valid block is found, run `spongent_verifier.py` on your PC to mathematically audit the FPGA's physical output.

## Build From Source

### FPGA (Verilog)
1. Open `miner.v` in Go Configure Software Hub (or your preferred Yosys toolchain).
2. Click Synthesize → Generate Bitstream.
3. Output will be `FPGA_bitstream_MCU.bin`.

### Firmware (MicroPython)
1. Open the project directory in Thonny.
2. Ensure you have flashed the compiled bitstream.
3. Run `main.py` to test the mining controller, or run `spongent_miner.py` on your PC to benchmark standard CPU execution speeds.

## How It Works

This rig bridges complex digital logic with robust embedded software to achieve stability at millions of hashes per second:

* **The Silicon Engine (`miner.v`):** The FPGA executes the SPONGENT-88 XOR, S-Box substitutions, and 44-wire Bit Permutations simultaneously within a single clock cycle using deep combinatorial logic. A **Hardware Memory Lock** prevents asynchronous Python SPI polling requests from corrupting the active memory registers during long computational workloads.
* **The MCU Controller (`main.py` & `dspi_bus.py`):** The RP2040 utilizes its PIO state machines for half-duplex Dual-SPI communication. It implements a **Sign-Bit Hardware Bypass** using the `struct` library to safely pack 32-bit unsigned words, entirely immunizing the rig against MicroPython integer overflow crashes. It also utilizes **Merkle Root Pre-Hashing** (`hashlib.sha256`) to dynamically condense input strings of any length into a strict 4-byte hardware footprint before SPI injection.
* **The PC Toolchain:** Includes `spongent_miner.py` for CPU brute-forcing (~700 H/s vs FPGA ~2.17 MH/s) and `spongent_verifier.py`, an independent auditor script that mathematically verifies the FPGA's output to ensure the silicon did not suffer from false positives due to electrical noise.
