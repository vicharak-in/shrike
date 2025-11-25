# Using PMOD 7-Segment Display with Shrike

This example demostrates use of [PMOD 7-Segment Display module (available from 1BitSquared)](https://1bitsquared.com/products/pmod-7-segment-display) with Shrike.

## Overview
7-Segment Displays are widely used for FPGA projects. A standard 2-digit 7-Segment PMOD for FPGAs usually doesn’t light all digits at once. The FPGA cycles through each digit very quickly (time-multiplexing) while sharing the same segment lines. The refresh is fast enough that it looks continuous to the human eye.

This example shows how time-multiplexing logic is utilized to implement a counter which goes from 00 to 99 with a 1 second-heartbeat.

## Prerequisite
1. Need a [2 x 6 female pin right-angled PMOD connector](https://www.digikey.in/en/products/detail/w%C3%BCrth-elektronik/613012243121/16608604) soldered on bottom PMOD pins (3.3V, GND and F8-F15). 
2. Get the 7-Segment Display PMOD from 1BitSquared or get it fabricated from [source files](https://github.com/icebreaker-fpga/icebreaker-pmod/tree/master/7segment/v1.2a).
3. Optionally hook a button on FPGA GPIO7 or F7 pin to handle design's inverted reset signal ``rst_n``. 


## How Design works?
- FPGA powers up, ``clk`` is system clock of 50 MHz.
- ``gen_1Hz_tick`` turns that ``clk`` into a 1 Hz pulse ``tick_1Hz``.
- A state machine ``bcd_two_digit_counter`` uses that tick to count seconds up to 99, then resets.
- ``time_multiplexing_clock`` creates a fast tick ``tick_195KHz`` to alternate between the two digits.
- ``seven_segment_decoder_driver``:
    - Latches ``counter_val`` every second (``buffer_in`` = ``tick_1Hz``).
    - Rapidly multiplexes digit 0 and digit 1 via ``active_num``.
    - For each active digit, decodes its BCD nibble into 7-segment pattern.

- Net effect on the 7-segment PMOD:
   - You see a two-digit “seconds” counter incrementing once a second.
   - The digits are time-multiplexed but appear steady to your eyes.

<p align="center">
  <img src="./media/board_with_pmod_module.jpg" width="800"/>
</p>
<p align="center"><em>Design running on Shrike</em></p>


## Note for IO Planner 
We can also hook design's inverted reset ``rst_n`` to ``FPGA_CORE_READY``

## How to flash the FPGA bitstream file
In ForgeFPGA Workshop hit **FPGA Editor** → **Synthesize** → **Generate Bitstream**. Find the generated bin file in as follows ``/ffpga/build/bitstream/FPGA_bitstream_MCU.bin``. Afterward refer the section [here](https://github.com/vicharak-in/shrike_fpga/blob/main/Docs/getting_started.md#4-flashing-the-bitstream) to flash that binary to FPGA.