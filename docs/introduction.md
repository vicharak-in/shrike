(introduction)=

# Introduction to Shrike Project 

Hello! So you’ve got the **Shrike FPGA** - nice!

Before we explain how programming works on Shrike, it’s important to understand what Shrike actually is and how it differs from all kind of other embedded development boards. 

These points will give you the right foundation, especially if you are new to electronics or computing systems. If you already know the basics of microcontroller, FPGAs, and embedded systems, you can skip this introduction and jump directly into the programming section.

Shrike is special because it combines two worlds on a single board:  
&emsp;**A Microcontroller (MCU)** — Raspberry Pi’s [RP2350/RP2040](https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html) (Pico 1 Family)  
&emsp;**An FPGA (Field-Programmable Gate Array)**

You can write software for the micro-controller and create digital circuits on the FPGA, and then let them work together to build powerful and fun projects. If you’re curious to learn more about FPGAs, you can read about them here.

In Shrike, the micro-controller is connected to the FPGA through an SPI bus. The SPI bus is used for two main purposes:

&emsp;1. **Configuring the FPGA** - loading the bitstream into the FPGA via the RP2040  
&emsp;2. **Communication** - between the microcontroller and the FPGA.

While your program is running on the micro-controller, you can configure the FPGA at any time to perform specific tasks. Not only that, once the FPGA is programmed, it can also communicate with the MCU back and forth.
The beauty of this setup is that you can reprogram the FPGA an unlimited number of times, and that’s exactly where reconfigurable computing comes to life.

As discussed earlier, we’ll need to learn how compilation works for both systems: the FPGA and the micro-controller (RP2350/RP2040).

The binary files that the FPGA understands are called **bitstreams**.  
Follow the guide here to learn how to generate a bitstream for the FPGA:  [Generating Your First Bitstream](https://vicharak-in.github.io/shrike-lite/generating_your_first_bitstream.html)

Once you have the bitstream, you’re ready to load it into the FPGA through a microcontroller (RP2040) program.

We’ll start with a simple blink-LED example to say hello to the world of hardware.  
Along the way, we’ll also set up the required software and toolchain.